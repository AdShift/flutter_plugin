import XCTest

@testable import AdshiftBridgeCore

final class LinkGateTests: XCTestCase {
  private let link = "https://brand.example/promo"
  private let other = "myapp://settings"

  private func openGate(forwardsSystemLinks: Bool = true) -> LinkGate<String> {
    var gate = LinkGate<String>()
    _ = gate.open(forwardsSystemLinks: forwardsSystemLinks, at: 0)
    return gate
  }

  // MARK: Before initialize

  func testLinkBeforeInitializeIsHeldAndForwardedAfterIt() {
    var gate = LinkGate<String>()

    XCTAssertFalse(gate.admitFromSystem("launch", url: link, at: 0))
    XCTAssertEqual(gate.open(forwardsSystemLinks: true, at: 1), ["launch"])
  }

  func testHeldLinksAreForwardedInTheOrderTheyCame() {
    var gate = LinkGate<String>()
    _ = gate.admitFromSystem("first", url: link, at: 0)
    _ = gate.admitFromSystem("second", url: other, at: 5)

    XCTAssertEqual(gate.open(forwardsSystemLinks: true, at: 6), ["first", "second"])
  }

  /// Both life cycles deliver the launch link in an app that uses the application delegate.
  func testSameUrlDeliveredTwiceBeforeInitializeIsHeldOnce() {
    var gate = LinkGate<String>()
    _ = gate.admitFromSystem("launch options", url: link, at: 0)
    _ = gate.admitFromSystem("open url", url: link, at: 0.1)

    XCTAssertEqual(gate.open(forwardsSystemLinks: true, at: 1), ["launch options"])
  }

  func testHeldLinksAreDroppedWhenTheAppHandlesLinksItself() {
    var gate = LinkGate<String>()
    _ = gate.admitFromSystem("launch", url: link, at: 0)

    XCTAssertEqual(gate.open(forwardsSystemLinks: false, at: 1), [])
    XCTAssertEqual(gate.open(forwardsSystemLinks: true, at: 2), [])
  }

  func testOnlyTheLatestLinksAreHeld() {
    var gate = LinkGate<Int>()
    let count = LinkGate<Int>.holdLimit + 3
    for index in 0..<count {
      _ = gate.admitFromSystem(index, url: "myapp://item/\(index)", at: 0)
    }

    XCTAssertEqual(gate.open(forwardsSystemLinks: true, at: 1), Array(3..<count))
  }

  func testHeldLinkPassedByTheAppRightAfterInitializeCountsOnce() {
    var gate = LinkGate<String>()
    _ = gate.admitFromSystem("launch", url: link, at: 0)
    _ = gate.open(forwardsSystemLinks: true, at: 10)

    XCTAssertFalse(gate.admitFromApp(url: link, at: 11))
  }

  // MARK: After initialize

  func testLinkAfterInitializeIsForwardedAtOnce() {
    var gate = openGate()

    XCTAssertTrue(gate.admitFromSystem("tap", url: link, at: 5))
  }

  func testSameUrlFromTheSystemTwiceIsForwardedOnce() {
    var gate = openGate()

    XCTAssertTrue(gate.admitFromSystem("scene", url: link, at: 5))
    XCTAssertFalse(gate.admitFromSystem("application", url: link, at: 5.2))
  }

  func testUrlPassedByTheAppAfterTheSystemDeliveredItCountsOnce() {
    var gate = openGate()

    XCTAssertTrue(gate.admitFromSystem("tap", url: link, at: 5))
    XCTAssertFalse(gate.admitFromApp(url: link, at: 6.9))
  }

  func testUrlDeliveredByTheSystemAfterTheAppPassedItCountsOnce() {
    var gate = openGate()

    XCTAssertTrue(gate.admitFromApp(url: link, at: 5))
    XCTAssertFalse(gate.admitFromSystem("tap", url: link, at: 5.5))
  }

  /// iOS delivers a link as it was written; the app passes it as Dart's `Uri` spells it.
  func testOneLinkInTwoSpellingsCountsOnce() {
    let asWritten = "HTTPS://Example.RightLink.me/x?a=%7e"
    let fromDart = "https://example.rightlink.me/x?a=~"

    var gate = openGate()
    XCTAssertTrue(gate.admitFromSystem("tap", url: asWritten, at: 5))
    XCTAssertFalse(gate.admitFromApp(url: fromDart, at: 5.5))

    gate = openGate()
    XCTAssertTrue(gate.admitFromApp(url: fromDart, at: 5))
    XCTAssertFalse(gate.admitFromSystem("tap", url: asWritten, at: 5.5))
  }

