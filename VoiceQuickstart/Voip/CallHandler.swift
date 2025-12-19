//
//  CallHandler.swift
//  VoiceQuickstart
//
//  Created by Alex Bumbu on 12.11.2025.
//

import Combine
import CallKit
import TwilioVoice

private extension CallHandler {
    struct RingbackManager {
        private var playCustomRingback: Bool
        private var player = RingtonePlayer()
        
        init(playCustomRingback: Bool) {
            self.playCustomRingback = playCustomRingback
        }
        
        @MainActor
        func playRingback() {
            guard playCustomRingback else {
                return
            }
            
            player.play()
        }
        
        @MainActor
        func stopRingback() {
            guard playCustomRingback else {
                return
            }
            
            player.stop()
        }
    }
}

final class CallHandler: NSObject, CallDelegate {
    private unowned let state: VoipState
    private var ringback: RingbackManager
    private var callKitCompletionCallback: ((Bool) -> Void)?

    init(state: VoipState, playCustomRingback: Bool, callKitCompletionCallback: ((Bool) -> Void)?) {
        self.state = state
        self.ringback = RingbackManager(playCustomRingback: playCustomRingback)
        self.callKitCompletionCallback = callKitCompletionCallback
        super.init()
    }

    func updateCallKitCompletion(_ callback: ((Bool) -> Void)?) {
        self.callKitCompletionCallback = callback
    }

    func callDidConnect(call: Call) {
        print("callDidConnect:")

        ringback.stopRingback()

        if let callKitCompletionCallback {
            callKitCompletionCallback(true)
        }

        // TODO: maybe move the following piece to VoipState().toggleAudioRoute(toSpeaker:)
        // Route to speaker by default
        state.audioDevice.block = {
            AudioSessionManager.toggleAudioRoute(toSpeaker: true)
        }
        state.audioDevice.block()
        state.sendEvent(.didConnect)
    }

    func callDidFailToConnect(call: Call, error: any Error) {
        print("Call failed to connect: \(error.localizedDescription)")

        if let completion = callKitCompletionCallback {
            completion(false)
        }

        if let uuid = call.uuid {
            state.callKitController.reportCallEnded(uuid: uuid, reason: .failed)
        }

        callDisconnected(call: call)
        state.sendEvent(.didDisconnect)
    }

    func callDidDisconnect(call: Call, error: (any Error)?) {
        if let error {
            print("Call failed: \(error.localizedDescription)")
        } else {
            print("Call disconnected")
        }

        if !state.userInitiatedDisconnect, let uuid = call.uuid {
            let reason: CXCallEndedReason = error != nil ? .failed : .remoteEnded
            state.callKitController.reportCallEnded(uuid: uuid, reason: reason)
        }

        callDisconnected(call: call)
        state.sendEvent(.didDisconnect)
    }

    func callDidStartRinging(call: Call) {
        print("callDidStartRinging:")

        state.sendEvent(.didStartRinging)

        /*
        When [answerOnBridge](https://www.twilio.com/docs/voice/twiml/dial#answeronbridge) is enabled in the
        <Dial> TwiML verb, the caller will not hear the ringback while the call is ringing and awaiting to be
        accepted on the callee's side. The application can use the `AVAudioPlayer` to play custom audio files
        between the `[TVOCallDelegate callDidStartRinging:]` and the `[TVOCallDelegate callDidConnect:]` callbacks.
       */
        ringback.playRingback()
    }

    func callIsReconnecting(call: Call, error: Error) {
        print("call:isReconnectingWithError:")

        state.sendEvent(.isReconnecting)
    }

    func callDidReconnect(call: Call) {
        print("callDidReconnect:")

        state.sendEvent(.didReconnect)
    }

    func callDidReceiveQualityWarnings(call: Call, currentWarnings: Set<NSNumber>, previousWarnings: Set<NSNumber>) {
        /**
        * currentWarnings: existing quality warnings that have not been cleared yet
        * previousWarnings: last set of warnings prior to receiving this callback
        *
        * Example:
        *   - currentWarnings: { A, B }
        *   - previousWarnings: { B, C }
        *   - intersection: { B }
        *
        * Newly raised warnings = currentWarnings - intersection = { A }
        * Newly cleared warnings = previousWarnings - intersection = { C }
        */
        var warningsIntersection: Set<NSNumber> = currentWarnings
        warningsIntersection = warningsIntersection.intersection(previousWarnings)

        var newWarnings: Set<NSNumber> = currentWarnings
        newWarnings.subtract(warningsIntersection)
        if newWarnings.count > 0 {
            state.sendEvent(.qualityWarnings(warnings: newWarnings, isCleared: false))
        }

        var clearedWarnings: Set<NSNumber> = previousWarnings
        clearedWarnings.subtract(warningsIntersection)
        if clearedWarnings.count > 0 {
            state.sendEvent(.qualityWarnings(warnings: clearedWarnings, isCleared: true))
        }
    }

    private func callDisconnected(call: Call) {
        state.removeCall(call)
        state.userInitiatedDisconnect = false
        ringback.stopRingback()
    }
}
