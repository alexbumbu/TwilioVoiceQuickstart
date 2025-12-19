//
//  VoipService.swift
//  VoiceQuickstart
//
//  Created by Alex Bumbu on 12.11.2025.
//

import SwiftUI
import Combine
import TwilioVoice

private extension VoipService {
    enum Constant {
        static let twimlParamTo = "to"
        static let kRegistrationTTLInDays = 365
    }
}

class VoipService: NSObject {
    var accessToken: String
    var voipRegistry: VoipPushRegistry
    
    var callEventsPublisher: AnyPublisher<CallEvent, Never> {
        callEvents.eraseToAnyPublisher()
    }
    private let callEvents = PassthroughSubject<CallEvent, Never>()

    private var outgoingValue: String = ""
    
    private let state: VoipState
    
    private let callProvider: CallProvider
    private let callHandler: CallHandler
    private let callInviteHandler: CallInviteHandler
    
    private var callKitController = CallKitController()
    private var callKitCompletionCallback: ((Bool) -> Void)? = nil
    
    @AppStorage("cachedDeviceToken") private var cachedDeviceToken: Data?
    @AppStorage("cachedBindingDate") private var cachedBindingDate: Date?
    
    private var cancellables = Set<AnyCancellable>()
            
    init(accessToken: String, voipRegistry: VoipPushRegistry, callProvider: CallProvider? = nil) {
        let audioDevice = DefaultAudioDevice()
        
        self.accessToken = accessToken
        self.voipRegistry = voipRegistry
        self.state = VoipState(audioDevice: audioDevice, callKitController: callKitController)
        self.callProvider = callProvider ?? TwilioCallProvider(audioDevice: audioDevice)
        callInviteHandler = CallInviteHandler(state: state)
        callHandler = CallHandler(
            state: state,
            playCustomRingback: true,
            callKitCompletionCallback: callKitCompletionCallback
        )
        super.init()

        setupVoipState()
        setupVoipRegistry()
        setupCallKit()
        setupTwilio()
    }
}

extension VoipService {
    
    func startCall(to: String, uuid: UUID = UUID(), handle: String) {
        outgoingValue = to
        callKitController.requestStartCall(uuid: uuid, handle: handle)
    }
    
    func endCall(uuid: UUID) {
        state.userInitiatedDisconnect = true
        callKitController.requestEndCallAction(uuid: uuid)
    }
    
    func currentCall() -> Call? {
        state.currentCall()
    }
    
    func muteCurrentCall(_ mute: Bool) {
        state.muteCurrentCall(mute)
    }
    
    func toggleAudioRoute(toSpeaker: Bool) {
        state.toggleAudioRoute(toSpeaker: toSpeaker)
    }
}

private extension VoipService {
    
    func setupVoipState() {
        state.eventsPublisher
            .sink { [weak self] event in
                self?.callEvents.send(event)
            }
            .store(in: &cancellables)
    }
    
    func setupTwilio() {
        // Ensure the Voice SDK uses our audio device before any call actions.
        callProvider.setupAudioDevice()
        
        // Example usage of provider logger to print app logs
        callProvider.logDebug("The default logger is used for app logs")
    }
    
    func setupCallKit() {
        callKitController.eventsPublisher
            .sink { [weak self] event in
                switch event {
                case .onProviderDidBegin:
                    break
                case .onProviderDidReset:
                    self?.state.disableAudioDevice()
                case .audioSessionActivated:
                    self?.state.enableAudioDevice()
                case .audioSessionDeactivated:
                    self?.state.disableAudioDevice()
                case .onStartCall(uuid: let uuid):
                    self?.callEvents.send(.willStart)
                    self?.performVoiceCall(uuid: uuid, client: "") { success in
                        if success {
                            print("performVoiceCall() successful")
                            self?.callKitController.reportOutgoingCallConnected(uuid: uuid)
                        } else {
                            print("performVoiceCall() failed")
                        }
                    }
                case .onAnswerCall(uuid: let uuid):
                    self?.performAnswerVoiceCall(uuid: uuid) { success in
                        if success {
                            print("performAnswerVoiceCall() successful")
                        } else {
                            print("performAnswerVoiceCall() failed")
                        }
                    }
                case .onEndCall(uuid: let uuid):
                    if let invite = self?.state.activeCallInvite(uuid: uuid) {
                        invite.reject()
                        self?.state.removeCallInvite(invite)
                    } else if let call = self?.state.activeCall(uuid: uuid) {
                        call.disconnect()
                    } else {
                        print("Unknown UUID to perform end-call action with")
                    }
                }
            }
            .store(in: &cancellables)
        
        callKitController.onHoldChangeRequested = { [weak self] callUUID, isOnHold in
            guard let call = self?.state.activeCall(uuid: callUUID) else {
                return false
            }
            
            call.isOnHold = isOnHold
            
            /** Explicitly enable the TVOAudioDevice.
             * This is workaround for an iOS issue where the `provider(_:didActivate:)` method is not called
             * when un-holding a VoIP call after an ended PSTN call.
             */ https://developer.apple.com/forums/thread/694836
            if !call.isOnHold {
                self?.state.enableAudioDevice()
                self?.state.setCurrentCall(call)
            }
            
            Task { @MainActor in
                self?.callEvents.send(.holdStateChanged)
            }
            
            return true
        }
        callKitController.onMuteChangeRequested = { [weak self] callUUID, isMuted in
            guard let call = self?.state.activeCall(uuid: callUUID)  else {
                return false
            }
            
            call.isMuted = isMuted
            return true
        }
        callKitController.onDTMFPlayRequested = { [weak self] callUUID, digits in
            guard let call = self?.state.activeCall(uuid: callUUID) else {
                return false
            }
            
            call.sendDigits(digits)
            return true
        }
    }
    
