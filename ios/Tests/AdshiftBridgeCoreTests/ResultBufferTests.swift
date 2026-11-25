import XCTest

@testable import AdshiftBridgeCore

final class ResultBufferTests: XCTestCase {
  private let limit = ResultBuffer<String>.limit

  private func fullBuffer(deferredAt deferred: Set<Int> = []) -> ResultBuffer<String> {
    var buffer = ResultBuffer<String>()
    for index in 0..<limit {
      buffer.add("\(index)", isDeferred: deferred.contains(index))
    }
    return buffer
  }

  func testResultsComeOutInTheOrderTheyCameIn() {
    var buffer = ResultBuffer<String>()
    buffer.add("a", isDeferred: false)
    buffer.add("b", isDeferred: true)
    buffer.add("c", isDeferred: false)

    XCTAssertEqual(buffer.takeAll(), ["a", "b", "c"])
  }

  func testEachResultIsHandedOutOnce() {
    var buffer = ResultBuffer<String>()
    buffer.add("a", isDeferred: false)
    _ = buffer.takeAll()

    XCTAssertEqual(buffer.takeAll(), [])
  }

  func testFullBufferDropsItsOldestDirectResult() {
    var buffer = fullBuffer()
    buffer.add("new", isDeferred: false)

    let results = buffer.takeAll()
    XCTAssertEqual(results.count, limit)
    XCTAssertEqual(results.first, "1")
    XCTAssertEqual(results.last, "new")
  }

  func testDeferredResultIsKeptWhileADirectOneCanGo() {
    var buffer = fullBuffer(deferredAt: [0])
    buffer.add("new", isDeferred: false)

    let results = buffer.takeAll()
    XCTAssertEqual(results.count, limit)
    XCTAssertEqual(Array(results.prefix(2)), ["0", "2"])
    XCTAssertEqual(results.last, "new")
  }

  func testNewDeferredResultTakesThePlaceOfADirectOne() {
    var buffer = fullBuffer()
    buffer.add("deferred", isDeferred: true)

    let results = buffer.takeAll()
    XCTAssertEqual(results.first, "1")
    XCTAssertEqual(results.last, "deferred")
  }

  func testDirectResultNeverPushesOutADeferredOne() {
    var buffer = fullBuffer(deferredAt: Set(0..<limit))
    buffer.add("direct", isDeferred: false)

    XCTAssertEqual(buffer.takeAll(), (0..<limit).map(String.init))
  }

  func testAmongDeferredResultsTheOldestGoes() {
    var buffer = fullBuffer(deferredAt: Set(0..<limit))
    buffer.add("new", isDeferred: true)

    let results = buffer.takeAll()
    XCTAssertEqual(results.count, limit)
    XCTAssertEqual(results.first, "1")
    XCTAssertEqual(results.last, "new")
  }
}
