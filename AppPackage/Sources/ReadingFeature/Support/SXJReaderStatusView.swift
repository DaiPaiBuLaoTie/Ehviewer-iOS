import AppModels
import Sharing
import SwiftUI
import UIKit

struct SXJReaderStatusView: View {
    @SharedReader(.sxjReaderOptions) private var options: SXJReaderOptions
    @State private var batteryLevel: Float = -1
    @State private var previousBatteryMonitoring = false
    let page: Int
    let total: Int

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            HStack(spacing: 10) {
                if options.showsPageNumber {
                    Text(verbatim: String(page) + " / " + String(total))
                }
                if options.showsTime {
                    Text(context.date, style: .time)
                }
                if options.showsBattery, batteryLevel >= 0 {
                    Text(verbatim: String(Int((batteryLevel * 100).rounded())) + "%")
                }
            }
            .font(.caption.monospacedDigit()).foregroundStyle(.white)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(.black.opacity(0.6), in: .capsule)
            .opacity(options.showsPageNumber || options.showsTime || options.showsBattery ? 1 : 0)
        }
        .allowsHitTesting(false)
        .onAppear {
            previousBatteryMonitoring = UIDevice.current.isBatteryMonitoringEnabled
            updateBatteryMonitoring()
        }
        .onChange(of: options.showsBattery) { _, _ in updateBatteryMonitoring() }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)) { _ in
            batteryLevel = UIDevice.current.batteryLevel
        }
        .onDisappear { UIDevice.current.isBatteryMonitoringEnabled = previousBatteryMonitoring }
    }

    private func updateBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = options.showsBattery || previousBatteryMonitoring
        batteryLevel = UIDevice.current.batteryLevel
    }
}