    func setupVoipRegistry() {
        voipRegistry.eventsPublisher
            .sink { [weak self] event in
                switch event {
                case .credentialsUpdated(token: let token):
                    self?.updateCredentials(token: token)
                case .credentialsInvalidated:
                    self?.invalidateCredentials()
                case .incoming(payload: let payload):
                    self?.handleIncomingPush(payload: payload)
                }
            }
            .store(in: &cancellables)
    }
    
    func performVoiceCall(uuid: UUID, client: String?, completion: @escaping (Bool) -> Void) {
        let connectOptionsParams = [Constant.twimlParamTo: self.outgoingValue]
        let call = callProvider.connect(accessToken: accessToken, uuid: uuid, params: connectOptionsParams, delegate: callHandler)
        state.addActiveCall(call)
        
        callKitCompletionCallback = completion
    }
    
    func performAnswerVoiceCall(uuid: UUID, completion: @escaping (Bool) -> Void) {
        guard let callInvite = state.activeCallInvite(uuid: uuid) else {
            print("No CallInvite matches the UUID")
            return
        }
        
        let call = callProvider.accept(invite: callInvite, delegate: callHandler)
        state.addActiveCall(call)
        
        callKitCompletionCallback = completion
        state.removeCallInvite(callInvite)
    }
    
    private func updateCredentials(token deviceToken: Data) {
        guard registrationRequired() || cachedDeviceToken != deviceToken else {
            return
        }
        
        callProvider.register(accessToken: accessToken, deviceToken: deviceToken) { [weak self] error in
            if let error {
                print("An error occurred while registering: \(error.localizedDescription)")
            } else {
                print("Successfully registered for VoIP push notifications.")
            }
            
            self?.cachedDeviceToken = deviceToken
            self?.cachedBindingDate = Date()
        }
    }
    
    private func invalidateCredentials() {
        guard let deviceToken = cachedDeviceToken else {
            return
        }
        
        callProvider.unregister(accessToken: accessToken, deviceToken: deviceToken) { [weak self] error in
            if let error {
                print("An error occurred while unregistering: \(error.localizedDescription)")
            } else {
                print("Successfully unregistered from VoIP push notifications.")
            }
            
            self?.cachedDeviceToken = nil
            self?.cachedBindingDate = nil
        }
    }
    
    private func handleIncomingPush(payload: [AnyHashable: Any]) {
        callProvider.handleNotification(payload, delegate: callInviteHandler)
    }
    
    /**
     * The TTL of a registration is 1 year. The TTL for registration for this device/identity pair is reset to
     * 1 year whenever a new registration occurs or a push notification is sent to this device/identity pair.
     * This method checks if binding exists in UserDefaults, and if half of TTL has been passed then the method
     * will return true, else false.
     */
    private func registrationRequired() -> Bool {
        guard let cachedBindingDate else {
            return true
        }
        
        let date = Date()
        var components = DateComponents()
        components.setValue(Constant.kRegistrationTTLInDays/2, for: .day)
        
        if let expirationDate = Calendar.current.date(byAdding: components, to: cachedBindingDate), expirationDate.compare(date) == .orderedDescending {
            return false
        }

        return true;
    }
}

