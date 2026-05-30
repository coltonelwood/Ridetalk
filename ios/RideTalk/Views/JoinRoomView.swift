import SwiftUI

/// Join Ride Room screen: enter a 6-char code (invite links route here automatically).
struct JoinRoomView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var isBusy = false
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Color.rideBackground.ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "person.2.wave.2.fill")
                    .font(.system(size: 56)).foregroundStyle(.rideTalk).padding(.top, 24)

                Text("Enter the ride code your host shared.")
                    .foregroundStyle(.secondary)

                TextField("ABC123", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.center)
                    .font(.system(size: 40, weight: .heavy, design: .monospaced))
                    .focused($focused)
                    .padding()
                    .background(Color.rideSurface, in: RoundedRectangle(cornerRadius: 16))
                    .onChange(of: code) { newValue in
                        let cleaned = String(newValue.uppercased().prefix(6))
                        if cleaned != code { code = cleaned }
                    }

                Button { join() } label: {
                    Text("Join ride").font(.title3.bold())
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .background(Color.rideTalk, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.black)
                .disabled(code.count < 4)

                Spacer()
            }
            .padding()
            if isBusy { Color.black.opacity(0.4).ignoresSafeArea(); ProgressView().tint(.white).scaleEffect(1.5) }
        }
        .navigationTitle("Join Ride")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { focused = true }
    }

    private func join() {
        isBusy = true
        Task {
            await appState.joinRoom(code: code)
            isBusy = false
            if appState.activeRoom != nil { dismiss() }
        }
    }
}
