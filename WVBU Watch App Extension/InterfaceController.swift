//
//  InterfaceController.swift
//  WVBU Watch App Extension
//
//  Created by Joe Duvall on 4/20/16.
//  Copyright © 2016 Joe Duvall. All rights reserved.
//

import WatchKit
import Foundation

class InterfaceController: WKInterfaceController {

    @IBOutlet var artworkInterfaceImage: WKInterfaceImage!
    
    @IBOutlet var songLabel: WKInterfaceLabel!
    
    @IBOutlet var artistLabel: WKInterfaceLabel!
    
    
    let metadataManager = WVBUMetadataManager()
    
    /// Timer to manage the interval between metadata updates.
    /// -Note: This is implicitly-unwrapped because we can't initialize it before the super.init call.
    var metadataUpdateTimer: NSTimer!
    
    override init() {
        super.init()
        initialize()
    }
    
    func initialize() {
        metadataManager.delegate = self
        metadataUpdateTimer = NSTimer.scheduledTimerWithTimeInterval(10, target: self, selector: #selector(requestMetadataUpdate), userInfo: nil, repeats: true)
    }
    
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        // Configure interface objects here.
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        requestMetadataUpdate()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

    func requestMetadataUpdate() {
        metadataManager.requestMetadataUpdate()
    }
    
}

// MARK: - WVBUMetadataManagerDelegate

extension InterfaceController: WVBUMetadataManagerDelegate {
    
    func metadataDidGetNewiTunesURL(url: NSURL?) {
        
    }
    
    func metadataDidGetNewAlbumArtwork(artworkImage: UIImage) {
        dispatch_async(dispatch_get_main_queue()) {
            self.artworkInterfaceImage.setImage(artworkImage)
        }
    }
    func metadataDidGetNewSongAndArtist(song: String, artist: String) {
        dispatch_async(dispatch_get_main_queue()) {
            self.songLabel.setText(song)
            self.artistLabel.setText(artist)
        }
    }
    func metadataDidFailToGetAlbumArtwork(errorString: String) {
        print("Failed to get album artwork.")
    }
    func metadataDidFailToGetSongAndArtist(errorString: String) {
        print("Failed to get song and artist.")
    }
    
}
