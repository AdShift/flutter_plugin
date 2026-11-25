import Foundation

/// Hands Dart's calls to the bridge one at a time, in the order they arrived.
/// A call that answers at once is followed by the next one right away. A call
/// that answers later holds the following calls back until its request is with
/// the SDK, so that a `stop` made after an event never reaches the SDK first.
@MainActor
final class CallQueue {
  private var waiting: [(_ turn: Int) -> Void] = []
  private var turn = 0
  private var isHeld = false

  /// `call` is given its turn, to pass to `release`.
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

  /// Ends the current turn once the code running now has given the main thread
  /// back. A bridge method calls this and then hands its request to the SDK
  /// without suspending in between, so the next call finds the request there.
  func releaseAfterCurrentWork() {
    let turn = turn
    DispatchQueue.main.async {
      self.release(turn)
    }
  }

  private func deliver() {
    guard !isHeld, !waiting.isEmpty else { return }
    isHeld = true
    turn += 1
    waiting.removeFirst()(turn)
  }
}
