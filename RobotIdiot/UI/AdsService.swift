import GoogleMobileAds
import UIKit

/// Identifiants AdMob.
/// DEBUG : unités de test Google (simulateur et device).
/// Release : unités de production.
enum AdUnit {
#if DEBUG
    static let launchInterstitial = "ca-app-pub-3940256099942544/4411468910"
    static let homeBanner = "ca-app-pub-3940256099942544/2934735716"
    static let helpRewardedInterstitial = "ca-app-pub-3940256099942544/6978759866"
    static let levelSuccessInterstitial = "ca-app-pub-3940256099942544/4411468910"
    static let errorInterstitial = "ca-app-pub-3940256099942544/4411468910"
#else
    static let launchInterstitial = "ca-app-pub-9540216894729209/7972568678"
    static let homeBanner = "ca-app-pub-9540216894729209/5430165810"
    static let helpRewardedInterstitial = "ca-app-pub-9540216894729209/3985047191"
    static let levelSuccessInterstitial = "ca-app-pub-9540216894729209/3594164951"
    static let errorInterstitial = "ca-app-pub-9540216894729209/9521666092"
#endif
}

/// Chargement et présentation des pubs AdMob.
@MainActor
final class AdsService: NSObject {
    static let shared = AdsService()

    private var isStarted = false
    private var launchInterstitial: InterstitialAd?
    private var successInterstitial: InterstitialAd?
    private var errorInterstitial: InterstitialAd?
    private var helpRewarded: RewardedInterstitialAd?

    private var pendingCompletion: (() -> Void)?
    private var didShowLaunchInterstitial = false
    private var isPresenting = false

    private override init() {
        super.init()
    }

    func start(completion: (() -> Void)? = nil) {
        guard !isStarted else {
            completion?()
            return
        }
        isStarted = true
#if DEBUG
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [
            "GADSimulatorID"
        ]
#endif
        MobileAds.shared.start { [weak self] _ in
            Task { @MainActor in
                self?.preloadAll()
                completion?()
            }
        }
    }

    func preloadAll() {
        loadLaunchInterstitial()
        loadSuccessInterstitial()
        loadErrorInterstitial()
        loadHelpRewarded()
    }

    // MARK: - Launch

    func showLaunchInterstitialIfNeeded(from controller: UIViewController) {
        guard !didShowLaunchInterstitial else { return }
        waitForInterstitial(
            getter: { [weak self] in self?.launchInterstitial },
            loader: { [weak self] in self?.loadLaunchInterstitial() },
            timeout: 8
        ) { [weak self] ad in
            guard let self else { return }
            guard let ad else { return }
            self.didShowLaunchInterstitial = true
            self.launchInterstitial = nil
            self.present(interstitial: ad, from: controller) {
                self.loadLaunchInterstitial()
            }
        }
    }

    // MARK: - Banner

