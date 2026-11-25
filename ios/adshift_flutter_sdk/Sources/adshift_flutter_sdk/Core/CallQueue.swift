/// Hands Dart's calls to the bridge one at a time, in the order they arrived:
/// the next call is delivered only when the one before it has answered. A
/// bridge method answers when its SDK call has returned, `start` when the SDK
/// has started or refused to. So a `stop` made after an event or after `start`
/// never reaches the SDK before them.
@MainActor
final class CallQueue {
  private var waiting: [(_ turn: Int) -> Void] = []
  private var turn = 0
  private var isHeld = false
  private var isDelivering = false

  /// `call` is given its turn, to pass to `release` when it has answered.
  func add(_ call: @escaping (_ turn: Int) -> Void) {
    waiting.append(call)
    deliver()
  }

  /// Ends a turn: the next call is delivered. A turn that has ended is ignored.
  func release(_ turn: Int) {
    guard isHeld, turn == self.turn else { return }
    isHeld = false
    deliver()
  }

  private func deliver() {
    // A call that answers before it returns ends its turn inside this loop;
    // the next call then starts here, after that one has returned.
    guard !isDelivering else { return }
    isDelivering = true
    defer { isDelivering = false }
    while !isHeld, !waiting.isEmpty {
      isHeld = true
      turn += 1
      waiting.removeFirst()(turn)
    }
  }
}
