//
//  CallKitManager.swift
//  VoiceQuickstart
//
//  Created by Alex Bumbu on 27.11.2025.
//


import Combine
import CallKit
import AVFoundation

extension CallKitController {
    enum CallKitEvents {
        case onProviderDidBegin
        case onProviderDidReset
        case onStartCall(uuid: UUID)
        case onAnswerCall(uuid: UUID)
        case onEndCall(uuid: UUID)
        case audioSessionActivated
        case audioSessionDeactivated
    }
}

class CallKitController: NSObject {
    var eventsPublisher: AnyPublisher<CallKitEvents, Never> {
        events.eraseToAnyPublisher()
    }
    private var events = PassthroughSubject<CallKitEvents, Never>()
    
    var onHoldChangeRequested: ((_ callUUID: UUID, _ isOnHold: Bool) -> Bool)?
    var onMuteChangeRequested: ((_ callUUID: UUID, _ isMuted: Bool) -> Bool)?
    var onDTMFPlayRequested: ((_ callUUID: UUID, _ digits: String) -> Bool)?
    
    private var callKitProvider: CXProvider
    private var callKitCallController = CXCallController()
    
    override init() {
        let configuration = CXProviderConfiguration()
        configuration.maximumCallGroups = 2
        configuration.maximumCallsPerCallGroup = 1
        
        callKitProvider = CXProvider(configuration: configuration)
        super.init()
        
        setupCallKitProvider()
    }
    
    func requestStartCall(uuid: UUID, handle: String) {
        let callHandle = CXHandle(type: .generic, value: handle)
        let startCallAction = CXStartCallAction(call: uuid, handle: callHandle)
        let transaction = CXTransaction(action: startCallAction)

        callKitCallController.request(transaction) { [weak self] error in
            if let error = error {
                print("StartCallAction transaction request failed: \(error.localizedDescription)")
                return
            }

            print("StartCallAction transaction request successful")

            let callUpdate = CXCallUpdate()
            
            callUpdate.remoteHandle = callHandle
            callUpdate.supportsDTMF = true
            callUpdate.supportsHolding = true
            callUpdate.supportsGrouping = false
            callUpdate.supportsUngrouping = false
            callUpdate.hasVideo = false

            self?.callKitProvider.reportCall(with: uuid, updated: callUpdate)
        }
    }
    
    func requestEndCallAction(uuid: UUID) {
        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endCallAction)

        callKitCallController.request(transaction) { error in
            if let error = error {
                print("EndCallAction transaction request failed: \(error.localizedDescription).")
            } else {
                print("EndCallAction transaction request successful")
            }
        }
    }
    
    func reportIncomingCall(from: String, uuid: UUID) {
        let callHandle = CXHandle(type: .generic, value: from)
        let callUpdate = CXCallUpdate()
        
        callUpdate.remoteHandle = callHandle
        callUpdate.supportsDTMF = true
        callUpdate.supportsHolding = true
        callUpdate.supportsGrouping = false
        callUpdate.supportsUngrouping = false
        callUpdate.hasVideo = false

        callKitProvider.reportNewIncomingCall(with: uuid, update: callUpdate) { error in
            if let error = error {
                print("Failed to report incoming call successfully: \(error.localizedDescription).")
            } else {
                print("Incoming call successfully reported.")
            }
        }
    }
    
    func reportOutgoingCallConnected(uuid: UUID) {
        callKitProvider.reportOutgoingCall(with: uuid, connectedAt: Date())
    }
    
    func reportCallEnded(uuid: UUID, reason: CXCallEndedReason) {
        callKitProvider.reportCall(with: uuid, endedAt: Date(), reason: reason)
    }
}

private extension CallKitController {
    
    func setupCallKitProvider() {
        callKitProvider.setDelegate(self, queue: nil)
    }
}


// MARK: -

extension CallKitController: CXProviderDelegate {
    
    func providerDidBegin(_ provider: CXProvider) {
        print("providerDidBegin")
        events.send(.onProviderDidBegin)
    }
    
    func providerDidReset(_ provider: CXProvider) {
        print("providerDidReset:")
        events.send(.onProviderDidReset)
    }

    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        print("provider:performStartCallAction:")
        
        provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: Date())
        events.send(.onStartCall(uuid: action.callUUID))
        
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        print("provider:performAnswerCallAction:")
        
        events.send(.onAnswerCall(uuid: action.callUUID))
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("provider:performEndCallAction:")
        
        events.send(.onEndCall(uuid: action.callUUID))
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        print("provider:performSetHeldAction:")
        
        if onHoldChangeRequested?(action.callUUID, action.isOnHold) ?? false {
            action.fulfill()
        } else {
            action.fail()
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        print("provider:performSetMutedAction:")

        if onMuteChangeRequested?(action.callUUID, action.isMuted) ?? false {
            action.fulfill()
        } else {
            action.fail()
        }
    }

    func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) {
        print("provider:performPlayDTMFCallAction:")

        if onDTMFPlayRequested?(action.callUUID, action.digits) ?? false {
            action.fulfill()
        } else {
            action.fail()
        }
    }
    
    func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        print("provider:timedOutPerformingAction:")
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        print("provider:didActivateAudioSession:")
        events.send(.audioSessionActivated)
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        print("provider:didDeactivateAudioSession:")
        events.send(.audioSessionDeactivated)
    }
}
