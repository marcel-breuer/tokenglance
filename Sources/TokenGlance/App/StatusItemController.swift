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
    button.image = NSImage(systemSymbolName: "chart.bar.xaxis", accessibilityDescription: nil)
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
    let tokens = dependencies.menuBarSummary?.totals.calculatedTotal ?? 0
    let label = tokens.formatted(
      .number.notation(.compactName).precision(.fractionLength(0...1)))
    button.title = " \(label) \(strings.todayShort)"
    button.toolTip = "TokenGlance \(strings.totalTokensTodayAccessibility(tokens))"
    button.sizeToFit()
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
