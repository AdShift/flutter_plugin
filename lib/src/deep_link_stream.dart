import 'dart:async';

import 'log.dart';
import 'models/adshift_deep_link.dart';

/// Holds deep link results until somebody listens, then delivers each once.
final class DeepLinkStream {
  static const int _bufferLimit = 20;

  late final StreamController<AdshiftDeepLink> _controller =
      StreamController<AdshiftDeepLink>.broadcast(onListen: _scheduleReplay);
  final List<AdshiftDeepLink> _buffer = [];
  bool _replayScheduled = false;

  late final Stream<AdshiftDeepLink> stream = _ContainedStream(
    _controller.stream,
  );

  void add(AdshiftDeepLink link) {
    // A result must not overtake one still waiting in the buffer.
    if (_controller.hasListener && _buffer.isEmpty) {
      _controller.add(link);
      return;
    }
    _hold(link);
    _scheduleReplay();
  }

  /// A deferred result is never dropped to make room for a direct one.
  void _hold(AdshiftDeepLink link) {
    if (_buffer.length >= _bufferLimit) {
      final evictable = _buffer.indexWhere((held) => !held.isDeferred);
      if (evictable >= 0) {
        _buffer.removeAt(evictable);
      } else if (link.isDeferred) {
        _buffer.removeAt(0);
      } else {
        debugWarn('Deep link buffer is full; dropping a direct deep link.');
        return;
      }
    }
    _buffer.add(link);
  }

  /// Replays in a microtask, so every listener added in the same turn as the
  /// first one receives the held results too.
  void _scheduleReplay() {
    if (_replayScheduled || _buffer.isEmpty) return;
    _replayScheduled = true;
    scheduleMicrotask(() {
      _replayScheduled = false;
      if (!_controller.hasListener) return;
      final held = List.of(_buffer);
      _buffer.clear();
      held.forEach(_controller.add);
    });
  }
}

/// A listener that throws does not disturb the other listeners or the SDK;
/// the exception is printed in debug builds.
final class _ContainedStream extends Stream<AdshiftDeepLink> {
  _ContainedStream(this._source);

  final Stream<AdshiftDeepLink> _source;

  @override
  bool get isBroadcast => true;

  @override
  StreamSubscription<AdshiftDeepLink> listen(
    void Function(AdshiftDeepLink link)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _source.listen(
    onData == null
        ? null
        : (link) {
            try {
              onData(link);
            } catch (error, stackTrace) {
              debugWarn('onDeepLink listener threw: $error\n$stackTrace');
            }
          },
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
}
