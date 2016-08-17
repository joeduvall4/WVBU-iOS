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
    var metadataUpdateTimer: Timer!
    
    var currentURL: URL? {
        didSet {
            if currentURL == nil {
                iTunesButton.isEnabled = false
            } else {
                iTunesButton.isEnabled = true
            }
        }
    }
    
    var trackID: String? {
        didSet {
            if trackID == nil {
                addToLibraryButton.isEnabled = false
            } else {
                addToLibraryButton.isEnabled = true
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialize()
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        initialize()
    }
    
    fileprivate func initialize() {
        audioManager.delegate = self
        metadataManager.delegate = self
        metadataUpdateTimer = Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(requestMetadataUpdate), userInfo: nil, repeats: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        requestMetadataUpdate()
        let titleImageView = UIImageView(image: UIImage(named: "DarkLogoSkinny"))
        titleImageView.contentMode = .scaleAspectFit
        navigationItem.titleView = titleImageView
        if navigationController != nil {
            titleImageView.frame = CGRect(x: 0.0, y: 0.0, width: navigationController!.navigationBar.frame.size.width, height: navigationController!.navigationBar.frame.size.height - 10.0)
        }
        
        //view.translatesAutoresizingMaskIntoConstraints = false
    }

    func requestMetadataUpdate() {
        metadataManager.requestMetadataUpdate()
    }
    
    @IBAction func playPressed(_ sender: UIButton) {
        audioManager.playPause()
    }
    
    @IBAction func iTunesPressed(_ sender: UIButton) {
        if currentURL != nil {
            let success = UIApplication.shared.openURL(currentURL!)
            print("Open URL \(currentURL) \(success)")
        }
    }
    
    @IBAction func addToLibraryPressed(_ sender: UIButton) {
        guard trackID != nil else { return }
        if SKCloudServiceController.authorizationStatus() != .authorized {
            SKCloudServiceController.requestAuthorization({ (status: SKCloudServiceAuthorizationStatus) in
                if status == .authorized {
                    MPMediaLibrary.default().addItem(withProductID: self.trackID!) { (entity: [MPMediaEntity], error: Error?) in
                        if error != nil {
                            print(error!.localizedDescription)
                        }
                    }
                }
            })
        } else {
            MPMediaLibrary.default().addItem(withProductID: trackID!) { (entity: [MPMediaEntity], error: Error?) in
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
        playPauseButton.setImage(UIImage(named: "Pause"), for: UIControlState())
        requestMetadataUpdate()
    }
    
    func audioManagerDidStopPlaying() {
        playPauseButton.setImage(UIImage(named: "Play"), for: UIControlState())
    }
}

// MARK: - WVBUMetadataManagerDelegate
extension ViewController {
    func metadataDidGetNewAlbumArtwork(_ artworkImage: UIImage) {
        DispatchQueue.main.async {
            self.artworkActivityIndicator.stopAnimating()
            self.albumArtworkImageView.image = artworkImage
        }
    }
    
    func metadataDidGetNewiTunesURL(_ url: URL?) {
        DispatchQueue.main.async {
            self.currentURL = url
        }
    }
    
    func metadataDidFailToGetAlbumArtwork(_ errorString: String?) {
        print("Album Artwork Error: \(errorString)")
        DispatchQueue.main.async {
            self.artworkActivityIndicator.stopAnimating()
            self.albumArtworkImageView.image = UIImage(named: "PlaceholderArtwork")
        }
    }
    
    func metadataDidFailToGetSongAndArtist(_ errorString: String?) {
        print("Metadata Error: \(errorString)")
    }
    
    func metadataDidGetNewSong(_ song: Song) {
        DispatchQueue.main.async {
            self.artistLabel.text = "\(song.artist)"
            self.songLabel.text = "\(song.title)"
            self.artworkActivityIndicator.startAnimating()
        }
    }
    
    func metadataDidGetNewTrackID(_ trackID: String?) {
        DispatchQueue.main.async {
            self.trackID = trackID
        }
    }
}

