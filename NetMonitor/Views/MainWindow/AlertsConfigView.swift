import SwiftUI
import SwiftData

struct AlertsConfigView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = AlertsViewModel()
    @State private var showingAddSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Usage Alerts")
                    .font(.title2.bold())
                Spacer()
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Alert", systemImage: "plus")
                }
            }

            if viewModel.alerts.isEmpty {
                ContentUnavailableView(
                    "No Alerts",
                    systemImage: "bell.slash",
                    description: Text("Add an alert to get notified when your network usage exceeds a threshold.")
                )
            } else {
                List {
                    ForEach(viewModel.alerts, id: \.id) { alert in
                        AlertRow(alert: alert, viewModel: viewModel, modelContext: modelContext)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.deleteAlert(viewModel.alerts[index], modelContext: modelContext)
                        }
                    }
                }
            }
        }
        .padding(20)
        .onAppear {
            viewModel.loadAlerts(modelContext: modelContext)
        }
        .sheet(isPresented: $showingAddSheet) {
            AddAlertSheet(viewModel: viewModel, modelContext: modelContext)
        }
    }
}

struct AlertRow: View {
    let alert: UsageAlert
    let viewModel: AlertsViewModel
    let modelContext: ModelContext

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(alert.name)
                    .font(.headline)
                HStack(spacing: 8) {
                    Text(ByteCountFormatter.formatBytes(alert.thresholdBytes))
                    Text(alert.period.rawValue.capitalized)
                    Text(alert.direction.rawValue.capitalized)
                    if let filter = alert.interfaceFilter {
                        Text(filter.capitalized)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let lastTriggered = alert.lastTriggeredDate {
                    Text("Last triggered: \(lastTriggered, style: .relative) ago")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { alert.isEnabled },
                set: { _ in viewModel.toggleAlert(alert, modelContext: modelContext) }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

struct AddAlertSheet: View {
    let viewModel: AlertsViewModel
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var thresholdGB: Double = 1.0
    @State private var period: AlertPeriod = .daily
    @State private var direction: TrafficDirection = .both
    @State private var interfaceFilter: String? = nil
    @State private var selectedInterface = "All"

    var body: some View {
        VStack(spacing: 20) {
            Text("New Usage Alert")
                .font(.title2.bold())

            Form {
                TextField("Alert Name", text: $name)

                HStack {
                    Text("Threshold")
                    Slider(value: $thresholdGB, in: 0.1...100, step: 0.1)
                    Text("\(thresholdGB, specifier: "%.1f") GB")
                        .monospacedDigit()
                        .frame(width: 70)
                }

                Picker("Period", selection: $period) {
                    ForEach(AlertPeriod.allCases, id: \.self) { p in
                        Text(p.rawValue.capitalized).tag(p)
                    }
                }

                Picker("Direction", selection: $direction) {
                    ForEach(TrafficDirection.allCases, id: \.self) { d in
                        Text(d.rawValue.capitalized).tag(d)
                    }
                }

                Picker("Interface", selection: $selectedInterface) {
                    Text("All").tag("All")
                    Text("WiFi").tag("wifi")
                    Text("Hotspot").tag("hotspot")
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add Alert") {
                    let filter = selectedInterface == "All" ? nil : selectedInterface
                    let thresholdBytes = Int64(thresholdGB * 1_073_741_824)
                    viewModel.addAlert(
                        name: name.isEmpty ? "Usage Alert" : name,
                        thresholdBytes: thresholdBytes,
                        period: period,
                        direction: direction,
                        interfaceFilter: filter,
                        appFilter: nil,
                        modelContext: modelContext
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}
