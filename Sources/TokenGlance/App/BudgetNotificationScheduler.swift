import Foundation
import UserNotifications
import TokenGlanceCore

@MainActor
final class BudgetNotificationScheduler {
  private let center = UNUserNotificationCenter.current()

  func deliver(_ alert: UsageBudgetAlert, language: AppLanguage) async -> Bool {
    let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
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
    do {
      try await center.add(request)
      return true
    } catch {
      return false
    }
  }
}
