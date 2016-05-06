//
//  ViewController.swift
//  WVBU
//
//  Created by Joe Duvall on 4/16/16.
//  Copyright © 2016 Joe Duvall. All rights reserved.
//

import UIKit
import MediaPlayer
import StoreKit

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
    @IBOutlet weak var addToLibraryButton: UIButton!
    
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
    
    var trackID: String? {
        didSet {
            if trackID == nil {
                addToLibraryButton.enabled = false
            } else {
                addToLibraryButton.enabled = true
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
    
    @IBAction func iTunesPressed(sender: UIButton) {
        if currentURL != nil {
            let success = UIApplication.sharedApplication().openURL(currentURL!)
            print("Open URL \(currentURL) \(success)")
        }
    }
    
    @IBAction func addToLibraryPressed(sender: UIButton) {
        guard trackID != nil else { return }
        if SKCloudServiceController.authorizationStatus() != .Authorized {
            SKCloudServiceController.requestAuthorization({ (status: SKCloudServiceAuthorizationStatus) in
                if status == .Authorized {
                    MPMediaLibrary.defaultMediaLibrary().addItemWithProductID(self.trackID!) { (entity: [MPMediaEntity], error: NSError?) in
                        if error != nil {
                            print(error!.localizedDescription)
                        }
                    }
                }
            })
        } else {
            MPMediaLibrary.defaultMediaLibrary().addItemWithProductID(trackID!) { (entity: [MPMediaEntity], error: NSError?) in
                if error != nil {
                    print(error!.localizedDescription)
                }
            }
        }
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
            var nowPlayingInfo = MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo
            if nowPlayingInfo == nil {
                nowPlayingInfo = [String : AnyObject]()
            }
            let mediaItemArtwork = MPMediaItemArtwork(image: artworkImage)
            nowPlayingInfo![MPMediaItemPropertyArtwork] = mediaItemArtwork
            MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = nowPlayingInfo
        }
    }
    
    func metadataDidGetNewiTunesURL(url: NSURL?) {
        dispatch_async(dispatch_get_main_queue()) {
            self.currentURL = url
        }
    }
    
    func metadataDidFailToGetAlbumArtwork(errorString: String) {
        print("Album Artwork Error: \(errorString)")
        dispatch_async(dispatch_get_main_queue()) {
            self.artworkActivityIndicator.stopAnimating()
            self.albumArtworkImageView.image = UIImage(named: "PlaceholderArtwork")
            var nowPlayingInfo = MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo
            if nowPlayingInfo == nil {
                nowPlayingInfo = [String : AnyObject]()
            }
            nowPlayingInfo![MPMediaItemPropertyArtwork] = nil
            MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = nowPlayingInfo
        }
    }
    
    func metadataDidFailToGetSongAndArtist(errorString: String) {
        print("Metadata Error: \(errorString)")
    }
    
    func metadataDidGetNewSongAndArtist(song: String, artist: String) {
        dispatch_async(dispatch_get_main_queue()) {
            var nowPlayingInfo = MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo
            if nowPlayingInfo == nil {
                nowPlayingInfo = [String : AnyObject]()
            }
            nowPlayingInfo![MPMediaItemPropertyArtist] = artist
            nowPlayingInfo![MPMediaItemPropertyTitle] = song
            MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = nowPlayingInfo
            self.artistLabel.text = "\(artist)"
            self.songLabel.text = "\(song)"
            self.artworkActivityIndicator.startAnimating()
        }
    }
    
    func metadataDidGetNewTrackID(trackID: String?) {
        dispatch_async(dispatch_get_main_queue()) {
            self.trackID = trackID
        }
    }
}

