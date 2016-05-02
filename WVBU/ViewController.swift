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
    @IBOutlet weak var playPauseButton: UIButton! {
        didSet {
            playPauseButton.tintColor = WVBUColorScheme.sharedInstance.buttonColor()
        }
    }
    @IBOutlet weak var songLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var iTunesButton: UIButton! {
        didSet {
            iTunesButton.tintColor = WVBUColorScheme.sharedInstance.buttonColor()
        }
    }
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
        let titleImageView = UIImageView(image: UIImage(named: "DarkLogoSkinny"))
        titleImageView.contentMode = .ScaleAspectFit
        navigationItem.titleView = titleImageView
        if navigationController != nil {
            titleImageView.frame = CGRect(x: 0.0, y: 0.0, width: navigationController!.navigationBar.frame.size.width, height: navigationController!.navigationBar.frame.size.height - 10.0)
        }
        
        //view.translatesAutoresizingMaskIntoConstraints = false
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
        playPauseButton.setImage(UIImage(named: "Pause"), forState: .Normal)
        requestMetadataUpdate()
    }
    
    func audioManagerDidStopPlaying() {
        playPauseButton.setImage(UIImage(named: "Play"), forState: .Normal)
    }
}

// MARK: - WVBUMetadataManagerDelegate
extension ViewController {
    func metadataDidGetNewAlbumArtwork(artworkImage: UIImage) {
        dispatch_async(dispatch_get_main_queue()) {
            self.artworkActivityIndicator.stopAnimating()
            self.albumArtworkImageView.image = artworkImage
        }
    }
    
    func metadataDidGetNewiTunesURL(url: NSURL?) {
        currentURL = url
    }
    
    func metadataDidFailToGetAlbumArtwork(errorString: String) {
        print("Album Artwork Error: \(errorString)")
        dispatch_async(dispatch_get_main_queue()) {
            self.artworkActivityIndicator.stopAnimating()
            self.albumArtworkImageView.image = UIImage(named: "PlaceholderArtwork")
        }
    }
    
    func metadataDidFailToGetSongAndArtist(errorString: String) {
        print("Metadata Error: \(errorString)")
    }
    
    func metadataDidGetNewSongAndArtist(song: String, artist: String) {
        dispatch_async(dispatch_get_main_queue()) { 
            self.artistLabel.text = "\(artist)"
            self.songLabel.text = "\(song)"
            self.artworkActivityIndicator.startAnimating()
        }
    }
}

