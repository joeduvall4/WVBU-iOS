//
//  WVBUMetadataManager.swift
//  WVBU
//
//  Created by Joe Duvall on 4/20/16.
//  Copyright © 2016 Joe Duvall. All rights reserved.
//  Updated to remove third-party frameworks for full cross-platform compatibility on 4/24/16.
//

#if os(watchOS)
import WatchKit
import Foundation
#else
import UIKit
import MediaPlayer
#endif

struct Song: Equatable {
    var title: String
    var artist: String
}

func == (left: Song, right: Song) -> Bool {
    return (left.title == right.title) && (left.artist == right.artist)
}

// MARK: - WVBUMetadataManagerDelegate Protocol

protocol WVBUMetadataManagerDelegate {
    func metadataDidGetNewAlbumArtwork(artworkImage: UIImage)
    func metadataDidGetNewSong(song: Song)
    func metadataDidFailToGetAlbumArtwork(errorString: String?)
    func metadataDidFailToGetSongAndArtist(errorString: String?)
    func metadataDidGetNewiTunesURL(url: NSURL?)
    func metadataDidGetNewTrackID(trackID: String?)
}

// Default empty implementations of delegate methods we want to be optional.
//  We do this because in order to declare a protocol method as optional, @objc must be used.
//  If @objc is used, Swift structs cannot be used as parameters.
extension WVBUMetadataManagerDelegate {
    func metadataDidGetNewiTunesURL(url: NSURL?) { }
    func metadataDidGetNewTrackID(trackID: String?) { }
}

// MARK: - WVBUMetadataManager

class WVBUMetadataManager {
    
    var delegate: WVBUMetadataManagerDelegate?
    
    var previousSong: Song?
    var currentSong: Song? {
        didSet {
            if oldValue != currentSong && currentSong != nil {
                previousSong = oldValue
                delegate?.metadataDidGetNewSong(currentSong!)
                updateOSNowPlayingInfoCenter(.SongOnly)
                searchForAlbumArtwork(song: currentSong!.title, artist: currentSong!.artist)
            }
        }
    }
    var currentSongiTunesURL: NSURL? {
        didSet { delegate?.metadataDidGetNewiTunesURL(currentSongiTunesURL) }
    }
    var currentSongTrackID: String? {
        didSet { delegate?.metadataDidGetNewTrackID(currentSongTrackID) }
    }
    var currentSongAlbumArtwork: UIImage? {
        didSet {
            if currentSongAlbumArtwork != nil {
                delegate?.metadataDidGetNewAlbumArtwork(currentSongAlbumArtwork!)
            } else {
                delegate?.metadataDidFailToGetAlbumArtwork("")
            }
            updateOSNowPlayingInfoCenter(.ArtworkOnly)
        }
    }
    
    private enum MetadataURLString: String {
        case NowPlayingTextFile = "http://eg.bucknell.edu/~wvbu/current.txt"
        case iTunesBaseURL = "https://itunes.apple.com/search"
        case AppUserAgent = "WVBU iOS v1.0"
        case SearchCountryParameter = "US"
        case SearchEntityTypeParameter = "song"
        case HTTPMethod = "GET"
    }
    
    enum MetadataError: ErrorType {
        case NowPlaying(description: String)
        case Search(description: String)
    }
    
    enum UpdateType {
        case SongAndArtwork, SongOnly, ArtworkOnly
    }
    
    func updateOSNowPlayingInfoCenter(updateType: UpdateType) {
        #if os(watchOS)
            return
        #else
            var nowPlayingInfo = MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo
            if nowPlayingInfo == nil {
                nowPlayingInfo = [String : AnyObject]()
            }
            if updateType == .SongAndArtwork || updateType == .SongOnly {
                if currentSong != nil {
                    nowPlayingInfo![MPMediaItemPropertyTitle] = currentSong!.title
                    nowPlayingInfo![MPMediaItemPropertyArtist] = currentSong!.artist
                }
            }
            if updateType == .SongAndArtwork || updateType == .ArtworkOnly {
                if currentSongAlbumArtwork != nil {
                    nowPlayingInfo![MPMediaItemPropertyArtwork] = MPMediaItemArtwork(image: currentSongAlbumArtwork!)
                } else {
                    nowPlayingInfo![MPMediaItemPropertyArtwork] = MPMediaItemArtwork(image: UIImage(named: "PlaceholderArtwork")!)
                }
            }
            MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = nowPlayingInfo
        #endif
    }
    
}

