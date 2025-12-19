//
//  CallEvent.swift
//  VoiceQuickstart
//
//  Created by Alex Bumbu on 09.12.2025.
//

import Foundation

enum CallEvent {
    case willStart
    case didStartRinging
    case didConnect
    case isReconnecting
    case didReconnect
    case didDisconnect
    case holdStateChanged
    case qualityWarnings(warnings: Set<NSNumber>, isCleared: Bool)
}
