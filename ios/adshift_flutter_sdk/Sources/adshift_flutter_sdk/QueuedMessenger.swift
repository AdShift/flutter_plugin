import Flutter

/// A messenger whose message handlers receive their calls through a
/// `CallQueue`. Flutter runs handlers in the order Dart made the calls, but a
/// method that answers later starts its work only afterwards, so without the
/// queue a later call could reach the SDK before it. Sending is passed on as is.
@MainActor
final class QueuedMessenger: NSObject, @preconcurrency FlutterBinaryMessenger {
  private let messenger: FlutterBinaryMessenger
  private let calls: CallQueue

  init(_ messenger: FlutterBinaryMessenger, calls: CallQueue) {
    self.messenger = messenger
    self.calls = calls
  }

  func setMessageHandlerOnChannel(
    _ channel: String,
    binaryMessageHandler handler: FlutterBinaryMessageHandler? = nil
  ) -> FlutterBinaryMessengerConnection {
    guard let handler else {
      return messenger.setMessageHandlerOnChannel(channel, binaryMessageHandler: nil)
    }
    return messenger.setMessageHandlerOnChannel(channel) { [calls] message, reply in
      calls.add { turn in
        var hasAnswered = false
        handler(message) { answer in
          hasAnswered = true
          reply(answer)
        }
        // An answer given before the handler returns means the call is done.
        if hasAnswered {
          calls.release(turn)
        }
      }
    }
  }

  func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {
    messenger.cleanUpConnection(connection)
  }

  func send(onChannel channel: String, message: Data?) {
    messenger.send(onChannel: channel, message: message)
  }

  func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply? = nil) {
    messenger.send(onChannel: channel, message: message, binaryReply: callback)
  }
}