    func makeHomeBanner(rootViewController: UIViewController) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = AdUnit.homeBanner
        banner.rootViewController = rootViewController
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.heightAnchor.constraint(equalToConstant: AdSizeBanner.size.height).isActive = true
        banner.load(Request())
        return banner
    }

    // MARK: - Level success

    func showLevelSuccessInterstitial(from controller: UIViewController, then completion: @escaping () -> Void) {
        waitForInterstitial(
            getter: { [weak self] in self?.successInterstitial },
            loader: { [weak self] in self?.loadSuccessInterstitial() },
            timeout: 4
        ) { [weak self] ad in
            guard let self else {
                completion()
                return
            }
            guard let ad else {
                self.loadSuccessInterstitial()
                completion()
                return
            }
            self.successInterstitial = nil
            self.present(interstitial: ad, from: controller) {
                self.loadSuccessInterstitial()
                completion()
            }
        }
    }

    // MARK: - Error / Modifier

    func showErrorInterstitial(from controller: UIViewController, then completion: @escaping () -> Void) {
        waitForInterstitial(
            getter: { [weak self] in self?.errorInterstitial },
            loader: { [weak self] in self?.loadErrorInterstitial() },
            timeout: 3
        ) { [weak self] ad in
            guard let self else {
                completion()
                return
            }
            guard let ad else {
                self.loadErrorInterstitial()
                completion()
                return
            }
            self.errorInterstitial = nil
            self.present(interstitial: ad, from: controller) {
                self.loadErrorInterstitial()
                completion()
            }
        }
    }

    // MARK: - Help rewarded

    func showHelpRewarded(
        from controller: UIViewController,
        onReward: @escaping () -> Void,
        onUnavailable: (() -> Void)? = nil
    ) {
        waitForRewarded(timeout: 5) { [weak self] ad in
            guard let self else {
                onUnavailable?()
                return
            }
            guard let ad else {
                self.loadHelpRewarded()
                onUnavailable?()
                return
            }
            self.helpRewarded = nil
            guard !self.isPresenting else {
                self.loadHelpRewarded()
                onUnavailable?()
                return
            }
            self.isPresenting = true
            ad.fullScreenContentDelegate = self
            var rewarded = false
            self.pendingCompletion = { [weak self] in
                self?.isPresenting = false
                self?.loadHelpRewarded()
                if rewarded {
                    onReward()
                } else {
                    onUnavailable?()
                }
            }
            let presenter = Self.topPresenter(from: controller)
            ad.present(from: presenter) {
                rewarded = true
            }
        }
    }

    // MARK: - Presentation helpers

    private func present(interstitial ad: InterstitialAd, from controller: UIViewController, then completion: @escaping () -> Void) {
        guard !isPresenting else {
            completion()
            return
        }
        isPresenting = true
        ad.fullScreenContentDelegate = self
        pendingCompletion = { [weak self] in
            self?.isPresenting = false
            completion()
        }
        let presenter = Self.topPresenter(from: controller)
        ad.present(from: presenter)
    }

    private static func topPresenter(from controller: UIViewController) -> UIViewController {
        var top = controller
        while let presented = top.presentedViewController {
            top = presented
        }
        if let nav = top as? UINavigationController, let visible = nav.visibleViewController {
            return visible
        }
        return top
    }

    private func waitForInterstitial(
        getter: @escaping () -> InterstitialAd?,
        loader: @escaping () -> Void,
        timeout: TimeInterval,
        completion: @escaping (InterstitialAd?) -> Void
    ) {
        if let ad = getter() {
            completion(ad)
            return
        }
        loader()
        let started = Date()
        Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { timer in
            Task { @MainActor in
                if let ad = getter() {
                    timer.invalidate()
                    completion(ad)
                    return
                }
                if Date().timeIntervalSince(started) >= timeout {
                    timer.invalidate()
                    completion(nil)
                } else {
                    loader()
                }
            }
        }
    }

    private func waitForRewarded(timeout: TimeInterval, completion: @escaping (RewardedInterstitialAd?) -> Void) {
        if let ad = helpRewarded {
            completion(ad)
            return
        }
        loadHelpRewarded()
        let started = Date()
        Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] timer in
            Task { @MainActor in
                if let ad = self?.helpRewarded {
                    timer.invalidate()
                    completion(ad)
                    return
                }
                if Date().timeIntervalSince(started) >= timeout {
                    timer.invalidate()
                    completion(nil)
                } else {
                    self?.loadHelpRewarded()
                }
            }
        }
    }

    // MARK: - Loading

    private func loadLaunchInterstitial() {
        guard launchInterstitial == nil else { return }
        InterstitialAd.load(with: AdUnit.launchInterstitial, request: Request()) { [weak self] ad, error in
            Task { @MainActor in
                if let error {
                    print("[Ads] launch load failed: \(error.localizedDescription)")
                }
                self?.launchInterstitial = ad
                ad?.fullScreenContentDelegate = self
            }
        }
    }

    private func loadSuccessInterstitial() {
        guard successInterstitial == nil else { return }
        InterstitialAd.load(with: AdUnit.levelSuccessInterstitial, request: Request()) { [weak self] ad, error in
            Task { @MainActor in
                if let error {
                    print("[Ads] success load failed: \(error.localizedDescription)")
                }
                self?.successInterstitial = ad
                ad?.fullScreenContentDelegate = self
            }
        }
    }

    private func loadErrorInterstitial() {
        guard errorInterstitial == nil else { return }
        InterstitialAd.load(with: AdUnit.errorInterstitial, request: Request()) { [weak self] ad, error in
            Task { @MainActor in
                if let error {
                    print("[Ads] error load failed: \(error.localizedDescription)")
                }
                self?.errorInterstitial = ad
                ad?.fullScreenContentDelegate = self
            }
        }
    }

    private func loadHelpRewarded() {
        guard helpRewarded == nil else { return }
        RewardedInterstitialAd.load(with: AdUnit.helpRewardedInterstitial, request: Request()) { [weak self] ad, error in
            Task { @MainActor in
                if let error {
                    print("[Ads] rewarded load failed: \(error.localizedDescription)")
                }
                self?.helpRewarded = ad
                ad?.fullScreenContentDelegate = self
            }
        }
    }

    private func finishPresentation() {
        let done = pendingCompletion
        pendingCompletion = nil
        done?()
    }
}

extension AdsService: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        finishPresentation()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("[Ads] present failed: \(error.localizedDescription)")
        finishPresentation()
    }
}
