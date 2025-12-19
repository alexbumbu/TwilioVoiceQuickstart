//
//  CallProvider.swift
//  VoiceQuickstart
//
//  Created by Alex Bumbu on 12.11.2025.
//

import Foundation
import TwilioVoice

protocol CallProvider {
    var audioDevice: AudioDevice { get set }
    
    func setupAudioDevice()
    func connect(accessToken: String, uuid: UUID, params: [String: String], delegate: CallDelegate) -> Call
    func register(accessToken: String, deviceToken: Data, completion: @escaping (Error?) -> Void)
    func unregister(accessToken: String, deviceToken: Data, completion: @escaping (Error?) -> Void)
    func accept(invite: CallInvite, delegate: CallDelegate) -> Call
    func handleNotification(_ payload: [AnyHashable: Any], delegate: NotificationDelegate)
    
    func logDebug(_ message: String)
}

final class TwilioCallProvider: CallProvider {
    var audioDevice: AudioDevice

    init(audioDevice: AudioDevice) {
        self.audioDevice = audioDevice
    }

    func setupAudioDevice() {
        TwilioVoiceSDK.audioDevice = audioDevice
    }

    func connect(accessToken: String, uuid: UUID, params: [String: String], delegate: CallDelegate) -> Call {
        let options = ConnectOptions(accessToken: accessToken) { builder in
            builder.params = params
            builder.uuid = uuid
        }
        
        return TwilioVoiceSDK.connect(options: options, delegate: delegate)
    }

    func register(accessToken: String, deviceToken: Data, completion: @escaping (Error?) -> Void) {
        TwilioVoiceSDK.register(accessToken: accessToken, deviceToken: deviceToken, completion: completion)
    }

    func unregister(accessToken: String, deviceToken: Data, completion: @escaping (Error?) -> Void) {
        TwilioVoiceSDK.unregister(accessToken: accessToken, deviceToken: deviceToken, completion: completion)
    }
    
    func accept(invite: CallInvite, delegate: CallDelegate) -> Call {
        let options = AcceptOptions(callInvite: invite) { builder in
            builder.uuid = invite.uuid
        }
        
        return invite.accept(options: options, delegate: delegate)
    }

    func handleNotification(_ payload: [AnyHashable : Any], delegate: NotificationDelegate) {
        TwilioVoiceSDK.handleNotification(payload, delegate: delegate, delegateQueue: nil)
    }
    
    func logDebug(_ message: String) {
        guard let parameters = LogParameters(module: .platform, logLevel: .debug, message: message) else {
            return
        }
        
        TwilioVoiceSDK.logger.log(params: parameters)
    }
}
