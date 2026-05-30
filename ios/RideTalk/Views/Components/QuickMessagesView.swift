import SwiftUI

/// One-tap canned text alerts ("Stopping", "Need gas", "Slow down", "I'm behind",
/// "All good"), plus the recent feed. Big targets for gloved hands.
struct QuickMessagesView: View {
    @ObservedObject var vm: ActiveRideViewModel
    @Environment(\.dismiss) private var dismiss

    private let kinds: [QuickMessageKind] = [.stopping, .gas, .slowDown, .behind, .allGood]
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.rideBackground.ignoresSafeArea()
                VStack(spacing: 16) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(kinds) { kind in
                            Button {
                                Task { await vm.sendQuick(kind); dismiss() }
                            } label: {
                                VStack(spacing: 10) {
                                    Image(systemName: kind.icon).font(.system(size: 30, weight: .bold))
                                    Text(kind.label).font(.headline)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 22)
                                .background(kind.isPriority ? Color.rideDanger.opacity(0.85) : Color.rideSurface,
                                            in: RoundedRectangle(cornerRadius: 18))
                                .foregroundStyle(kind.isPriority ? .white : .primary)
                            }
                        }
                    }
                    .padding(.horizontal)

                    if !vm.quickMessages.isEmpty { recentFeed }
                    Spacer()
                }
                .padding(.top)
            }
            .navigationTitle("Quick Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }

    private var recentFeed: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent").font(.headline).padding(.horizontal)
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(vm.quickMessages.prefix(12)) { msg in
                        HStack(spacing: 8) {
                            Image(systemName: (QuickMessageKind(rawValue: msg.kind.rawValue) ?? .custom).icon)
                                .foregroundStyle(msg.isPriority ? .rideDanger : .rideAccent)
                            Text("\(vm.name(forUserId: msg.userId)): \(msg.text)").font(.subheadline)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
}
