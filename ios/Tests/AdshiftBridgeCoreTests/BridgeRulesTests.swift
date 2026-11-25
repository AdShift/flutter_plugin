import XCTest

@testable import AdshiftBridgeCore

final class LinkOutcomeTests: XCTestCase {
  /// A deferred result can arrive with the routing value alone, no `isDeferred` or `status`.
  func testDeferredResultReportsFoundAndDeferred() {
    let outcome = BridgeRules.linkOutcome(
      hasLink: true,
      subs: [],
      params: nil,
      reportedIsDeferred: nil,
      reportedStatus: nil,
      hasError: false
    )

    XCTAssertEqual(outcome.status, .found)
    XCTAssertTrue(outcome.isDeferred)
    XCTAssertEqual(outcome.params, [:])
  }

  func testDeferredResultCarriesItsSubsInParams() {
    let outcome = BridgeRules.linkOutcome(
      hasLink: true,
      subs: ["spring", nil, "banner", nil, nil],
      params: nil,
      reportedIsDeferred: true,
      reportedStatus: .found,
      hasError: false
    )

    XCTAssertEqual(outcome.params, ["deep_link_sub1": "spring", "deep_link_sub3": "banner"])
  }

  func testSubDoesNotReplaceAParameterOfTheSameName() {
    let outcome = BridgeRules.linkOutcome(
      hasLink: true,
      subs: ["spring"],
      params: ["deep_link_sub1": "from-the-link"],
      reportedIsDeferred: true,
      reportedStatus: .found,
      hasError: false
    )

    XCTAssertEqual(outcome.params, ["deep_link_sub1": "from-the-link"])
  }

  func testDirectResultParamsAreTheLinkQueryAlone() {
    let outcome = BridgeRules.linkOutcome(
      hasLink: true,
      subs: ["spring", nil, nil, nil, nil],
      params: ["product_id": "7"],
      reportedIsDeferred: false,
      reportedStatus: .found,
      hasError: false
    )

    XCTAssertEqual(outcome.params, ["product_id": "7"])
  }

  func testDeferredLookupWithoutALinkReportsNotFound() {
    let outcome = BridgeRules.linkOutcome(
      hasLink: false,
      subs: [],
      params: nil,
      reportedIsDeferred: nil,
      reportedStatus: nil,
      hasError: false
    )

    XCTAssertEqual(outcome.status, .notFound)
    XCTAssertTrue(outcome.isDeferred)
  }

  func testDirectResultIsReportedAsTheSdkStatedIt() {
    let outcome = BridgeRules.linkOutcome(
      hasLink: true,
      subs: [],
      params: ["campaign": "spring"],
      reportedIsDeferred: false,
      reportedStatus: .found,
      hasError: false
    )

    XCTAssertEqual(
      outcome,
      BridgeRules.LinkOutcome(status: .found, isDeferred: false, params: ["campaign": "spring"])
    )
  }

  func testReportedNotFoundSurvivesAMissingLink() {
    let outcome = BridgeRules.linkOutcome(
      hasLink: false,
      subs: [],
      params: nil,
      reportedIsDeferred: false,
      reportedStatus: .notFound,
      hasError: false
    )

    XCTAssertEqual(outcome.status, .notFound)
    XCTAssertFalse(outcome.isDeferred)
  }

  /// A URL that is not an AdShift link is reported with its status, not as a found link.
  func testReportedNotFoundSurvivesAPresentLink() {
    let outcome = BridgeRules.linkOutcome(
      hasLink: true,
      subs: [],
      params: nil,
      reportedIsDeferred: false,
      reportedStatus: .notFound,
      hasError: false
    )

    XCTAssertEqual(outcome.status, .notFound)
  }

  func testErrorOutranksTheReportedStatus() {
    let outcome = BridgeRules.linkOutcome(
      hasLink: true,
      subs: [],
      params: nil,
      reportedIsDeferred: false,
      reportedStatus: .found,
      hasError: true
    )

    XCTAssertEqual(outcome.status, .error)
  }

  func testStatusNamesAreTheOnesTheSdkUses() {
    XCTAssertEqual(BridgeRules.LinkStatus(rawValue: "found"), .found)
    XCTAssertEqual(BridgeRules.LinkStatus(rawValue: "notFound"), .notFound)
    XCTAssertEqual(BridgeRules.LinkStatus(rawValue: "error"), .error)
  }
}

final class TrackingOutcomeTests: XCTestCase {
  func testExcludedDeviceIsRecognisedByItsStatus() {
    XCTAssertTrue(BridgeRules.isExcludedFromTracking(responseStatus: "opted_out"))
  }

  func testAcceptedEventIsNotAFailure() {
    XCTAssertFalse(BridgeRules.isExcludedFromTracking(responseStatus: "queued"))
    XCTAssertFalse(BridgeRules.isExcludedFromTracking(responseStatus: nil))
  }
}

final class ConsentRuleTests: XCTestCase {
  func testNothingDecidedLeavesTheIdentifierAllowed() {
    XCTAssertTrue(BridgeRules.adIdentifiersAllowed(adStorageEnabled: nil, adUserDataEnabled: nil))
  }

  func testBothGrantedAllowsTheIdentifier() {
    XCTAssertTrue(BridgeRules.adIdentifiersAllowed(adStorageEnabled: true, adUserDataEnabled: true))
  }

  func testEitherDenialWithholdsTheIdentifier() {
    XCTAssertFalse(BridgeRules.adIdentifiersAllowed(adStorageEnabled: true, adUserDataEnabled: false))
    XCTAssertFalse(BridgeRules.adIdentifiersAllowed(adStorageEnabled: false, adUserDataEnabled: true))
    XCTAssertFalse(BridgeRules.adIdentifiersAllowed(adStorageEnabled: nil, adUserDataEnabled: false))
  }
}

final class OptionRuleTests: XCTestCase {
  func testDurationIsPassedAsGiven() {
    XCTAssertEqual(BridgeRules.milliseconds(0), 0)
    XCTAssertEqual(BridgeRules.milliseconds(10_000), 10_000)
  }

  func testNegativeDurationIsNotApplied() {
    XCTAssertNil(BridgeRules.milliseconds(-1))
  }

  func testDurationIsCapped() {
    XCTAssertEqual(BridgeRules.milliseconds(.max), Int(Int32.max))
  }
}
