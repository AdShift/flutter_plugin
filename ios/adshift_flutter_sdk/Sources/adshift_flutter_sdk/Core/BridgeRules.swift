import Foundation

/// Rules of the bridge that need neither the AdShift SDK nor Flutter.
enum BridgeRules {
  enum LinkStatus: String {
    case found, notFound, error
  }

  struct LinkOutcome: Equatable {
    let status: LinkStatus
    let isDeferred: Bool
    let params: [String: String]
  }

  /// Fills in `isDeferred` and `status` when a result has none; an error outranks
  /// a reported status. The subs of a deferred result also go into `params`.
  static func linkOutcome(
    hasLink: Bool,
    subs: [String?],
    params: [String: String]?,
    reportedIsDeferred: Bool?,
    reportedStatus: LinkStatus?,
    hasError: Bool
  ) -> LinkOutcome {
    let isDeferred = reportedIsDeferred ?? (reportedStatus == nil)
    var resolvedParams = params ?? [:]
    if isDeferred {
      for (index, sub) in subs.prefix(5).enumerated() {
        let key = "deep_link_sub\(index + 1)"
        if let sub, resolvedParams[key] == nil {
          resolvedParams[key] = sub
        }
      }
    }
    let status = hasError ? .error : reportedStatus ?? (hasLink ? .found : .notFound)
    return LinkOutcome(status: status, isDeferred: isDeferred, params: resolvedParams)
  }

  /// An event of a device excluded from tracking is answered with this status, not an error.
  static func isExcludedFromTracking(responseStatus: String?) -> Bool {
    responseStatus == "opted_out"
  }

  /// An explicit `false` for either withholds the identifiers; `nil` (not decided) does not.
  static func adIdentifiersAllowed(adStorageEnabled: Bool?, adUserDataEnabled: Bool?) -> Bool {
    adStorageEnabled != false && adUserDataEnabled != false
  }

  /// `nil` for a negative duration, which is not applied.
  static func milliseconds(_ value: Int64) -> Int? {
    value >= 0 ? Int(min(value, Int64(Int32.max))) : nil
  }
}
