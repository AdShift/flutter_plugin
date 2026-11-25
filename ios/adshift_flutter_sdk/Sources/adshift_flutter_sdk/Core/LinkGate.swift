import Foundation

/// Decides which links reach the SDK. None does before `initialize` has applied
/// its options: a link that arrives earlier is held. One URL is let through once
/// in `repeatWindow`, whether iOS delivered it twice or the app also passed it.
struct LinkGate<Link> {
  static var repeatWindow: TimeInterval { 2 }
  static var holdLimit: Int { 10 }

  private var isOpen = false
  private var forwardsSystemLinks = true
  private var held: [(url: String, link: Link)] = []
  private var forwardedAt: [String: TimeInterval] = [:]

  /// A link delivered by iOS. True when it goes to the SDK now.
  mutating func admitFromSystem(_ link: Link, url: String, at now: TimeInterval) -> Bool {
    let url = LinkSpelling.normalized(url)
    guard isOpen else {
      if !held.contains(where: { $0.url == url }) {
        if held.count == Self.holdLimit { held.removeFirst() }
        held.append((url, link))
      }
      return false
    }
    return forwardsSystemLinks && admit(url, at: now)
  }

  /// A link the app passed itself. True when it goes to the SDK.
  mutating func admitFromApp(url: String, at now: TimeInterval) -> Bool {
    admit(LinkSpelling.normalized(url), at: now)
  }

  /// `initialize` has applied its options. Returns the held links to forward,
  /// none when the app handles links itself.
  mutating func open(forwardsSystemLinks: Bool, at now: TimeInterval) -> [Link] {
    isOpen = true
    self.forwardsSystemLinks = forwardsSystemLinks
    let waiting = forwardsSystemLinks ? held : []
    held = []
    for (url, _) in waiting {
      forwardedAt[url] = now
    }
    return waiting.map(\.link)
  }

  private mutating func admit(_ url: String, at now: TimeInterval) -> Bool {
    forwardedAt = forwardedAt.filter { now - $0.value < Self.repeatWindow }
    guard forwardedAt[url] == nil else { return false }
    forwardedAt[url] = now
    return true
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