// MARK: - Retrieve Now Playing Metadata

extension WVBUMetadataManager {
    
    func requestMetadataUpdate() {
        startURLSessionDataTask(MetadataURLString.NowPlayingTextFile.rawValue, completionHandler: handleNowPlayingResult)
    }

    private func handleNowPlayingResult(data: NSData?, response: NSURLResponse?, error: NSError?) {
        guard error == nil && data != nil else {
            failedToUpdateNowPlayingMetadata("Unable to get currently-playing song (an error occurred).")
            return
        }
        if let nowPlayingString = String(data: data!, encoding: NSUTF8StringEncoding) {
            let nowPlayingStringCleaned = nowPlayingString.stringByReplacingOccurrencesOfString("^", withString: "")
            let currentSongAttributes = nowPlayingStringCleaned.componentsSeparatedByString("-")
            // should check for a count greater than 2.
            if currentSongAttributes.count > 1 {
                currentSong = Song(title: currentSongAttributes[1], artist: currentSongAttributes[0])
            } else {
                failedToUpdateNowPlayingMetadata("Song and artist not present in downloaded data.")
            }
        } else {
            failedToUpdateNowPlayingMetadata("Could not parse data as string.")
        }
    }
    
    private func failedToUpdateNowPlayingMetadata(errorString: String?) {
        delegate?.metadataDidFailToGetSongAndArtist(errorString)
        currentSongAlbumArtwork = nil
        currentSongiTunesURL = nil
        currentSongTrackID = nil
    }

}

// MARK: - Download Album Artwork

extension WVBUMetadataManager {

    private enum AlbumArtworkSize: String {
        case Large =    "600x600"
        case Small =    "300x300"
        case Default =  "100x100"
    }
    
    private func searchForAlbumArtwork(song song: String, artist: String) {
        let searchSong = song.componentsSeparatedByCharactersInSet(NSCharacterSet(charactersInString: "[]()"))[0] // make sure we search for only the title of the song.
        let searchArtist = artist.componentsSeparatedByCharactersInSet(NSCharacterSet(charactersInString: "[]()"))[0] // make sure we search for only for first part of artist.
        sendiTunesRequest("\(searchSong) \(searchArtist)")
    }
    
    private func getAlbumArtworkSizeForCurrentPlatform() -> AlbumArtworkSize {
        #if os(watchOS)
            return .Small
        #else
            return .Large
        #endif
    }
    
    private func sendiTunesRequest(searchTerm: String) {
        sendiTunesSearchRequest(searchTerm) { (data: NSData?, response: NSURLResponse?, error: NSError?) in
            guard error == nil && data != nil else {
                self.delegate?.metadataDidFailToGetAlbumArtwork("Request to iTunes API returned an error.")
                self.currentSongiTunesURL = nil
                self.currentSongTrackID = nil
                return
            }
            self.parseiTunesJSONResponse(data!)
        }
    }

    private func parseiTunesJSONResponse(data: NSData) {
        do {
            let json = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            if let results = json["results"] as? [[String: AnyObject]] {
                if results.count > 0 {
                    // WE HAVE A MATCH!
                    if let albumArtworkURLString = results[0]["artworkUrl100"] as? String {
                        getAlbumArtwork(URLString: albumArtworkURLString)
                    } else {
                        self.delegate?.metadataDidFailToGetAlbumArtwork("Could not get URL from iTunes search results.")
                    }
                    self.currentSongiTunesURL = NSURL(stringOptional: results[0]["trackViewUrl"] as? String)
                    self.currentSongTrackID = results[0]["trackId"] as? String
                } else {
                    throw MetadataError.Search(description: "No results for iTunes search.")
                }
            } else {
                throw MetadataError.Search(description: "Unable to parse response from iTunes search.")
            }
        } catch MetadataError.Search(let description) {
            self.delegate?.metadataDidFailToGetAlbumArtwork(description)
            self.currentSongiTunesURL = nil
            self.currentSongTrackID = nil
        } catch {
            self.delegate?.metadataDidFailToGetAlbumArtwork("Error parsing data from iTunes: \(error)")
            self.currentSongiTunesURL = nil
            self.currentSongTrackID = nil
        }
    }
    
