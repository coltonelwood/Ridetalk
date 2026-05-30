import SwiftUI

/// Red SOS banner with a "navigate to rider" link and resolve action.
struct SOSBanner: View {
    let name: String
    let alert: SOSAlert
    let canResolve: Bool
    let onResolve: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sos").font(.title3.bold())
            VStack(alignment: .leading, spacing: 2) {
                Text("\(name) needs help").font(.headline)
                if alert.coordinate != nil { Text("Location shared").font(.caption).opacity(0.9) }
            }
            Spacer()
            if let c = alert.coordinate,
               let url = URL(string: "http://maps.apple.com/?daddr=\(c.latitude),\(c.longitude)&dirflg=d") {
                Link(destination: url) { Image(systemName: "location.fill.viewfinder").font(.title3) }
            }
            if canResolve {
                Button(action: onResolve) { Image(systemName: "checkmark.circle.fill").font(.title3) }
            }
        }
        .foregroundStyle(.white).padding()
        .frame(maxWidth: .infinity)
        .background(Color.rideDanger, in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Group-separation banner: "Jake is 1.2 miles behind".
struct SeparationBanner: View {
    let separations: [ActiveRideViewModel.Separation]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "person.line.dotted.person.fill").font(.title3)
                Text(message).font(.subheadline.bold()).lineLimit(2)
                Spacer()
                Image(systemName: "map.fill")
            }
            .foregroundStyle(.black).padding()
            .frame(maxWidth: .infinity)
            .background(Color.yellow, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var message: String {
        if let first = separations.first, separations.count == 1 {
            return "\(first.name) is \(String(format: "%.1f", first.miles)) mi behind the group"
        }
        let names = separations.prefix(2).map(\.name).joined(separator: ", ")
        return "\(names)\(separations.count > 2 ? " +\(separations.count - 2)" : "") fell behind"
    }
}

/// Generic safety banner (low battery, stopped, reconnecting…).
struct SafetyBanner: View {
    let text: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
            Text(text).font(.subheadline.bold()).lineLimit(2)
            Spacer()
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.rideSurface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(tint.opacity(0.4)))
    }
}
