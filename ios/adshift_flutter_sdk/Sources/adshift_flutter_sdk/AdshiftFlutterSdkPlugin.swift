import AdshiftSDK
import Flutter
import UIKit

/// The iOS side of the plugin. Flutter creates one instance per engine. Only an
/// instance whose engine shows the app's UI drives the SDK and receives deep
/// link results; calls from any other engine, such as one that runs Dart in the
/// background, never reach the SDK.
@MainActor
public final class AdshiftFlutterSdkPlugin: NSObject, @preconcurrency FlutterPlugin,
  @preconcurrency FlutterSceneLifeCycleDelegate, @preconcurrency AdshiftHostApi
{
  private let state = BridgeState.shared
  private let calls = CallQueue()
  private weak var registrar: FlutterPluginRegistrar?
  private let flutterApi: AdshiftFlutterApi

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = AdshiftFlutterSdkPlugin(registrar: registrar)
    AdshiftHostApiSetup.setUp(
      binaryMessenger: QueuedMessenger(registrar.messenger(), calls: instance.calls),
      api: instance
    )
    registrar.addApplicationDelegate(instance)
    registrar.addSceneDelegate(instance)
  }

  private init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    flutterApi = AdshiftFlutterApi(binaryMessenger: registrar.messenger())
  }

  /// Read on every call: an engine gets its view controller after its plugins are registered.
  private var showsUI: Bool {
    registrar?.viewController != nil
  }

  /// Why a call from this instance cannot reach the SDK; `nil` when it can.
  private var refusal: ErrorMessage? {
    guard showsUI else {
      return ErrorMessage(
        code: .notInitialized,
        message: "AdShift runs only in the Flutter engine that shows the app's UI"
      )
    }
    guard state.isInitialized else {
      return ErrorMessage(code: .notInitialized, message: "Call initialize() first")
    }
    return nil
  }

  private var sdk: Adshift? {
    refusal == nil ? Adshift.shared : nil
  }

  func send(_ link: DeepLinkMessage) {
    Task { [flutterApi] in
      try? await flutterApi.onDeepLink(link: link)
    }
  }

  // MARK: - AdshiftHostApi

  // The calls arrive through `calls`, one at a time. A method that answers at
  // once has made its SDK call when it returns. An `async` method lets the
  // next call through with `releaseAfterCurrentWork()` and must not suspend
  // between that and its SDK call.

  func initialize(options: InitializeMessage) -> ErrorMessage? {
    guard showsUI else { return refusal }
    let sdk = Adshift.shared
    sdk.wrapper = "flutter"
    if let isDebug = options.isDebug {
      sdk.isDebug = isDebug
    }
    if !options.apiKey.isEmpty {
      sdk.apiKey = options.apiKey
    }
    if let debounce = options.appOpenDebounceMs.flatMap(BridgeRules.milliseconds) {
      sdk.appOpenDebounceMs = debounce
    }
    if let disableSkan = options.disableSkan {
      sdk.disableSKAN = disableSkan
    }
    if let waitForAtt = options.waitForAttBeforeStart {
      sdk.waitForATTBeforeStart = waitForAtt
    }
    if let timeout = options.attTimeoutMs.flatMap(BridgeRules.milliseconds) {
      sdk.attTimeoutMs = timeout
    }
    if let domains = options.brandedDomains {
      sdk.brandedDomains = domains
    }
    if let testMode = options.testMode {
      sdk.testMode = testMode
    }
    if let clipboard = options.deferredDeepLinkClipboard {
      sdk.deferredDeepLinkClipboard = clipboard.sdkValue
    }
    options.pushDeepLinkPaths?.forEach(state.addPushPath)
    // `metaAppId` and `collectOaid` apply to Android only.
    state.didInitialize(self, forwardsSystemLinks: options.autoHandleDeepLinks ?? true)
    return nil
  }

  func start() async -> StartMessage {
    calls.releaseAfterCurrentWork()
    if let refusal {
      return StartMessage(success: false, error: refusal)
    }
    return await withCheckedContinuation { continuation in
      Adshift.shared.start { response, error in
        continuation.resume(returning: StartMessage(response: response, error: error))
      }
    }
  }

  func stop() {
    sdk?.stop()
  }

  func setCustomerUserId(userId: String) {
    sdk?.setCustomerUserId(userId)
  }

  func setDebugEnabled(enabled: Bool) {
    sdk?.isDebug = enabled
  }

  func setAppOpenDebounceMs(ms: Int64) {
    if let debounce = BridgeRules.milliseconds(ms) {
      sdk?.appOpenDebounceMs = debounce
    }
  }

  func setBrandedDomains(domains: [String]) {
    sdk?.brandedDomains = domains
  }

  /// Android only.
  func setMetaAppId(appId: String) {}

  /// Android only.
  func setOaidData(oaid: String) {}

  func setConsentData(consent: ConsentMessage) {
    sdk?.setConsentData(consent.sdkValue)
  }

  func enableTcfDataCollection(enabled: Bool) {
    sdk?.enableTCFDataCollection(enabled)
  }

  func enableGppDataCollection(enabled: Bool) {
    sdk?.enableGPPDataCollection(enabled)
  }

  func setThirdPartySharing(optOut: Bool) {
    sdk?.setThirdPartySharing(optOut ? .optedOut() : .allowed())
  }

  func clearThirdPartySharing() {
    sdk?.clearThirdPartySharing()
  }

  func refreshConsent() -> ConsentSnapshotMessage? {
    sdk.map { ConsentSnapshotMessage($0.refreshConsent()) }
  }

  /// Every event is passed by name.
  func trackEvent(name: String, values: [String: Any?]) async -> ErrorMessage? {
    calls.releaseAfterCurrentWork()
    guard let sdk else { return refusal }
    var answer: ErrorMessage?
    await sdk.track(event: .customEvent(name), values: EventValues.native(values)) { response, error in
      answer = .tracking(response: response, error: error)
    }
    return answer
  }

  func trackPurchase(productId: String, price: Double, currency: String, token: String) async
    -> ErrorMessage?
  {
    calls.releaseAfterCurrentWork()
    guard let sdk else { return refusal }
    var answer: ErrorMessage?
    await sdk.trackPurchase(productId: productId, price: price, currency: currency, token: token) {
      response, error in
      answer = .tracking(response: response, error: error)
    }
    return answer
  }

  func logAdRevenue(data: AdRevenueMessage) async -> ErrorMessage? {
    calls.releaseAfterCurrentWork()
    guard let sdk else { return refusal }
    var parameters = EventValues.native(data.additionalParameters ?? [:])
    if let adUnitId = data.adUnitId {
      parameters[ASInAppEventParameterName.adRevenueAdUnitId] = adUnitId
    }
    if let precision = data.precision {
      parameters[ASInAppEventParameterName.adRevenuePrecision] = precision
    }
    await sdk.logAdRevenue(
      ASAdRevenueData(
        monetizationNetwork: data.monetizationNetwork,
        mediationNetwork: ASMediationNetwork(rawValue: data.mediationNetwork) ?? .other,
        currencyIso4217Code: data.currency,
        revenue: data.revenue
      ),
      additionalParameters: parameters.isEmpty ? nil : parameters
    )
    return nil
  }

  func getAdShiftDeviceId() -> String? {
    sdk?.getAdShiftDeviceId()
  }

  /// Answers without waiting for the SDK, which can take seconds to resolve a
  /// short link. The result arrives through the deep link listener only.
  func handleDeepLink(url: String) async -> ErrorMessage? {
    guard let sdk else {
      calls.releaseAfterCurrentWork()
      return refusal
    }
    guard let link = URL(string: url), link.scheme?.isEmpty == false else {
      calls.releaseAfterCurrentWork()
      return ErrorMessage(code: .invalidArgument, message: "url must be an absolute URL")
    }
    Task {
      calls.releaseAfterCurrentWork()
      if state.admitLinkFromApp(link) {
        _ = try? await sdk.handleDeepLink(url: link)
      }
    }
    return nil
  }

  /// `nil`, or a string that is not a URL, tells the SDK the user skipped the paste.
  func handlePastedDeepLink(url: String?) {
    sdk?.handlePastedDeepLink(url.flatMap(URL.init(string:)))
  }

  func addPushNotificationDeepLinkPath(path: [String]) {
    if sdk != nil {
      state.addPushPath(path)
    }
  }

  func handlePushNotification(payload: [String: Any?]) -> Bool {
    sdk?.handlePushNotification(userInfo: payload.compactMapValues { $0 }) ?? false
  }

  func deepLinkListenerReady() {
    if showsUI {
      state.listenerReady(self)
    }
  }

  // MARK: - Links from iOS

  // Each of these hands the link to the bridge and reports the event as not
  // handled, so the app's own routing and other plugins still receive it.

  public func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    if let connectionOptions {
      state.receive(connectionOptions)
    }
    return false
  }

  public func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    URLContexts.forEach { state.receive($0.url) }
    return false
  }

  public func scene(_ scene: UIScene, continue userActivity: NSUserActivity) -> Bool {
    state.receive(userActivity)
    return false
  }

  /// Returns true: false here would stop the launch for the whole app.
  public func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [AnyHashable: Any] = [:]
  ) -> Bool {
    if let url = launchOptions[UIApplication.LaunchOptionsKey.url] as? URL {
      state.receive(url)
    }
    let activities = launchOptions[UIApplication.LaunchOptionsKey.userActivityDictionary]
    for case let activity as NSUserActivity in (activities as? [AnyHashable: Any] ?? [:]).values {
      state.receive(activity)
    }
    return true
  }

  public func application(
    _ application: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    state.receive(url)
    return false
  }

  public func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([Any]) -> Void
  ) -> Bool {
    state.receive(userActivity)
    return false
  }
}
