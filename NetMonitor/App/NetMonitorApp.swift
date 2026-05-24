import SwiftUI
import SwiftData

@main
struct NetMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .frame(minWidth: 700, minHeight: 500)
        }
        .modelContainer(for: [
            InterfaceSample.self,
            AppTrafficSample.self,
            DailySummary.self,
            UsageAlert.self
        ])
        .windowStyle(.titleBar)
        .defaultSize(width: 900, height: 600)
    }
}
