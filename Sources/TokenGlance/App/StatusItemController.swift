import AppKit
import Combine
import SwiftUI
import TokenGlanceCore

@MainActor
final class StatusItemController: NSObject, ObservableObject {
  private let dependencies: AppDependencies
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  private let popover = NSPopover()
  private var cancellables: Set<AnyCancellable> = []

  init(dependencies: AppDependencies) {
    self.dependencies = dependencies
    super.init()
    configurePopover()
    configureStatusItem()
    bindUpdates()
    dependencies.start()
  }

  private func configurePopover() {
    popover.behavior = .transient
    popover.contentSize = NSSize(width: 460, height: 640)
    popover.contentViewController = NSHostingController(
      rootView: DashboardView()
        .environmentObject(dependencies)
        .frame(width: 460, height: 640)
    )
  }

  private func configureStatusItem() {
    guard let button = statusItem.button else { return }
    button.image = symbolImage()
    button.imagePosition = .imageLeading
    button.target = self
    button.action = #selector(statusItemClicked(_:))
    button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    updateStatusItem()
  }

  private func bindUpdates() {
    dependencies.$menuBarSummary
      .combineLatest(dependencies.$settings)
      .receive(on: RunLoop.main)
      .sink { [weak self] _, _ in
        self?.updateStatusItem()
      }
      .store(in: &cancellables)
  }

  private func updateStatusItem() {
    guard let button = statusItem.button else { return }
    let strings = AppStrings(dependencies.settings.language)
    let summary = dependencies.menuBarSummary
    let totalTokens = summary?.totals.calculatedTotal ?? 0

    switch dependencies.settings.menuBarMetric {
    case .sparklineToday:
      statusItem.length = 44
      button.title = ""
      button.image = MenuBarSparklineRenderer.image(summary: summary)
      button.imagePosition = .imageOnly
      button.toolTip = "TokenGlance \(strings.tokenSparklineTodayAccessibility(totalTokens))"
    case .iconOnly:
      statusItem.length = NSStatusItem.squareLength
      button.title = ""
      button.image = symbolImage()
      button.imagePosition = .imageOnly
      button.toolTip = "TokenGlance \(strings.totalTokensTodayAccessibility(totalTokens))"
    case .totalToday, .lastHour, .inputToday, .outputToday:
      let metric = menuBarMetricText(summary: summary, strings: strings)
      statusItem.length = NSStatusItem.variableLength
      button.title = " \(metric.label)"
      button.image = symbolImage()
      button.imagePosition = .imageLeading
      button.toolTip = "TokenGlance \(metric.accessibilityText)"
      button.sizeToFit()
    }
  }

  private func menuBarMetricText(summary: UsageSummary?, strings: AppStrings) -> (
    label: String, accessibilityText: String
  ) {
    func label(_ value: Int) -> String {
      value.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
    }

    switch dependencies.settings.menuBarMetric {
    case .lastHour:
      let tokens = summary?.buckets.last?.tokens.calculatedTotal ?? 0
      let text = label(tokens)
      return (text, strings.lastHourAccessibility(text))
    case .inputToday:
      let tokens = summary?.totals.inputTokens ?? 0
      let text = label(tokens)
      return (text, strings.inputTodayAccessibility(text))
    case .outputToday:
      let tokens = summary?.totals.outputTokens ?? 0
      let text = label(tokens)
      return (text, strings.outputTodayAccessibility(text))
    case .totalToday, .sparklineToday, .iconOnly:
      let tokens = summary?.totals.calculatedTotal ?? 0
      return (label(tokens), strings.totalTokensTodayAccessibility(tokens))
    }
  }

  private func symbolImage() -> NSImage? {
    let image = NSImage(systemSymbolName: "chart.bar.xaxis", accessibilityDescription: nil)
    image?.isTemplate = true
    return image
  }

  @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
    guard let event = NSApp.currentEvent else { return }
    switch event.type {
    case .rightMouseUp:
      showContextMenu(from: sender)
    default:
      togglePopover(from: sender)
    }
  }

  private func togglePopover(from button: NSStatusBarButton) {
    if popover.isShown {
      popover.performClose(nil)
    } else {
      dependencies.start()
      popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
      popover.contentViewController?.view.window?.makeKey()
    }
  }

  private func showContextMenu(from button: NSStatusBarButton) {
    if popover.isShown {
      popover.performClose(nil)
    }
    let strings = AppStrings(dependencies.settings.language)
    let menu = NSMenu()
    menu.addItem(
      NSMenuItem(
        title: strings.quitTokenGlance,
        action: #selector(quitTokenGlance(_:)),
        keyEquivalent: "q"
      ))
    for item in menu.items {
      item.target = self
    }
    menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
  }

  @objc private func quitTokenGlance(_ sender: NSMenuItem) {
    NSApp.terminate(sender)
  }
}
