import SwiftUI

/// Glanceable status: connection, audio route (AirPods), speed, battery.
struct StatusStrip: View {
    @ObservedObject var vm: ActiveRideViewModel

    var body: some View {
        HStack(spacing: 8) {
            pill(icon: connIcon, text: connText, tint: connTint)
            pill(icon: vm.usingBluetooth ? "airpodspro" : "iphone",
                 text: vm.routeName, tint: vm.usingBluetooth ? .rideAccent : .secondary)
            pill(icon: "speedometer", text: "\(vm.speedMph) mph", tint: .primary)
            pill(icon: batteryIcon, text: "\(batteryPct)%", tint: vm.lowBattery ? .rideDanger : .primary)
        }
        .font(.caption.bold()).lineLimit(1).minimumScaleFactor(0.7)
    }

    private func pill(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 4) { Image(systemName: icon); Text(text) }
            .foregroundStyle(tint)
            .padding(.horizontal, 10).padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color.rideSurface, in: Capsule())
    }

    private var connIcon: String {
        switch vm.connectionState {
        case .connected: return "wifi"
        case .connecting, .reconnecting: return "wifi.exclamationmark"
        case .disconnected: return "wifi.slash"
        }
    }
    private var connText: String {
        switch vm.connectionState {
        case .connected: return "Live"
        case .connecting: return "Connecting"
        case .reconnecting: return "Reconnecting"
        case .disconnected: return "Offline"
        }
    }
    private var connTint: Color {
        switch vm.connectionState {
        case .connected: return .rideAccent
        case .connecting, .reconnecting: return .yellow
        case .disconnected: return .rideDanger
        }
    }

    private var batteryPct: Int { vm.batteryLevel >= 0 ? Int(vm.batteryLevel * 100) : 0 }
    private var batteryIcon: String {
        switch vm.batteryLevel {
        case ..<0.1: return "battery.0percent"
        case ..<0.4: return "battery.25percent"
        case ..<0.7: return "battery.50percent"
        case ..<0.95: return "battery.75percent"
        default: return "battery.100percent"
        }
    }
}
