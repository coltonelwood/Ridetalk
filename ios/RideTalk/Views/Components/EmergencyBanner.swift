import SwiftUI

/// Red alert banner shown to everyone in the room when a rider taps "I need help".
struct EmergencyBanner: View {
    let event: EmergencyEvent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(event.displayName) needs help")
                    .font(.headline)
                if event.lat != nil {
                    Text("Location shared • tap Map to see")
                        .font(.caption)
                        .opacity(0.9)
                }
            }
            Spacer()
            if let lat = event.lat, let lng = event.lng,
               let url = URL(string: "http://maps.apple.com/?ll=\(lat),\(lng)") {
                Link(destination: url) {
                    Image(systemName: "location.fill.viewfinder").font(.title2)
                }
            }
        }
        .foregroundStyle(.white)
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.rideDanger, in: RoundedRectangle(cornerRadius: 16))
    }
}
