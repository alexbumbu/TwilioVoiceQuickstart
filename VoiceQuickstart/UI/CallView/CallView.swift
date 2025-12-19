//
//  CallView.swift
//  VoiceQuickstart
//
//  Created by Alex Bumbu on 12.11.2025.
//

import SwiftUI
import AVFoundation
import Combine

private extension CallView {
    enum AnimationType {
        static let fade: Animation = .easeInOut
        static let quickFade: Animation = .easeOut(duration: 0.1)
    }
    
    struct CallControlView: View {
        @Binding var isMuted: Bool
        @Binding var isSpeakerEnabled: Bool
        
        var body: some View {
            HStack(alignment: .center, spacing: 32) {
                VStack() {
                    Toggle("Mute Toggle", isOn: $isMuted)
                        .labelsHidden()
                        .padding(.vertical, 8)
                    
                    Text("Mute")
                        .font(.caption)
                }
                
                VStack() {
                    Toggle("Speaker Toggle", isOn: $isSpeakerEnabled)
                        .labelsHidden()
                        .padding(.vertical, 8)
                    
                    Text("Speaker")
                        .font(.caption)
                }
            }
        }
    }
}

struct CallView: View {
    @Environment(\.openURL) private var openURL
    @StateObject private var state: ViewState
    
    init(voipService: VoipService) {
        self._state = StateObject(wrappedValue: ViewState(voipService: voipService))
    }
        
    var body: some View {
        GeometryReader { geometry in
            ZStack() {
                Group() {
                    Text(state.warningsMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .opacity(state.showWarnings ? 1 : 0)
                        .animation(AnimationType.fade, value: state.showWarnings)
                        .animation(AnimationType.quickFade, value: state.warningsMessage)
                        .padding(.top, 8)
                }
                .frame(height: geometry.size.height, alignment: .topLeading)
                
                VStack() {
                    SpinnerView(isSpinning: $state.isSpinning) {
                        Image("TwilioLogo")
                            .resizable()
                            .frame(width: 240, height: 240)
                    }
                                      
                    TextField("", text: $state.dialText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 240)
                        .padding(.top)
                    
                    Text("Dial a client name or phone number. Leaving the field empty results in an automated response.")
                        .multilineTextAlignment(.center)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 256)
                        .padding(.top, 4)
                        .padding(.horizontal, 48)
                    
                    Button(state.activeAction.title) {
                        startOrEndCall()
                    }
                    .foregroundStyle(.twilioRed)
                    .disabled(!state.activeAction.isEnabled)
                    .padding()
                    .animation(AnimationType.quickFade, value: state.activeAction)
                    
                    CallControlView(isMuted: $state.isMuted, isSpeakerEnabled: $state.isSpeakerEnabled)
                        .opacity(state.showCallControl ? 1 : 0)
                        .animation(AnimationType.fade, value: state.showCallControl)
                }
            }
            .frame(width: geometry.size.width)
        }
        .microphoneAccessAlert(isPresented: $state.showMicrophoneAccessRequest, continueWithoutMic: {
            state.startCall(recordPermissionCheck: false)
        }, openSettings: {
            openURL(URL(string: UIApplication.openSettingsURLString)!)
        }, cancel: {
            state.cancelCall()
        })
    }
}

private extension CallView {
    
    func startOrEndCall() {
        if state.currentCall != nil {
            state.endCurrentCall()
        } else {
            state.startCall(recordPermissionCheck: true)
        }
    }
}

// MARK: -

#Preview {
    let service = VoipService(accessToken: "", voipRegistry: VoipPushRegistry())
    return CallView(voipService: service)
}
