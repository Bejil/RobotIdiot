import UIKit
import UserNotifications

/// Rappel local quotidien (récurrent) pour les défis du jour — sans Firebase.
enum DailyReminderNotifications {
    static let openDailyHub = Notification.Name("robotidiot.openDailyHub")
    static let requestIdentifier = "robotidiot.dailyChallenges.reminder"
    /// Heure locale du rappel (réveil / matin).
    static let hour = 9
    static let minute = 0

    /// Resynchronise le rappel si la permission système est déjà accordée.
    static func refresh() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                scheduleRepeatingReminder()
            default:
                cancel()
            }
        }
    }

    /// Pitch au lancement : au plus une fois par jour civil (heure de l'appareil).
    static func promptAtLaunch(from controller: UIViewController) {
        promptIfNeeded(from: controller, reason: .launch)
    }

    /// Pitch après la victoire d'un défi / bug du jour (même plafond une fois / jour).
    static func promptAfterDailyVictory(from controller: UIViewController) {
        promptIfNeeded(from: controller, reason: .dailyVictory)
    }

    private enum PromptReason {
        case launch
        case dailyVictory
    }

    private static func promptIfNeeded(from controller: UIViewController, reason: PromptReason) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    scheduleRepeatingReminder()
                case .notDetermined:
                    guard !alreadyPromptedToday else { return }
                    presentPitch(from: controller)
                case .denied:
                    guard !alreadyPromptedToday else { return }
                    // Au lancement : une fois si pas encore « vu » ; après un défi : même règle jour + hint.
                    if reason == .launch || !PlaySettings.notificationDeniedHintSeen {
                        presentDeniedHelpIfNeeded(from: controller)
                    }
                @unknown default:
                    break
                }
            }
        }
    }

    private static var alreadyPromptedToday: Bool {
        PlaySettings.lastNotificationPromptCivilDate == todayCivilDate()
    }

    private static func markPromptedToday() {
        PlaySettings.lastNotificationPromptCivilDate = todayCivilDate()
    }

    private static func todayCivilDate() -> String {
        let calendar = Calendar.current
        let parts = calendar.dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func handleResponse(_ response: UNNotificationResponse) {
        guard response.notification.request.identifier == requestIdentifier else { return }
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: openDailyHub, object: nil)
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [requestIdentifier])
    }

    private static func presentPitch(from controller: UIViewController) {
        guard controller.view.window != nil else { return }
        markPromptedToday()
        ChartedConfirmAlertView.present(
            from: controller,
            ribbon: "Défis du jour",
            headline: "Ne rate pas tes missions",
            detail: "Un petit rappel chaque matin à 9 h pour le niveau et le bug du jour. Aucun compte, aucune donnée envoyée : tout reste sur ton appareil.",
            confirmTitle: "Activer les rappels",
            cancelTitle: "Plus tard",
            accent: .primary,
            confirmSystemImage: "bell.badge"
        ) {
            requestAuthorizationAndSchedule()
        }
    }

    private static func presentDeniedHelpIfNeeded(from controller: UIViewController) {
        guard !PlaySettings.notificationDeniedHintSeen else { return }
        guard controller.view.window != nil else { return }
        markPromptedToday()
        ChartedConfirmAlertView.present(
            from: controller,
            ribbon: "Notifications",
            headline: "Rappels désactivés",
            detail: "Tu as refusé les notifications. Pour recevoir le rappel des défis du jour, active-les pour Robot Idiot dans les Réglages iOS.",
            confirmTitle: "Ouvrir Réglages",
            cancelTitle: "Plus tard",
            accent: .primary,
            confirmSystemImage: "gear",
            onCancel: {
                PlaySettings.notificationDeniedHintSeen = true
            },
            onConfirm: {
                PlaySettings.notificationDeniedHintSeen = true
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
        )
    }

    private static func requestAuthorizationAndSchedule() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    PlaySettings.notificationDeniedHintSeen = false
                    scheduleRepeatingReminder()
                } else {
                    cancel()
                }
            }
        }
    }

    private static func scheduleRepeatingReminder() {
        cancel()
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: requestIdentifier,
            content: reminderContent(),
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private static func reminderContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Défis du jour"
        content.body = "Le niveau et le bug du jour t'attendent. Un passage rapide ?"
        content.sound = .default
        content.userInfo = ["destination": "dailyHub"]
        return content
    }
}