  func testHeldLinkInAnotherSpellingCountsOnce() {
    var gate = LinkGate<String>()
    _ = gate.admitFromSystem("launch", url: "HTTPS://Example.RightLink.me/x?a=%7e", at: 0)
    _ = gate.admitFromSystem("again", url: "https://example.rightlink.me/x?a=%7E", at: 0.1)

    XCTAssertEqual(gate.open(forwardsSystemLinks: true, at: 10), ["launch"])
    XCTAssertFalse(gate.admitFromApp(url: "https://example.rightlink.me/x?a=~", at: 11))
  }

  func testSameUrlAfterTheWindowIsANewTap() {
    var gate = openGate()

    XCTAssertTrue(gate.admitFromSystem("tap", url: link, at: 5))
    XCTAssertTrue(gate.admitFromSystem("tap again", url: link, at: 5 + LinkGate<String>.repeatWindow))
  }

  /// The window counts from the forwarded link, not from the repeats that were dropped.
  func testDroppedRepeatDoesNotExtendTheWindow() {
    var gate = openGate()

    XCTAssertTrue(gate.admitFromApp(url: link, at: 5))
    XCTAssertFalse(gate.admitFromApp(url: link, at: 6.5))
    XCTAssertTrue(gate.admitFromApp(url: link, at: 7.5))
  }

  func testDifferentUrlsDoNotAffectEachOther() {
    var gate = openGate()

    XCTAssertTrue(gate.admitFromSystem("link", url: link, at: 5))
    XCTAssertTrue(gate.admitFromSystem("other", url: other, at: 5))
  }

  func testSystemLinksAreNotForwardedWhenTheAppHandlesLinksItself() {
    var gate = openGate(forwardsSystemLinks: false)

    XCTAssertFalse(gate.admitFromSystem("tap", url: link, at: 5))
    XCTAssertTrue(gate.admitFromApp(url: link, at: 5.1))
  }

  func testLaterInitializeCanTurnForwardingOn() {
    var gate = openGate(forwardsSystemLinks: false)
    _ = gate.open(forwardsSystemLinks: true, at: 3)

    XCTAssertTrue(gate.admitFromSystem("tap", url: link, at: 5))
  }
}

final class LinkSpellingTests: XCTestCase {
  func testSchemeAndHostAreLowerCased() {
    XCTAssertEqual(
      LinkSpelling.normalized("HTTPS://Example.RightLink.me/Path?Key=Value#Part"),
      "https://example.rightlink.me/Path?Key=Value#Part"
    )
    XCTAssertEqual(LinkSpelling.normalized("https://EXAMPLE.com"), "https://example.com")
    XCTAssertEqual(LinkSpelling.normalized("MyApp://Promo/Item?x=1"), "myapp://promo/Item?x=1")
  }

  func testUrlWithoutAHostKeepsItsPath() {
    XCTAssertEqual(LinkSpelling.normalized("MyApp:Promo/Item"), "myapp:Promo/Item")
  }

  func testEscapedLettersDigitsAndMarksAreDecoded() {
    XCTAssertEqual(
      LinkSpelling.normalized("https://example.com/%41bc%2d%2E%5f%7e%30"),
      "https://example.com/Abc-._~0"
    )
    XCTAssertEqual(LinkSpelling.normalized("https://ex%41mple.com/"), "https://example.com/")
  }

  func testOtherEscapesAreKeptInUpperCase() {
    XCTAssertEqual(
      LinkSpelling.normalized("https://example.com/a%2fb?q=%c3%a9%20x&r=%7Bx%7d"),
      "https://example.com/a%2Fb?q=%C3%A9%20x&r=%7Bx%7D"
    )
  }

  func testTextThatIsNotAnEscapeIsKept() {
    XCTAssertEqual(LinkSpelling.normalized("myapp://sale/100%?off=5%+x%zz%4"), "myapp://sale/100%?off=5%+x%zz%4")
  }

  func testDifferentLinksStayDifferent() {
    XCTAssertNotEqual(
      LinkSpelling.normalized("https://example.com/Path"),
      LinkSpelling.normalized("https://example.com/path")
    )
    XCTAssertNotEqual(
      LinkSpelling.normalized("https://example.com/a%2Fb"),
      LinkSpelling.normalized("https://example.com/a/b")
    )
  }
}
