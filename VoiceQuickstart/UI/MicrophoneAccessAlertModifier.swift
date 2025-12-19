import SwiftUI
import UIKit

struct MicrophoneAccessAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    let continueWithoutMic: () -> Void
    let openSettings: () -> Void
    let cancel: () -> Void

    func body(content: Content) -> some View {
        content.alert("Voice Quick Start", isPresented: $isPresented) {
            Button("Continue without microphone") {
                continueWithoutMic()
            }
            Button("Settings") {
                openSettings()
            }
            Button("Cancel") {
                cancel()
            }
        } message: {
            Text("Microphone permission not granted")
        }
    }
}

extension View {
    func microphoneAccessAlert(isPresented: Binding<Bool>,
                               continueWithoutMic: @escaping () -> Void,
                               openSettings: @escaping () -> Void,
                               cancel: @escaping () -> Void) -> some View {
        modifier(MicrophoneAccessAlertModifier(isPresented: isPresented,
                                               continueWithoutMic: continueWithoutMic,
                                               openSettings: openSettings,
                                               cancel: cancel))
    }
}
