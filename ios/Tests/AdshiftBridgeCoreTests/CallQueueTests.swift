import XCTest

@testable import AdshiftBridgeCore

@MainActor
final class CallQueueTests: XCTestCase {
  private let queue = CallQueue()
  private var log: [String] = []

  /// A call that answers at once: its turn ends before it returns.
  private func addCallThatAnswersAtOnce(_ name: String) {
    queue.add { turn in
      self.log.append(name)
      self.queue.release(turn)
    }
  }

  /// A call that answers later: it is delivered and keeps its turn.
  private func addCallThatAnswersLater(_ name: String) {
    queue.add { _ in
      self.log.append(name)
    }
  }

  /// Returns once everything already put on the main queue has run.
  private func mainQueueDrained() async {
    await withCheckedContinuation { continuation in
      DispatchQueue.main.async {
        continuation.resume()
      }
    }
  }

  func testCallsThatAnswerAtOnceAreDeliveredAsTheyArrive() {
    addCallThatAnswersAtOnce("first")
    XCTAssertEqual(log, ["first"])

    addCallThatAnswersAtOnce("second")
    addCallThatAnswersAtOnce("third")
    XCTAssertEqual(log, ["first", "second", "third"])
  }

  func testCallThatAnswersLaterHoldsTheFollowingOnesBack() {
    addCallThatAnswersLater("event")
    addCallThatAnswersAtOnce("stop")
    addCallThatAnswersAtOnce("setter")
    XCTAssertEqual(log, ["event"])

    queue.release(1)
    XCTAssertEqual(log, ["event", "stop", "setter"])
  }

  /// What a method that answers later does: it asks for the next call, then
  /// hands its request over in the same stretch of code.
  func testNextCallWaitsUntilTheRequestIsHandedOver() async {
    addCallThatAnswersLater("event")
    addCallThatAnswersAtOnce("stop")

    queue.releaseAfterCurrentWork()
    log.append("event handed to the SDK")
    XCTAssertEqual(log, ["event", "event handed to the SDK"])

    await mainQueueDrained()
    XCTAssertEqual(log, ["event", "event handed to the SDK", "stop"])
  }

  func testEachCallThatAnswersLaterHoldsItsOwnTurn() async {
    addCallThatAnswersLater("event")
    addCallThatAnswersLater("link")
    addCallThatAnswersAtOnce("stop")

    queue.releaseAfterCurrentWork()
    await mainQueueDrained()
    XCTAssertEqual(log, ["event", "link"])

    queue.releaseAfterCurrentWork()
    await mainQueueDrained()
    XCTAssertEqual(log, ["event", "link", "stop"])
  }

  func testEndedTurnDoesNotEndALaterOne() async {
    addCallThatAnswersLater("event")
    addCallThatAnswersLater("link")
    addCallThatAnswersAtOnce("stop")

    queue.releaseAfterCurrentWork()
    queue.release(1)
    XCTAssertEqual(log, ["event", "link"])

    // The release asked for during the first turn arrives during the second.
    await mainQueueDrained()
    queue.release(1)
    XCTAssertEqual(log, ["event", "link"])

    queue.release(2)
    XCTAssertEqual(log, ["event", "link", "stop"])
  }

  func testReleaseAskedForBeforeACallDoesNotEndItsTurn() async {
    queue.release(1)
    queue.releaseAfterCurrentWork()
    addCallThatAnswersLater("event")
    addCallThatAnswersAtOnce("stop")

    await mainQueueDrained()
    XCTAssertEqual(log, ["event"])
  }
}
