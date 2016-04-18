//
//  WVBUMetadataManager.swift
//  WVBU
//
//  Created by Joe Duvall on 4/16/16.
//  Copyright © 2016 Joe Duvall. All rights reserved.
//

import UIKit
import Alamofire
import AlamofireImage
import SwiftyJSON
import MediaPlayer

struct Song {
    var title: String
    var artist: String
}

protocol WVBUMetadataManagerDelegate {
    func metadataDidGetNewiTunesURL(url: NSURL?)
    func metadataDidGetNewAlbumArtwork(artworkImage: UIImage)
    func metadataDidGetNewSongAndArtist(song: String, artist: String)
    func metadataDidFailToGetAlbumArtwork(errorString: String)
    func metadataDidFailToGetSongAndArtist(errorString: String)
}

class WVBUMetadataManager {

    var delegate: WVBUMetadataManagerDelegate?
    
    var currentSongTitle: String?
    var currentSongArtist: String?
    var currentSongiTunesURL: NSURL?
    var currentSongAlbumArtwork: UIImage? {
        didSet {
            guard currentSongAlbumArtwork != nil else { return }
            var currentInfo = MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo
            currentInfo![MPMediaItemPropertyArtwork] = MPMediaItemArtwork(image: currentSongAlbumArtwork!)
            MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = currentInfo
        }
    }
    
    func requestMetadataUpdate() {
        if let song = getNowPlaying() {
            if song.title == currentSongTitle && song.artist == currentSongArtist {
                return // no update needed
            } else {
                currentSongTitle = song.title
                currentSongArtist = song.artist
                let mediaInfo = [MPMediaItemPropertyArtist : song.artist, MPMediaItemPropertyTitle : song.title]
                MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = mediaInfo
                delegate?.metadataDidGetNewSongAndArtist(song.title, artist: song.artist)
                searchForAlbumArtwork(song: song.title, artist: song.artist)
            }
        } else {
            delegate?.metadataDidFailToGetSongAndArtist("Unable to get currently-playing song.")
        }
    }
    
    func getNowPlaying() -> Song? {
        if let nowPlayingSongInput = try? String(contentsOfURL: NSURL(string: "http://eg.bucknell.edu/~wvbu/current.txt")!) {
            // should strip out brackets as well.
            let nowPlayingSongClean = nowPlayingSongInput.stringByReplacingOccurrencesOfString("^", withString: "")
            let currentSongAttributes = nowPlayingSongClean.componentsSeparatedByString("-")
            // should check for a count greater than 2.
            if currentSongAttributes.count > 1 {
                let incomingSong = currentSongAttributes[1]
                let incomingArtist = currentSongAttributes[0]
                let song = Song(title: incomingSong, artist: incomingArtist)
                return song
            }
        }
        return nil
    }
    
    func searchForAlbumArtwork(song song: String, artist: String) {
        let searchTerm = "\(song) \(artist)"
        Alamofire.request(.GET, "https://itunes.apple.com/search", parameters: [ "country" : "US", "term" : searchTerm, "entity" : "song" ], encoding: ParameterEncoding.URL, headers: ["User-Agent" : "WVBU Player v1.0"]).responseJSON { (response: Response<AnyObject, NSError>) -> Void in
            if let val = response.result.value {
                let json = JSON(val)
                if let albumArtworkURLString = json["results"][0]["artworkUrl100"].string {
                    let albumArtworkURLStringHighRes = albumArtworkURLString.stringByReplacingOccurrencesOfString("100x100", withString: "600x600")
                    Alamofire.request(.GET, albumArtworkURLStringHighRes, parameters: nil, encoding: .URL, headers: ["User-Agent" : "WVBU Player v1.0"]).responseImage(completionHandler: { (response: Response<Image, NSError>) -> Void in
                        if let image = response.result.value {
                            self.currentSongAlbumArtwork = image
                            self.delegate?.metadataDidGetNewAlbumArtwork(image)
                        } else {
                            self.delegate?.metadataDidFailToGetAlbumArtwork("Could not parse image response.")
                        }
                    })
                } else {
                    self.delegate?.metadataDidFailToGetAlbumArtwork("Could not get URL from iTunes search results.")
                }
                if let trackURLString = json["results"][0]["trackViewUrl"].string {
                    self.delegate?.metadataDidGetNewiTunesURL(NSURL(string: trackURLString))
                } else {
                    self.delegate?.metadataDidGetNewiTunesURL(nil)
                }
            } else {
                self.delegate?.metadataDidFailToGetAlbumArtwork("Invalid response from iTunes search.")
                self.delegate?.metadataDidGetNewiTunesURL(nil)
            }
        }
    }
    
}


