/// Deep link results waiting for the Dart side to listen, oldest first.
struct ResultBuffer<Element> {
  static var limit: Int { 20 }

  private var waiting: [(element: Element, isDeferred: Bool)] = []

  /// When full, the oldest direct result makes room. A deferred result is never
  /// dropped for a direct one: it comes once per install.
  mutating func add(_ element: Element, isDeferred: Bool) {
    if waiting.count >= Self.limit {
      if let direct = waiting.firstIndex(where: { !$0.isDeferred }) {
        waiting.remove(at: direct)
      } else if isDeferred {
        waiting.removeFirst()
      } else {
        return
      }
    }
    waiting.append((element, isDeferred))
  }

  mutating func takeAll() -> [Element] {
    defer { waiting = [] }
    return waiting.map(\.element)
  }
}
