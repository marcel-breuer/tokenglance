import Foundation
import UserNotifications
import TokenGlanceCore

@MainActor
final class BudgetNotificationScheduler {
  private let center = UNUserNotificationCenter.current()

  func deliver(_ alert: UsageBudgetAlert, language: AppLanguage) async -> Bool {
    let granted: Bool = await withCheckedContinuation { continuation in
      center.requestAuthorization(options: [.alert, .sound]) { allowed, _ in
        continuation.resume(returning: allowed)
      }
    }
    guard granted else { return false }

    let content = UNMutableNotificationContent()
    let amount = switch alert.metric {
    case .tokens: "\(Int(alert.currentAmount).formatted()) tokens"
    case .estimatedCost: alert.currentAmount.formatted(.currency(code: "USD"))
    }
    let strings = AppStrings(language)
    content.title = strings.budgetNotificationTitle
    content.body = strings.budgetNotificationBody(
      name: alert.budgetName, forecast: alert.isForecast,
      threshold: alert.threshold, amount: amount)
    content.sound = .default
    let request = UNNotificationRequest(identifier: alert.id, content: content, trigger: nil)
    return await withCheckedContinuation { continuation in
      center.add(request) { error in
        continuation.resume(returning: error == nil)
      }
    }
  }
}
