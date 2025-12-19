//
//  VoiceQuickstartApp.swift
//  VoiceQuickstart
//
//  Created by Alex Bumbu on 11.11.2025.
//

import SwiftUI

@main
struct VoiceQuickstartApp: App {
    private let accessToken: String = <#PASTE YOUR ACCESS TOKEN HERE#>
    
    var body: some Scene {
        WindowGroup {
            let voipService = VoipService(accessToken: accessToken, voipRegistry: VoipPushRegistry())
            CallView(voipService: voipService)
        }
    }
}
