//
//  VoipPushRegistry.swift
//  VoiceQuickstart
//
//  Created by Alex Bumbu on 12.11.2025.
//

import Combine
import PushKit

extension VoipPushRegistry {
    enum PushEvents {
        case credentialsUpdated(token: Data)
        case credentialsInvalidated
        case incoming(payload: [AnyHashable: Any])
    }
}

class VoipPushRegistry: NSObject, PKPushRegistryDelegate {
    var eventsPublisher: AnyPublisher<PushEvents, Never> {
        events.eraseToAnyPublisher()
    }
    private let events = PassthroughSubject<PushEvents, Never>()
    private let voipRegistry = PKPushRegistry.init(queue: DispatchQueue.main)
    
    override init() {
        super.init()
        
        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = Set([PKPushType.voIP])
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
        print("pushRegistry:didUpdatePushCredentials:forType:")
        
        events.send(.credentialsUpdated(token: credentials.token))
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        print("pushRegistry:didInvalidatePushTokenForType:")
        
        events.send(.credentialsInvalidated)
    }

    /**
     * This delegate method is available on iOS 11 and above. Call the completion handler once the
     * notification payload is passed to the `TwilioVoiceSDK.handleNotification()` method.
     */
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        print("pushRegistry:didReceiveIncomingPushWithPayload:forType:completion:")
        
        /**
         * The Voice SDK processes the call notification and returns the call invite synchronously. Report the incoming call to
         * CallKit and fulfill the completion before exiting this callback method.
         */
        events.send(.incoming(payload: payload.dictionaryPayload))
        completion()
    }
}

