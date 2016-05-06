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
#endif

// MARK: - WVBUMetadataManagerDelegate Protocol

@objc protocol WVBUMetadataManagerDelegate {
    func metadataDidGetNewAlbumArtwork(artworkImage: UIImage)
    func metadataDidGetNewSongAndArtist(song: String, artist: String)
    func metadataDidFailToGetAlbumArtwork(errorString: String)
    func metadataDidFailToGetSongAndArtist(errorString: String)
    optional func metadataDidGetNewiTunesURL(url: NSURL?)
    optional func metadataDidGetNewTrackID(trackID: String?)
}

// MARK: - WVBUMetadataManager

class WVBUMetadataManager {
    
    var delegate: WVBUMetadataManagerDelegate?
    
    var currentSongTitle: String?
    var currentSongArtist: String?
    var currentSongiTunesURL: NSURL?
    var currentSongAlbumArtwork: UIImage?
    
    private enum MetadataURLString: String {
        case NowPlayingTextFile = "http://eg.bucknell.edu/~wvbu/current.txt"
        case iTunesBaseURL = "https://itunes.apple.com/search"
        case AppUserAgent = "WVBU iOS v1.0"
        case SearchCountryParameter = "US"
        case SearchEntityTypeParameter = "song"
        case HTTPMethod = "GET"
    }
    
}

enum MetadataError: ErrorType {
    case NowPlaying(description: String)
    case Search(description: String)
}

// MARK: - Retrieve Now Playing Metadata

extension WVBUMetadataManager {
    
    func requestMetadataUpdate() {
        startURLSessionDataTask(MetadataURLString.NowPlayingTextFile.rawValue, completionHandler: handleNowPlayingResult)
    }

    private func handleNowPlayingResult(data: NSData?, response: NSURLResponse?, error: NSError?) {
        guard error == nil && data != nil else {
            delegate?.metadataDidFailToGetSongAndArtist("Unable to get currently-playing song (an error occurred).")
            delegate?.metadataDidFailToGetAlbumArtwork("No now playing data available to search on.")
            delegate?.metadataDidGetNewiTunesURL?(nil)
            delegate?.metadataDidGetNewTrackID?(nil)
            return
        }
        if let nowPlayingString = String(data: data!, encoding: NSUTF8StringEncoding) {
            let nowPlayingStringCleaned = nowPlayingString.stringByReplacingOccurrencesOfString("^", withString: "")
            let currentSongAttributes = nowPlayingStringCleaned.componentsSeparatedByString("-")
            // should check for a count greater than 2.
            if currentSongAttributes.count > 1 {
                let incomingSong = currentSongAttributes[1]
                let incomingArtist = currentSongAttributes[0]
                if incomingSong == currentSongTitle && incomingArtist == currentSongArtist {
                    return // no update needed
                } else {
                    currentSongTitle = incomingSong
                    currentSongArtist = incomingArtist
                    delegate?.metadataDidGetNewSongAndArtist(incomingSong, artist: incomingArtist)
                    let songToSearchFor = incomingSong.componentsSeparatedByCharactersInSet(NSCharacterSet(charactersInString: "[]()"))[0] // make sure we search for only the title of the song.
                    searchForAlbumArtwork(song: songToSearchFor, artist: incomingArtist)
                }
            } else {
                delegate?.metadataDidFailToGetSongAndArtist("Song and artist not present in downloaded data.")
                delegate?.metadataDidFailToGetAlbumArtwork("No now playing data available to search on.")
                delegate?.metadataDidGetNewiTunesURL?(nil)
                delegate?.metadataDidGetNewTrackID?(nil)
            }
        } else {
            delegate?.metadataDidFailToGetSongAndArtist("Could not parse data as string.")
            delegate?.metadataDidFailToGetAlbumArtwork("No now playing data available to search on.")
            delegate?.metadataDidGetNewiTunesURL?(nil)
            delegate?.metadataDidGetNewTrackID?(nil)
        }
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
        sendiTunesRequest("\(song) \(artist)")
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
                self.delegate?.metadataDidGetNewiTunesURL?(nil)
                self.delegate?.metadataDidGetNewTrackID?(nil)
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
                    
                    if let trackURLString = results[0]["trackViewUrl"] as? String {
                        self.delegate?.metadataDidGetNewiTunesURL?(NSURL(string: trackURLString))
                    } else {
                        self.delegate?.metadataDidGetNewiTunesURL?(nil)
                    }
                    
                    self.delegate?.metadataDidGetNewTrackID?(results[0]["trackId"] as? String)
                    
                } else {
                    throw MetadataError.Search(description: "No results for iTunes search.")
                }
            } else {
                throw MetadataError.Search(description: "Unable to parse response from iTunes search.")
            }
        } catch MetadataError.Search(let description) {
            self.delegate?.metadataDidFailToGetAlbumArtwork(description)
            self.delegate?.metadataDidGetNewiTunesURL?(nil)
        } catch {
            self.delegate?.metadataDidFailToGetAlbumArtwork("Error parsing data from iTunes: \(error)")
            self.delegate?.metadataDidGetNewiTunesURL?(nil)
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
    
}

