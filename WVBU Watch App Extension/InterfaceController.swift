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
    var metadataUpdateTimer: Timer!
    
    override init() {
        super.init()
        initialize()
    }
    
    func initialize() {
        metadataManager.delegate = self
        metadataUpdateTimer = Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(requestMetadataUpdate), userInfo: nil, repeats: true)
    }
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
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
    
    func metadataDidGetNewAlbumArtwork(_ artworkImage: UIImage) {
        DispatchQueue.main.async {
            self.artworkInterfaceImage.setImage(artworkImage)
        }
    }
    func metadataDidGetNewSong(_ song: Song) {
        DispatchQueue.main.async {
            self.songLabel.setText(song.title)
            self.artistLabel.setText(song.artist)
        }
    }
    func metadataDidFailToGetAlbumArtwork(_ errorString: String?) {
        print("Failed to get album artwork.")
    }
    func metadataDidFailToGetSongAndArtist(_ errorString: String?) {
        print("Failed to get song and artist.")
    }
    
    
}
