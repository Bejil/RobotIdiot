import UIKit
import UserMessagingPlatform

/// Collecte le consentement UMP avant toute requête AdMob.
@MainActor
final class AdsConsentManager {
    static let shared = AdsConsentManager()

    private var isGathering = false

    var canRequestAds: Bool {
        UMPConsentInformation.sharedInstance.canRequestAds
    }

    var isPrivacyOptionsRequired: Bool {
        UMPConsentInformation.sharedInstance.privacyOptionsRequirementStatus == .required
    }

    private init() {}

    /// À appeler à chaque lancement. Présente le formulaire si nécessaire, puis démarre AdMob dès que possible.
    func gatherConsent(from viewController: UIViewController?, completion: ((Error?) -> Void)? = nil) {
        guard AdsService.areEnabled else {
            completion?(nil)
            return
        }
        guard !isGathering else {
            completion?(nil)
            return
        }
        isGathering = true

        let parameters = UMPRequestParameters()
#if DEBUG
        let debugSettings = UMPDebugSettings()
        // Force l’EEE pour tester le formulaire sur simulateur / device de debug.
        debugSettings.geography = .EEA
        parameters.debugSettings = debugSettings
#endif

        UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(with: parameters) { [weak self] requestError in
            Task { @MainActor in
                guard let self else { return }

                if let requestError {
                    print("[UMP] consent update failed: \(requestError.localizedDescription)")
                }

                // Consentement déjà obtenu lors d’une session précédente.
                self.startAdsIfAllowed()

                UMPConsentForm.loadAndPresentIfRequired(from: viewController) { formError in
                    Task { @MainActor in
                        if let formError {
                            print("[UMP] consent form failed: \(formError.localizedDescription)")
                        }
                        self.startAdsIfAllowed()
                        self.isGathering = false
                        completion?(formError ?? requestError)
                    }
                }
            }
        }
    }

    func presentPrivacyOptions(from viewController: UIViewController, completion: ((Error?) -> Void)? = nil) {
        UMPConsentForm.presentPrivacyOptionsForm(from: viewController) { error in
            Task { @MainActor in
                if let error {
                    print("[UMP] privacy options failed: \(error.localizedDescription)")
                }
                self.startAdsIfAllowed()
                completion?(error)
            }
        }
    }

    private func startAdsIfAllowed() {
        guard canRequestAds else { return }
        AdsService.shared.start()
    }
}
