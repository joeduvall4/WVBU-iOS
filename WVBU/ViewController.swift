//
//  ViewController.swift
//  WVBU
//
//  Created by Joe Duvall on 4/16/16.
//  Copyright © 2016 Joe Duvall. All rights reserved.
//

import UIKit

class ViewController: UIViewController, WVBUAudioManagerDelegate, WVBUMetadataManagerDelegate {

    @IBOutlet weak var albumArtworkImageView: UIImageView!
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var songLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var iTunesButton: UIButton!
    @IBOutlet weak var artworkActivityIndicator: UIActivityIndicatorView!
    
    let audioManager = WVBUAudioManager.sharedManager
    
    let metadataManager = WVBUMetadataManager()
    
    /// Timer to manage the interval between metadata updates.
    /// -Note: This is implicitly-unwrapped because we can't initialize it before the super.init call.
    var metadataUpdateTimer: NSTimer!
    
    var currentURL: NSURL? {
        didSet {
            if currentURL == nil {
                iTunesButton.enabled = false
            } else {
                iTunesButton.enabled = true
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialize()
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        initialize()
    }
    
    private func initialize() {
        audioManager.delegate = self
        metadataManager.delegate = self
        metadataUpdateTimer = NSTimer.scheduledTimerWithTimeInterval(10, target: self, selector: #selector(requestMetadataUpdate), userInfo: nil, repeats: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        requestMetadataUpdate()
    }

    func requestMetadataUpdate() {
        metadataManager.requestMetadataUpdate()
    }
    
    @IBAction func playPressed(sender: UIButton) {
        audioManager.playPause()
    }
    
}

// MARK: - WVBUAudioManagerDelegate
extension ViewController {
    func audioManagerDidStartPlaying() {
        playPauseButton.setTitle("Stop", forState: UIControlState.Normal)
        requestMetadataUpdate()
    }
    
    func audioManagerDidStopPlaying() {
        playPauseButton.setTitle("Play", forState: UIControlState.Normal)
    }
}

// MARK: - WVBUMetadataManagerDelegate
extension ViewController {
    func metadataDidGetNewAlbumArtwork(artworkImage: UIImage) {
        artworkActivityIndicator.stopAnimating()
        albumArtworkImageView.image = artworkImage
    }
    
    func metadataDidGetNewiTunesURL(url: NSURL?) {
        currentURL = url
    }
    
    func metadataDidFailToGetAlbumArtwork(errorString: String) {
        artworkActivityIndicator.stopAnimating()
        albumArtworkImageView.image = UIImage(named: "PlaceholderArtwork")
        print("Metadata Error: \(errorString)")
    }
    
    func metadataDidFailToGetSongAndArtist(errorString: String) {
        // error
    }
    
    func metadataDidGetNewSongAndArtist(song: String, artist: String) {
        artistLabel.text = "\(song)"
        songLabel.text = "\(artist)"
        artworkActivityIndicator.startAnimating()
    }
}