    private func getAlbumArtwork(URLString albumArtworkURLString: String) {
        let albumArtworkURLStringHighRes = albumArtworkURLString.stringByReplacingOccurrencesOfString(AlbumArtworkSize.Default.rawValue, withString: getAlbumArtworkSizeForCurrentPlatform().rawValue)
        startURLSessionDataTask(albumArtworkURLStringHighRes, completionHandler: handleNewImageResult)
    }
    
    private func handleNewImageResult(data: NSData?, response: NSURLResponse?, error: NSError?) {
        guard error == nil && data != nil else {
            self.delegate?.metadataDidFailToGetAlbumArtwork("Could not parse artwork image response.")
            return
        }
        if let image = UIImage(data: data!) {
            self.currentSongAlbumArtwork = image
            dispatch_async(dispatch_get_main_queue(), { 
                self.delegate?.metadataDidGetNewAlbumArtwork(image)
            })
        } else {
            self.delegate?.metadataDidFailToGetAlbumArtwork("Could not parse image response.")
        }
    }
    
    private func sendiTunesSearchRequest(searchTerm: String, completionHandler: (data: NSData?, response: NSURLResponse?, error: NSError?) -> Void) {
        let URLParams = [
            "country": MetadataURLString.SearchCountryParameter.rawValue,
            "term": searchTerm,
            "entity": MetadataURLString.SearchEntityTypeParameter.rawValue,
        ]
        startURLSessionDataTask(MetadataURLString.iTunesBaseURL.rawValue, URLParameters: URLParams, completionHandler: completionHandler)
    }
    
}

// MARK: - Helpers

extension WVBUMetadataManager {
    
    private func startURLSessionDataTask(URLString: String, URLParameters: [String : String]? = nil, completionHandler: (data: NSData?, response: NSURLResponse?, error: NSError?) -> Void) {
        let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration(), delegate: nil, delegateQueue: nil)
        guard var URL = NSURL(string: URLString) else {
            completionHandler(data: nil, response: nil, error: nil)
            return
        }
        if URLParameters != nil {
            URL = URL.URLByAppendingQueryParameters(URLParameters!)
        }
        let request = NSMutableURLRequest(URL: URL)
        request.HTTPMethod = MetadataURLString.HTTPMethod.rawValue
        request.addValue(MetadataURLString.AppUserAgent.rawValue, forHTTPHeaderField: "User-Agent")
        let task = session.dataTaskWithRequest(request, completionHandler: completionHandler)
        task.resume()
    }
    
}

// MARK: - Extensions

// These extensions were automatically generated by Paw ( https://luckymarmot.com/paw ), which was used to assemble some of the NSURLSession code.

protocol URLQueryParameterStringConvertible {
    var queryParameters: String {get}
}

extension Dictionary : URLQueryParameterStringConvertible {
    /**
     This computed property returns a query parameters string from the given NSDictionary. For
     example, if the input is @{@"day":@"Tuesday", @"month":@"January"}, the output
     string will be @"day=Tuesday&month=January".
     @return The computed parameters string.
     */
    var queryParameters: String {
        var parts: [String] = []
        for (key, value) in self {
            let part = NSString(format: "%@=%@",
                                String(key).stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!,
                                String(value).stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!)
            parts.append(part as String)
        }
        return parts.joinWithSeparator("&")
    }
}

extension NSURL {
    /**
     Creates a new URL by adding the given query parameters.
     @param parametersDictionary The query parameter dictionary to add.
     @return A new NSURL.
     */
    func URLByAppendingQueryParameters(parametersDictionary : Dictionary<String, String>) -> NSURL {
        let URLString : NSString = NSString(format: "%@?%@", self.absoluteString, parametersDictionary.queryParameters)
        return NSURL(string: URLString as String)!
    }
    
    convenience init?(stringOptional string: String?) {
        if string != nil {
            self.init(string: string!)
        } else {
            return nil
        }
    }
    
}

