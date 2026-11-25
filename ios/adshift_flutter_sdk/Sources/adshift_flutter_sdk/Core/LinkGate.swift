import Foundation

/// Decides which links reach the SDK, so that one tap is counted once.
///
/// - Nothing reaches the SDK before `initialize` has applied its options: a
///   link iOS delivers earlier is held.
/// - iOS can deliver one tap through both the scene and the application
///   delegate: deliveries of a URL less than `repeatWindow` apart are one tap.
/// - Once the SDK has the link of a delivery, the app passing the same URL
///   itself is that tap again and is not forwarded, however much later. The
///   next delivery of the URL by iOS is a new tap.
/// - A URL iOS never delivered goes out whenever the app passes it, once in
///   `repeatWindow`.
struct LinkGate<Link> {
  static var repeatWindow: TimeInterval { 2 }
  static var holdLimit: Int { 10 }
  static var memoryLimit: Int { 100 }

  private struct Trace {
    let url: String
    /// When iOS last delivered the URL; `nil` when it never did.
    var deliveredAt: TimeInterval?
    /// When the URL last went to the SDK.
    var forwardedAt: TimeInterval?

    /// Whether the SDK has the link of the latest delivery or, for a URL iOS
    /// never delivered, was given it less than `repeatWindow` ago.
    func isWithSdk(at now: TimeInterval) -> Bool {
      guard let forwardedAt else { return false }
      return forwardedAt > (deliveredAt ?? now) - LinkGate.repeatWindow
    }
  }

  private var isOpen = false
  private var forwardsSystemLinks = true
  private var held: [(url: String, link: Link)] = []
  /// The URLs seen last, oldest first, at most `memoryLimit`.
  private var traces: [Trace] = []

  /// A link delivered by iOS. True when it goes to the SDK now. With
  /// `forwardsSystemLinks` off it never does, but the delivery is remembered,
  /// so the app's own pass of the link goes out once.
  mutating func admitFromSystem(_ link: Link, url: String, at now: TimeInterval) -> Bool {
    let url = LinkSpelling.normalized(url)
    guard isOpen else {
      if !held.contains(where: { $0.url == url }) {
        if held.count == Self.holdLimit { held.removeFirst() }
        held.append((url, link))
      }
      return false
    }
    var trace = takeTrace(of: url)
    defer { keep(trace) }
    if let deliveredAt = trace.deliveredAt, now - deliveredAt < Self.repeatWindow {
      return false
    }
    trace.deliveredAt = now
    guard forwardsSystemLinks, !trace.isWithSdk(at: now) else { return false }
    trace.forwardedAt = now
    return true
  }

  /// A link the app passed itself. True when it goes to the SDK.
  mutating func admitFromApp(url: String, at now: TimeInterval) -> Bool {
    var trace = takeTrace(of: LinkSpelling.normalized(url))
    defer { keep(trace) }
    guard !trace.isWithSdk(at: now) else { return false }
    trace.forwardedAt = now
    return true
  }

  /// `initialize` has applied its options. Returns the held links to forward,
  /// none when the app handles links itself.
  mutating func open(forwardsSystemLinks: Bool, at now: TimeInterval) -> [Link] {
    isOpen = true
    self.forwardsSystemLinks = forwardsSystemLinks
    let waiting = held
    held = []
    for (url, _) in waiting {
      var trace = takeTrace(of: url)
      trace.deliveredAt = now
      if forwardsSystemLinks { trace.forwardedAt = now }
      keep(trace)
    }
    return forwardsSystemLinks ? waiting.map(\.link) : []
  }

  private mutating func takeTrace(of url: String) -> Trace {
    guard let index = traces.firstIndex(where: { $0.url == url }) else { return Trace(url: url) }
    return traces.remove(at: index)
  }

  private mutating func keep(_ trace: Trace) {
    traces.append(trace)
    if traces.count > Self.memoryLimit { traces.removeFirst() }
  }
}

/// One spelling for a URL, so the gate knows a link whichever way it came. iOS
/// hands a link over as it was written; a URL the app passes through Dart's
/// `Uri` has its scheme and host in lower case and its percent-escapes rewritten.
enum LinkSpelling {
  /// Scheme and host in lower case; percent-escapes of letters, digits and
  /// `-._~` decoded, any other escape in upper case.
  static func normalized(_ url: String) -> String {
    let text = normalizingEscapes(url)
    guard let colon = text.firstIndex(of: ":") else { return text }
    var end = text.index(after: colon)
    if text[end...].hasPrefix("//") {
      let authority = text.index(end, offsetBy: 2)
      end = text[authority...].firstIndex(where: { "/?#".contains($0) }) ?? text.endIndex
    }
    return text[..<end].lowercased() + text[end...]
  }

  private static func normalizingEscapes(_ url: String) -> String {
    var result = ""
    var rest = Substring(url)
    while let percent = rest.firstIndex(of: "%") {
      result += rest[..<percent]
      let digits = rest[percent...].dropFirst().prefix(2)
      guard digits.count == 2, digits.allSatisfy(\.isHexDigit), let byte = UInt8(digits, radix: 16)
      else {
        result += "%"
        rest = rest[rest.index(after: percent)...]
        continue
      }
      let character = Character(Unicode.Scalar(byte))
      let isUnreserved =
        character.isASCII && (character.isLetter || character.isNumber || "-._~".contains(character))
      result += isUnreserved ? String(character) : "%" + digits.uppercased()
      rest = rest[digits.endIndex...]
    }
    return result + rest
  }
}
