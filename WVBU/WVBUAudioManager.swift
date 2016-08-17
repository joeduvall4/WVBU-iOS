//
//  WVBUAudioManager.swift
//  WVBU
//
//  Created by Joe Duvall on 4/16/16.
//  Copyright © 2016 Joe Duvall. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit
import MediaPlayer

protocol WVBUAudioManagerDelegate {
    func audioManagerDidStopPlaying()
    func audioManagerDidStartPlaying()
}

class WVBUAudioManager: NSObject {
    
    // MARK: - URLs
    
    enum AudioURLStrings: String {
        case MainStream = "http://stream.bucknell.edu:90/wvbu.m3u"
    }

    /// The shared instance of `WVBUAudioManager`.
    static let sharedManager = WVBUAudioManager()
    
    /// The delegate of this `WVBUAudioManager`.
    /// The delegate will receive start and stop playing callbacks, which are useful for UI updates.
    var delegate: WVBUAudioManagerDelegate?
    
    /// The `AVPlayer` managed by the `WVBUAudioManager`. 
    /// - Note: This will never be nil, but may be reinitialized at any time.
    /// - Note: This is a private variable; interaction with this `AVPlayer` instance should be handled through the `WVBUAudioManager` `sharedManager`.
    fileprivate var player = AVPlayer(url: URL(string: AudioURLStrings.MainStream.rawValue)!)
    
    /// Indicates whether the audio session is currently in an interrupted state.
    var interrupted: Bool = false
    
    /// Initializes a new instance of WVBUAudioManager. Subscribes to appropriate NSNotifications.
    /// - Note: This is a private initializer. This forces use of the `sharedManager` singleton instance.
    fileprivate override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(self.compensateForMissedAudioStateChangesInBackground), name: NSNotification.Name(rawValue: Notifications.applicationWillEnterForeground.rawValue), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.audioSessionInterrupted(_:)), name: NSNotification.Name.AVAudioSessionInterruption, object: nil)
    }
    
    /// Since this class uses a singleton, it's unlikely `deinit` will ever be called, but it's included to maintain standards anyway.
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: Notifications.applicationWillEnterForeground.rawValue), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVAudioSessionInterruption, object: nil)
    }
    
    /// Plays the audio. 
    /// To ensure that users are always listening to the live stream, this method reinitializes the `AVPlayer` instance.
    @objc func play() {
        player = AVPlayer(url: URL(string: AudioURLStrings.MainStream.rawValue)!) // Re-Initialize Player
        player.play()
        if player.isPlaying {
            print("Playing")
            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
            setAudioSessionActive(true, callingFunction: #function)
            delegate?.audioManagerDidStartPlaying()
        }
    }
    
    /// Pauses the audio.
    @objc func pause() {
        player.pause()
        if player.isPaused {
            print("Paused")
            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
            setAudioSessionActive(false, callingFunction: #function)
            delegate?.audioManagerDidStopPlaying()
        }
    }
    
    /// Plays the audio if it is paused, or pauses the audio if it is playing.
    func playPause() {
        if player.isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    /// Adjusts audio playback state to match background changes.
    /// For example, a user could pause the player in Control Center, the Lock Screen, or the pause button on headphones.
    /// This is automatically called by a notification from `applicationWillEnterForeground`.
    @objc fileprivate func compensateForMissedAudioStateChangesInBackground() {
        if player.isPaused {
            pause()
        }
    }
    
    /// Compensates for an audio session interruption.
    /// For example, the OS will interupt our audio if a phone call occurs. 
    ///  We will also be notified when the interruption has ended, allowing us to automatically resume playing audio.
    /// This is automatically called by the built-in `AVAudioSessionInterruptionNotification`.
    @objc fileprivate func audioSessionInterrupted(_ notification: Notification) {
        print("DEBUG: Audio Session was interrupted.")
        if let interruptionType = (notification as NSNotification).userInfo?[AVAudioSessionInterruptionTypeKey] as? AVAudioSessionInterruptionType {
            switch interruptionType {
            case .began:
                pause()
                interrupted = true
            case .ended:
                if let interruptionOption = (notification as NSNotification).userInfo?[AVAudioSessionInterruptionOptionKey] as? AVAudioSessionInterruptionOptions {
                    if interruptionOption == AVAudioSessionInterruptionOptions.shouldResume {
                        // It is appropriate for the app to resume audio playback without waiting for user input.
                        if (interrupted == true) { play() }
                    }
                }
                interrupted = false
            }
        }
    }

}

extension AVPlayer {
    
    var isPaused: Bool {
        get { return self.rate == 0.0 }
    }
    
    var isPlaying: Bool {
        get { return self.rate != 0.0 }
    }
    
}
