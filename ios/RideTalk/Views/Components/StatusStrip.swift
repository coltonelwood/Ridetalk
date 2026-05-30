import SwiftUI

/// Glanceable status strip: connection, audio route (AirPods), speed, battery, rider count.
struct StatusStrip: View {
    @ObservedObject var vm: RideRoomViewModel

    var body: some View {
        HStack(spacing: 10) {
            pill(icon: connectionIcon, text: connectionText, tint: connectionTint)
            pill(icon: vm.usingBluetooth ? "airpodspro" : "iphone",
                 text: vm.routeName, tint: vm.usingBluetooth ? .rideAccent : .secondary)
            pill(icon: "speedometer", text: "\(vm.speedMph) mph", tint: .primary)
            pill(icon: batteryIcon, text: "\(Int(vm.batteryLevel * 100))%", tint: batteryTint)
        }
        .font(.caption.bold())
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private func pill(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.rideSurface, in: Capsule())
    }

    private var connectionIcon: String {
        switch vm.connectionStatus {
        case .connected: return "wifi"
        case .connecting, .reconnecting: return "wifi.exclamationmark"
        case .disconnected: return "wifi.slash"
        }
    }
    private var connectionText: String {
        switch vm.connectionStatus {
        case .connected: return "Live"
        case .connecting: return "Connecting"
        case .reconnecting: return "Reconnecting"
        case .disconnected: return "Offline"
        }
    }
    private var connectionTint: Color {
        switch vm.connectionStatus {
        case .connected: return .rideAccent
        case .connecting, .reconnecting: return .yellow
        case .disconnected: return .rideDanger
        }
    }

    private var batteryIcon: String {
        let lvl = vm.batteryLevel
        switch lvl {
        case ..<0.1: return "battery.0percent"
        case ..<0.4: return "battery.25percent"
        case ..<0.7: return "battery.50percent"
        case ..<0.95: return "battery.75percent"
        default: return "battery.100percent"
        }
    }
    private var batteryTint: Color {
        vm.batteryLevel < 0.2 ? .rideDanger : .primary
    }
}
