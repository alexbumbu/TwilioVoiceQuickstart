//
//  CallInviteHandler.swift
//  VoiceQuickstart
//
//  Created by Alex Bumbu on 12.11.2025.
//

import SwiftUI
import CallKit
import TwilioVoice

final class CallInviteHandler: NSObject, NotificationDelegate {
    private unowned let state: VoipState
    
    @AppStorage("cachedBindingDate") private var cachedBindingDate: Date?

    init(state: VoipState) {
        self.state = state
        super.init()
    }

    func callInviteReceived(callInvite: CallInvite) {
        print("callInviteReceived")

        /**
         * The TTL of a registration is 1 year. The TTL for registration for this device/identity
         * pair is reset to 1 year whenever a new registration occurs or a push notification is
         * sent to this device/identity pair.
         */
        cachedBindingDate = Date()
        
        let callerInfo: TVOCallerInfo = callInvite.callerInfo
        if let verified: NSNumber = callerInfo.verified, verified.boolValue {
            print("Call invite received from verified caller number!")
        }

        let from = (callInvite.from ?? "Voice Bot").replacingOccurrences(of: "client:", with: "")

        print("reportIncomingCall from: \(from)")

        // Always report to CallKit
        state.callKitController.reportIncomingCall(from: from, uuid: callInvite.uuid)
        state.addActiveCallInvite(callInvite)
    }
    
    func cancelledCallInviteReceived(cancelledCallInvite: CancelledCallInvite, error: any Error) {
        print("cancelledCallInviteCanceled:error:, error: \(error.localizedDescription)")

        if let callInvite = state.activeCallInvite(callSid: cancelledCallInvite.callSid) {
            state.userInitiatedDisconnect = true
            state.callKitController.requestEndCallAction(uuid: callInvite.uuid)
            state.removeCallInvite(callInvite)
        }
    }
}
