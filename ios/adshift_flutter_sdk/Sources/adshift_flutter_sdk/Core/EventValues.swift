import Foundation

enum EventValues {
  /// Keeps strings, numbers and booleans, as `String`, `Int`, `Double` and `Bool`;
  /// drops everything else. A value from a platform channel is an `NSNumber`,
  /// which reads as an `Int` whenever it holds a boolean or a whole number, so
  /// each one is turned into the type it was sent as.
  static func native(_ values: [String: Any?]) -> [String: Any] {
    var result: [String: Any] = [:]
    for (key, value) in values {
      switch value {
      case let string as String:
        result[key] = string
      case let number as NSNumber:
        if CFGetTypeID(number) == CFBooleanGetTypeID() {
          result[key] = number.boolValue
        } else if CFNumberIsFloatType(number) {
          result[key] = number.doubleValue
        } else {
          result[key] = number.intValue
        }
      default:
        continue
      }
    }
    return result
  }
}
