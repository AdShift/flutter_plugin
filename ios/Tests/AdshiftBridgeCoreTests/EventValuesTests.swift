import XCTest

@testable import AdshiftBridgeCore

final class EventValuesTests: XCTestCase {
  /// A reader that tries String, Int, Double, Bool, in this order.
  private func reading(_ value: Any?) -> String {
    switch value {
    case is String: return "string"
    case is Int: return "int"
    case is Double: return "double"
    case is Bool: return "bool"
    default: return "skipped"
    }
  }

  /// Values as a platform channel delivers them.
  private let fromChannel: [String: Any?] = [
    "flag": NSNumber(value: true),
    "off": NSNumber(value: false),
    "count": NSNumber(value: Int32(3)),
    "big": NSNumber(value: Int64(5_000_000_000)),
    "whole": NSNumber(value: 2.0),
    "price": NSNumber(value: 9.99),
    "name": "gold" as NSString,
  ]

  func testBooleanStaysABoolean() {
    let values = EventValues.native(fromChannel)

    XCTAssertEqual(reading(values["flag"]), "bool")
    XCTAssertEqual(values["flag"] as? Bool, true)
    XCTAssertEqual(reading(values["off"]), "bool")
    XCTAssertEqual(values["off"] as? Bool, false)
  }

  func testIntegerIsAnInt() {
    let values = EventValues.native(fromChannel)

    XCTAssertEqual(reading(values["count"]), "int")
    XCTAssertEqual(values["count"] as? Int, 3)
    XCTAssertEqual(reading(values["big"]), "int")
    XCTAssertEqual(values["big"] as? Int, 5_000_000_000)
  }

  func testWholeNumberDoubleStaysADouble() {
    let values = EventValues.native(fromChannel)

    XCTAssertEqual(reading(values["whole"]), "double")
    XCTAssertEqual(values["whole"] as? Double, 2.0)
    XCTAssertEqual(reading(values["price"]), "double")
    XCTAssertEqual(values["price"] as? Double, 9.99)
  }

  func testStringIsKept() {
    let values = EventValues.native(fromChannel)

    XCTAssertEqual(reading(values["name"]), "string")
    XCTAssertEqual(values["name"] as? String, "gold")
  }

  /// Without the conversion a boolean and a whole-number double would both be sent as integers.
  func testUnconvertedChannelNumbersReadAsIntegers() {
    XCTAssertEqual(reading(NSNumber(value: true)), "int")
    XCTAssertEqual(reading(NSNumber(value: 2.0)), "int")
  }

  func testSwiftValuesKeepTheirTypes() {
    let values = EventValues.native(["flag": true, "count": 3, "whole": 2.0, "name": "gold"])

    XCTAssertEqual(reading(values["flag"]), "bool")
    XCTAssertEqual(reading(values["count"]), "int")
    XCTAssertEqual(reading(values["whole"]), "double")
    XCTAssertEqual(reading(values["name"]), "string")
  }

  func testOtherValuesAreDropped() {
    let values = EventValues.native([
      "missing": nil,
      "null": NSNull(),
      "list": [1, 2] as NSArray,
      "map": ["a": 1] as NSDictionary,
      "kept": "yes",
    ])

    XCTAssertEqual(Array(values.keys), ["kept"])
  }
}
