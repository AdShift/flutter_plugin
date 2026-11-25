import XCTest

@testable import AdshiftBridgeCore

@MainActor
final class CallQueueTests: XCTestCase {
  private let queue = CallQueue()
  private var log: [String] = []

  /// A call that answers before it returns, as a synchronous bridge method does.
  private func addCallThatAnswersAtOnce(_ name: String) {
    queue.add { turn in
      self.log.append("\(name) begins")
      self.queue.release(turn)
      self.log.append("\(name) ends")
    }
  }

  /// A call that answers later: it is delivered and keeps its turn.
  private func addCallThatAnswersLater(_ name: String) {
    queue.add { _ in
      self.log.append(name)
    }
  }

  func testCallsThatAnswerAtOnceAreDeliveredAsTheyArrive() {
    addCallThatAnswersAtOnce("first")
    XCTAssertEqual(log, ["first begins", "first ends"])

    addCallThatAnswersAtOnce("second")
    XCTAssertEqual(log, ["first begins", "first ends", "second begins", "second ends"])
  }

  func testCallThatAnswersLaterHoldsTheFollowingOnesBack() {
    addCallThatAnswersLater("event")
    addCallThatAnswersAtOnce("stop")
    addCallThatAnswersLater("link")
    XCTAssertEqual(log, ["event"])

    queue.release(1)
    XCTAssertEqual(log, ["event", "stop begins", "stop ends", "link"])
  }

  func testEachCallThatAnswersLaterHoldsItsOwnTurn() {
    addCallThatAnswersLater("start")
    addCallThatAnswersLater("event")
    addCallThatAnswersAtOnce("stop")

    queue.release(1)
    XCTAssertEqual(log, ["start", "event"])

    queue.release(2)
    XCTAssertEqual(log, ["start", "event", "stop begins", "stop ends"])
  }

  /// The next call starts when the answering one has returned, not inside it.
  func testNextCallStartsAfterTheAnsweringOneHasReturned() {
    addCallThatAnswersLater("event")
    addCallThatAnswersAtOnce("stop")
    addCallThatAnswersAtOnce("setter")

    queue.release(1)
    XCTAssertEqual(log, ["event", "stop begins", "stop ends", "setter begins", "setter ends"])
  }

  func testSecondAnswerToACallDoesNotEndALaterTurn() {
    addCallThatAnswersLater("event")
    addCallThatAnswersLater("link")
    addCallThatAnswersAtOnce("stop")

    queue.release(1)
    queue.release(1)
    XCTAssertEqual(log, ["event", "link"])

    queue.release(2)
    XCTAssertEqual(log, ["event", "link", "stop begins", "stop ends"])
  }

  func testAnswerWithNothingDeliveredDoesNothing() {
    queue.release(1)
    addCallThatAnswersLater("event")
    addCallThatAnswersAtOnce("stop")

    XCTAssertEqual(log, ["event"])
  }
}
