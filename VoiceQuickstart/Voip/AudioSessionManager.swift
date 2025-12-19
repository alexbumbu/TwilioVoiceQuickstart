//
//  AudioSessionManager.swift
//  VoiceQuickstart
//
//  Created by Alex Bumbu on 27.11.2025.
//

import AVFoundation

struct AudioSessionManager {
    
    static func toggleAudioRoute(toSpeaker: Bool) {
        do {
            if toSpeaker {
                try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
            } else {
                try AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
            }
        } catch {
            print(error.localizedDescription)
        }
    }
    
    static func checkRecordPermission(completion: @escaping (_ permissionGranted: Bool) -> Void) {
        let permissionStatus = AVAudioApplication.shared.recordPermission
        
        switch permissionStatus {
        case .granted:
            // Record permission already granted.
            completion(true)
        case .denied:
            // Record permission denied.
            completion(false)
        case .undetermined:
            // Requesting record permission.
            // Optional: pop up app dialog to let the users know if they want to request.
            AVAudioApplication.requestRecordPermission { granted in
                completion(granted)
            }
        default:
            completion(false)
        }
    }
}
