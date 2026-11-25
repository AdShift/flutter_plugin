import AdshiftSDK
import Foundation

// Conversions between the SDK's types and the messages of the bridge contract.

extension ErrorMessage {
  init(_ error: Error) {
    let code: ErrorCodeMessage
    switch error {
    case AdShiftError.notStarted: code = .notStarted
    case AdShiftError.invalidAPIKey: code = .invalidApiKey
    case AdShiftError.trackingDisabled: code = .optedOut
    default: code = .unknown
    }
    let nsError = error as NSError
    self.init(
      code: code,
      message: nsError.localizedDescription,
      nativeCode: String(nsError.code),
      nativeDomain: nsError.domain
    )
  }

  /// The answer to a tracking call; `nil` when the event was accepted.
  static func tracking(response: [String: Any]?, error: Error?) -> ErrorMessage? {
    if let error {
      return ErrorMessage(error)
    }
    guard BridgeRules.isExcludedFromTracking(responseStatus: response?["status"] as? String) else {
      return nil
    }
    return ErrorMessage(code: .optedOut, message: "Tracking is disabled for this device")
  }
}

extension StartMessage {
  /// A second `start` is a success. The key is validated in the background, so
  /// a first answer usually says `pending`.
  init(response: [String: Any]?, error: Error?) {
    switch error {
    case AdShiftError.alreadyStarted?:
      self.init(success: true)
    case let error?:
      self.init(success: false, error: ErrorMessage(error))
    case nil:
      let keyStatus: KeyStatusMessage
      switch response?["api_key_validation_status"] as? String {
      case "valid": keyStatus = .valid
      case "invalid": keyStatus = .invalid
      default: keyStatus = .pending
      }
      self.init(success: true, keyStatus: keyStatus)
    }
  }
}

extension ConsentMessage {
  var sdkValue: AdShiftConsent {
    guard isUserSubjectToGdpr else {
      return .forNonGDPRUser()
    }
    return .forGDPRUser(
      hasConsentForDataUsage: hasConsentForDataUsage,
      hasConsentForAdsPersonalization: hasConsentForAdsPersonalization,
      hasConsentForAdStorage: hasConsentForAdStorage
    )
  }
}

extension ConsentSnapshotMessage {
  init(_ snapshot: ConsentSnapshot) {
    let source: ConsentSourceMessage
    switch snapshot.source {
    case .manual: source = .manual
    case .tcf: source = .tcf
    case .gpp: source = .gpp
    case .none: source = .none
    @unknown default: source = .none
    }
    self.init(
      source: source,
      gdprApplies: snapshot.gdprApplies.map(Int64.init),
      tcStringPresent: snapshot.tcStringPresent,
      gppPresent: snapshot.gppPresent,
      cmpDetected: snapshot.cmpDetected,
      adUserDataEnabled: snapshot.adUserDataEnabled,
      adPersonalizationEnabled: snapshot.adPersonalizationEnabled,
      adStorageEnabled: snapshot.adStorageEnabled,
      appliedAtMillis: snapshot.appliedAtMillis,
      adIdentifiersAllowed: BridgeRules.adIdentifiersAllowed(
        adStorageEnabled: snapshot.adStorageEnabled,
        adUserDataEnabled: snapshot.adUserDataEnabled
      )
    )
  }
}

extension ClipboardModeMessage {
  var sdkValue: DeferredDeepLinkClipboard {
    switch self {
    case .disabled: return .disabled
    case .prompt: return .prompt
    case .pasteControl: return .pasteControl
    }
  }
}

extension DeepLinkMessage {
  init(_ response: DeeplinkResponse) {
    let outcome = BridgeRules.linkOutcome(
      hasLink: response.deeplink != nil || response.deep_link_value != nil,
      subs: [
        response.deep_link_sub1,
        response.deep_link_sub2,
        response.deep_link_sub3,
        response.deep_link_sub4,
        response.deep_link_sub5,
      ],
      params: response.params,
      reportedIsDeferred: response.isDeferred,
      reportedStatus: response.status.flatMap { BridgeRules.LinkStatus(rawValue: $0.rawValue) },
      hasError: response.error != nil
    )
    let status: DeepLinkStatusMessage
    switch outcome.status {
    case .found: status = .found
    case .notFound: status = .notFound
    case .error: status = .error
    }
    self.init(
      status: status,
      isDeferred: outcome.isDeferred,
      deepLink: response.deeplink,
      deepLinkValue: response.deep_link_value,
      params: outcome.params,
      errorMessage: response.error.map(Self.describe),
      source: response.source.flatMap(Self.source),
      clickId: response.clickId,
      matchGuaranteed: response.matchGuaranteed,
      isFirstSession: response.isFirstSession,
      sub1: response.deep_link_sub1,
      sub2: response.deep_link_sub2,
      sub3: response.deep_link_sub3,
      sub4: response.deep_link_sub4,
      sub5: response.deep_link_sub5
    )
  }

  private static func source(_ source: DeepLinkSource) -> DeepLinkSourceMessage? {
    switch source {
    case .ul: return .universalLink
    case .scheme: return .scheme
    case .cta: return .cta
    case .push: return .push
    case .aak: return .adAttributionKit
    case .deferred: return .deferred
    case .foreign: return .foreign
    @unknown default: return nil
    }
  }

  private static func describe(_ error: DeepLinkError) -> String {
    switch error {
    case .decodingError: return "Decoding error"
    case .invalidURL: return "Invalid URL"
    case .deepLinkNotFound: return "Deep link not found"
    case .systemError(let message): return message
    case .timeout: return "Timeout"
    case .network: return "Network error"
    case .server: return "Server error"
    @unknown default: return "Unknown error"
    }
  }
}
