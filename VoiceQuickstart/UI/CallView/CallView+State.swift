//
//  CallView+State.swift
//  VoiceQuickstart
//
//  Created by Alex Bumbu on 18.12.2025.
//

import Combine
import TwilioVoice

extension Call.QualityWarning {
    var title: String {
        switch self {
        case .highRtt: "high-rtt"
        case .highJitter: "high-jitter"
        case .highPacketsLostFraction: "high-packets-lost-fraction"
        case .lowMos: "low-mos"
        case .constantAudioInputLevel: "constant-audio-input-level"
        default: "Unknown warning"
        }
    }
}

extension CallView {
    enum CallAction {
        case call, preparing, ringing, reconnecting, hangup
        
        var title: String {
            switch self {
            case .call:
                "Call"
            case .preparing:
                "Calling..."
            case .ringing:
                "Ringing"
            case .reconnecting:
                "Reconnecting"
            case .hangup:
                "Hangup"
            }
        }
        
        var isEnabled: Bool {
            switch self {
            case .call, .ringing, .hangup:
                true
            case .preparing, .reconnecting:
                false
            }
        }
    }
}

extension CallView {
    final class ViewState: ObservableObject {
        @Published var dialText = ""
        
        @Published private(set) var showWarnings = false
        @Published private(set) var warningsMessage = "Warnings Raised"
        
        @Published var isSpeakerEnabled = true
        @Published var isMuted = false
        @Published private(set) var showCallControl = false
        @Published var showMicrophoneAccessRequest = false
        
        @Published var isSpinning = false
        
        @Published private(set) var activeAction: CallAction = .call
        
        private let voipService: VoipService
        var currentCall: Call? {
            voipService.currentCall()
        }

        private var cancellables = Set<AnyCancellable>()
        
        init(voipService: VoipService) {
            self.voipService = voipService
            bindVoipService()
        }
    }
}

@MainActor
extension CallView.ViewState {
    
    func startSpinner() {
        isSpinning = true
    }
    
    func stopSpinner() {
        isSpinning = false
    }
    
    func requestMicrophoneAccess() {
        showMicrophoneAccessRequest = true
    }
}

extension CallView.ViewState {
    
    func startCall(recordPermissionCheck: Bool) {        
        if recordPermissionCheck {
            AudioSessionManager.checkRecordPermission { [weak self] permissionGranted in
                guard permissionGranted else {
                    self?.requestMicrophoneAccess()
                    return
                }
                
                self?.startCall(handle: "Voice Bot")
            }
        } else {
            startCall(handle: "Voice Bot")
        }
    }
    
    private func startCall(handle: String) {
        voipService.startCall(to: dialText, handle: handle)
    }
    
    func endCall(uuid callId: UUID) {
        voipService.endCall(uuid: callId)
    }
    
    func endCurrentCall() {
        guard let currentCall, let callId = currentCall.uuid else {
            return
        }
            
        endCall(uuid: callId)
    }
    
    func cancelCall() {
        activeAction = .call
        toggleUIState(showCallControl: false)
    }
    
    func muteCurrentCall(_ mute: Bool) {
        voipService.muteCurrentCall(mute)
    }
    
    func toggleAudioRoute(toSpeaker: Bool) {
        voipService.toggleAudioRoute(toSpeaker: toSpeaker)
    }
}

private extension CallView.ViewState {
    
    func bindVoipService() {
        voipService.callEventsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                switch event {
                case .willStart:
                    self?.activeAction = .preparing
                    self?.toggleUIState(showCallControl: false)
                    self?.startSpinner()
                case .didStartRinging:
                    self?.activeAction = .ringing
                case .didConnect:
                    self?.activeAction = .hangup
                    self?.stopSpinner()
                    self?.toggleUIState(showCallControl: true)
                case .isReconnecting:
                    self?.activeAction = .reconnecting
                    self?.toggleUIState(showCallControl: false)
                case .didReconnect:
                    self?.activeAction = .hangup
                    self?.toggleUIState(showCallControl: true)
                case .didDisconnect:
                    self?.stopSpinner()
                    if self?.currentCall != nil {
                        self?.toggleUIState(showCallControl: true)
                    } else {
                        self?.activeAction = .call
                        self?.toggleUIState(showCallControl: false)
                    }
                case let .qualityWarnings(warnings, isCleared):
                    self?.handleQualityWarnings(warnings, isCleared: isCleared)
                case .holdStateChanged:
                    self?.activeAction = .hangup // this might me unnecessary
                    self?.toggleUIState(showCallControl: true)
                }
            }
            .store(in: &cancellables)
        
        $isMuted
            .dropFirst()
            .sink { [weak voipService] newValue in
                voipService?.muteCurrentCall(newValue)
            }
            .store(in: &cancellables)

        $isSpeakerEnabled
            .dropFirst()
            .sink { [weak voipService] toSpeaker in
                voipService?.toggleAudioRoute(toSpeaker: toSpeaker)
            }
            .store(in: &cancellables)
    }
    
    func toggleUIState(showCallControl: Bool) {
        self.showCallControl = showCallControl
        
        if showCallControl {
            isMuted = currentCall?.isMuted ?? false
            
            for output in AVAudioSession.sharedInstance().currentRoute.outputs {
                isSpeakerEnabled = output.portType == AVAudioSession.Port.builtInSpeaker
            }
        }
    }
    
    func handleQualityWarnings(_ warnings: Set<NSNumber>, isCleared: Bool) {
        var popupMessage: String = "Warnings detected:\n"
        if isCleared {
            popupMessage = "Warnings cleared: "
        }
        
        let mappedWarnings: [String] = warnings.compactMap { Call.QualityWarning(rawValue: $0.uintValue)?.title }
        popupMessage += mappedWarnings.joined(separator: ", ")
        
        warningsMessage = popupMessage
        showWarnings = true
        
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            self.showWarnings = false
        }
    }
}
