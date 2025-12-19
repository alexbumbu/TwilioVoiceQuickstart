//
//  VoipState.swift
//  VoipState
//
//  Created by Alex Bumbu on 12.11.2025.
//

import Combine
import TwilioVoice

final class VoipState {
    // Dependencies
    let audioDevice: DefaultAudioDevice
    let callKitController: CallKitController
    
    var eventsPublisher: AnyPublisher<CallEvent, Never> {
        events.eraseToAnyPublisher()
    }
    private var events = PassthroughSubject<CallEvent, Never>()
    
    // Core state
    private var activeCalls: [String: Call] = [:]
    private var activeCallInvites: [String: CallInvite] = [:]
    // currentActiveCall represents the last connected call
    private var currentActiveCall: Call?
    var userInitiatedDisconnect: Bool = false
    
    init(audioDevice: DefaultAudioDevice, callKitController: CallKitController) {
        self.audioDevice = audioDevice
        self.callKitController = callKitController
    }
}

extension VoipState {
    
    func sendEvent(_ event: CallEvent) {
        events.send(event)
    }
    
    func setCurrentCall(_ call: Call) {
        self.currentActiveCall = call
    }
    
    func currentCall() -> Call? {
        if let activeCall = currentActiveCall {
            return activeCall
        } else if activeCalls.count == 1 {
            // This is a scenario when the only remaining call is still on hold after the previous call has ended
            return activeCalls.first?.value
        } else {
            return nil
        }
    }
    
    func muteCurrentCall(_ mute: Bool) {
        guard let currentCall = currentCall() else {
            return
        }
        
        currentCall.isMuted = mute
    }
    
    func activeCall(uuid: UUID) -> Call? {
        activeCalls[uuid.uuidString]
    }
    
    func addActiveCall(_ call: Call) {
        currentActiveCall = call
        
        if let uuid = call.uuid?.uuidString {
            activeCalls[uuid] = call
        }
    }
    
    func removeCall(_ call: Call) {
        if call == currentActiveCall {
            currentActiveCall = nil
        }
        
        if let uuid = call.uuid?.uuidString {
            activeCalls.removeValue(forKey: uuid)
        }
    }
    
    func activeCallInvite(uuid: UUID) -> CallInvite? {
        activeCallInvites[uuid.uuidString]
    }
    
    func activeCallInvite(callSid: String) -> CallInvite? {
        guard !activeCallInvites.isEmpty else {
            print("No pending call invite")
            return nil
        }
        
        return activeCallInvites.values.first { $0.callSid == callSid }
    }
    
    func addActiveCallInvite(_ callInvite: CallInvite) {
        activeCallInvites[callInvite.uuid.uuidString] = callInvite
    }
    
    func removeCallInvite(_ callInvite: CallInvite) {
        activeCallInvites.removeValue(forKey: callInvite.uuid.uuidString)
    }
}

extension VoipState {
    
    func enableAudioDevice() {
        audioDevice.isEnabled = true
    }
    
    func disableAudioDevice() {
        audioDevice.isEnabled = false
    }
    
    func toggleAudioRoute(toSpeaker: Bool) {
        // The mode set by the Voice SDK is "VoiceChat" so the default audio route is the built-in receiver. Use port override to switch the route.
        audioDevice.block = {
            Task { @MainActor in
                AudioSessionManager.toggleAudioRoute(toSpeaker: toSpeaker)
            }
        }
        
        audioDevice.block()
    }
}
