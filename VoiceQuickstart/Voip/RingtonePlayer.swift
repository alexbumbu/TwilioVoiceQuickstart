//
//  RingtonePlayer.swift
//  VoiceQuickstart
//
//  Created by Alex Bumbu on 12.11.2025.
//

import Foundation
import AVFoundation

@MainActor
class RingtonePlayer: NSObject {
    
    private var player: AVAudioPlayer?
    
    func play() {
        guard let resourcePath = Bundle.main.path(forResource: "ringtone", ofType: "wav") else {
            print("No ringtone found")
            return
        }
        
        let ringtonePath = URL(fileURLWithPath: resourcePath)
        
        do {
            player = try AVAudioPlayer(contentsOf: ringtonePath)
            player?.delegate = self
            player?.numberOfLoops = -1
            
            player?.volume = 1.0
            player?.play()
        } catch {
            print("Failed to initialize audio player")
        }
    }
    
    func stop() {
        guard let player, player.isPlaying else {
            return
        }
        
        player.stop()
    }
}

extension RingtonePlayer: AVAudioPlayerDelegate {
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            print("Audio player finished playing successfully");
        } else {
            print("Audio player finished playing with some error");
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error {
            print("Decode error occurred: \(error.localizedDescription)")
        }
    }
}
