import AdshiftSDK
import UIKit

/// A link as iOS delivered it, so the SDK receives it through the matching entry point.
enum SystemLink {
  case connection(UIScene.ConnectionOptions)
  case activity(NSUserActivity)
  case url(URL)
}

/// The bridge state of the process. Plugin instances come and go with their
/// Flutter engines; the SDK, its one deep link listener and the links and
/// results in transit outlive them.
@MainActor
final class BridgeState {
  static let shared = BridgeState()

  private(set) var isInitialized = false
  private var pushPaths: Set<[String]> = []
  private var links = LinkGate<SystemLink>()
  private var results = ResultBuffer<DeepLinkMessage>()
  private weak var listener: AdshiftFlutterSdkPlugin?

  private init() {}

  private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

  /// Called by `initialize` once the options are applied: from here links reach the SDK.
  func didInitialize(_ plugin: AdshiftFlutterSdkPlugin, forwardsSystemLinks: Bool) {
    if isInitialized {
      // A repeated `initialize` means the Dart side restarted: results wait
      // until it listens again.
      if listener === plugin { listener = nil }
    } else {
      isInitialized = true
      // The SDK keeps every listener it is given, so it gets exactly one.
      Adshift.shared.onDeepLinkReceived { [self] response in
        let message = DeepLinkMessage(response)
        results.add(message, isDeferred: message.isDeferred)
        sendResults()
      }
    }
    links.open(forwardsSystemLinks: forwardsSystemLinks, at: now).forEach(forward)
  }

  /// The SDK appends every path it is given, so each distinct one is passed once.
  func addPushPath(_ path: [String]) {
    guard !path.isEmpty, !path.contains(where: \.isEmpty) else { return }
    guard pushPaths.insert(path).inserted else { return }
    Adshift.shared.addPushNotificationDeepLinkPath(path)
  }

  // MARK: - Links in

  func receive(_ options: UIScene.ConnectionOptions) {
    let urls = options.userActivities.compactMap(\.webLink) + options.urlContexts.map(\.url)
    if urls.count == 1 {
      receive(.connection(options), url: urls[0])
    } else {
      urls.forEach(receive)
    }
  }

  func receive(_ activity: NSUserActivity) {
    if let url = activity.webLink {
      receive(.activity(activity), url: url)
    }
  }

  func receive(_ url: URL) {
    receive(.url(url), url: url)
  }

  private func receive(_ link: SystemLink, url: URL) {
    if links.admitFromSystem(link, url: url.absoluteString, at: now) {
      forward(link)
    }
  }

  /// False when the same URL went to the SDK within the last two seconds.
  func admitLinkFromApp(_ url: URL) -> Bool {
    links.admitFromApp(url: url.absoluteString, at: now)
  }

  private func forward(_ link: SystemLink) {
    switch link {
    case .connection(let options):
      Adshift.shared.handleDeepLink(connectionOptions: options)
    case .activity(let activity):
      Adshift.shared.handleDeepLink(userActivity: activity)
    case .url(let url):
      Task { _ = try? await Adshift.shared.handleDeepLink(url: url) }
    }
  }

  // MARK: - Results out

  func listenerReady(_ plugin: AdshiftFlutterSdkPlugin) {
    listener = plugin
    sendResults()
  }

  private func sendResults() {
    guard let listener else { return }
    results.takeAll().forEach(listener.send)
  }
}

extension NSUserActivity {
  /// The URL of a Universal Link; `nil` for any other activity.
  fileprivate var webLink: URL? {
    activityType == NSUserActivityTypeBrowsingWeb ? webpageURL : nil
  }
}
