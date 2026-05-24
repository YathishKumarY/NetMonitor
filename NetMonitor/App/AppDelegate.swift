import AppKit
import SwiftUI
import SwiftData
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var samplingEngine: SamplingEngine!
    private var alertEngine: AlertEngine!
    private var modelContainer: ModelContainer!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupModelContainer()
        setupSamplingEngine()
        setupStatusItem()
        setupPopover()
        setupAlertEngine()
        requestNotificationPermissions()
        registerForSleepWakeNotifications()
    }

    private func setupModelContainer() {
        do {
            modelContainer = try ModelContainer(for:
                InterfaceSample.self,
                AppTrafficSample.self,
                DailySummary.self,
                UsageAlert.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "arrow.up.arrow.down.circle",
                accessibilityDescription: "Network Monitor"
            )
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(
            width: Constants.popoverWidth,
            height: Constants.popoverHeight
        )
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarPopoverView(engine: samplingEngine)
                .modelContainer(modelContainer)
        )
    }

    private func setupSamplingEngine() {
        samplingEngine = SamplingEngine(modelContainer: modelContainer)
        samplingEngine.start()
    }

    private func setupAlertEngine() {
        alertEngine = AlertEngine(modelContainer: modelContainer)
        alertEngine.start()
    }

    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    private func registerForSleepWakeNotifications() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func systemWillSleep(_ notification: Notification) {
        samplingEngine.pause()
    }

    @objc private func systemDidWake(_ notification: Notification) {
        samplingEngine.resume()
    }
}
