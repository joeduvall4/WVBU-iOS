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

protocol WVBUMetadataManagerDelegate {
    func metadataDidGetNewiTunesURL(url: NSURL?)
    func metadataDidGetNewAlbumArtwork(artworkImage: UIImage)
    func metadataDidGetNewSongAndArtist(song: String, artist: String)
    func metadataDidFailToGetAlbumArtwork(errorString: String)
    func metadataDidFailToGetSongAndArtist(errorString: String)
}

// MARK: - WVBUMetadataManager

class WVBUMetadataManager {
    
    var delegate: WVBUMetadataManagerDelegate?
    
    var currentSongTitle: String?
    var currentSongArtist: String?
    var currentSongiTunesURL: NSURL?
    var currentSongAlbumArtwork: UIImage?
    
}

// MARK: - Retrieve Now Playing Metadata

extension WVBUMetadataManager {

    private func handleNowPlayingResult(data: NSData?, response: NSURLResponse?, error: NSError?) {
        if (error == nil) {
            if data != nil {
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
                    }
                } else {
                    delegate?.metadataDidFailToGetSongAndArtist("Could not parse data as string.")
                }
            } else {
                delegate?.metadataDidFailToGetSongAndArtist("Unable to get currently-playing song.")
            }
        } else {
            delegate?.metadataDidFailToGetSongAndArtist("Unable to download now playing data.")
            delegate?.metadataDidFailToGetAlbumArtwork("No now playing data available to search on.")
            delegate?.metadataDidGetNewiTunesURL(nil)
            print("URL Session Task Failed: %@", error!.localizedDescription);
        }
    }
    
    func requestMetadataUpdate() {
        let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration(), delegate: nil, delegateQueue: nil)
        
        guard let URL = NSURL(string: "http://eg.bucknell.edu/~wvbu/current.txt") else { return }
        let request = NSMutableURLRequest(URL: URL)
        request.HTTPMethod = "GET"
        
        let task = session.dataTaskWithRequest(request, completionHandler: handleNowPlayingResult)
        task.resume()
    }
    
}

// MARK: - Download Album Artwork

extension WVBUMetadataManager {

    enum AlbumArtworkSize: String {
        case Large =    "600x600"
        case Small =    "300x300"
        case Default =  "100x100"
    }
    
    func searchForAlbumArtwork(song song: String, artist: String) {
        let searchTerm = "\(song) \(artist)"
        #if os(watchOS)
            sendiTunesRequest(searchTerm, albumArtworkSize: .Small)
        #else
            sendiTunesRequest(searchTerm, albumArtworkSize: .Large)
        #endif
    }
    
    func sendiTunesRequest(searchTerm: String, albumArtworkSize: AlbumArtworkSize) {
        sendRequest(searchTerm) { (data: NSData?, response: NSURLResponse?, error: NSError?) in
            if (error == nil) {
                if data != nil {
                    self.parseiTunesJSONResponse(data!, albumArtworkSize: albumArtworkSize)
                } else {
                    self.delegate?.metadataDidFailToGetAlbumArtwork("Unable to obtain response from iTunes.")
                    self.delegate?.metadataDidGetNewiTunesURL(nil)
                }
            } else {
                self.delegate?.metadataDidFailToGetAlbumArtwork("Request to iTunes API returned an error.")
                self.delegate?.metadataDidGetNewiTunesURL(nil)
                print("URL Session Task Failed: %@", error!.localizedDescription);
            }
        }
    }

    func parseiTunesJSONResponse(data: NSData, albumArtworkSize: AlbumArtworkSize) {
        do {
            let json = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            if let results = json["results"] as? [[String: AnyObject]] {
                if results.count > 0 {
                    // WE HAVE A MATCH!
                    if let albumArtworkURLString = results[0]["artworkUrl100"] as? String {
                        let albumArtworkURLStringHighRes = albumArtworkURLString.stringByReplacingOccurrencesOfString(AlbumArtworkSize.Default.rawValue, withString: albumArtworkSize.rawValue)
                        if let url = NSURL(string: albumArtworkURLStringHighRes) {
                            requestImage(url)
                        } else {
                            self.delegate?.metadataDidFailToGetAlbumArtwork("Could not get URL from iTunes search results.")
                        }
                    } else {
                        self.delegate?.metadataDidFailToGetAlbumArtwork("Could not get URL from iTunes search results.")
                    }
                    
                    if let trackURLString = results[0]["trackViewUrl"] as? String {
                        self.delegate?.metadataDidGetNewiTunesURL(NSURL(string: trackURLString))
                    } else {
                        self.delegate?.metadataDidGetNewiTunesURL(nil)
                    }
                    
                } else {
                    // NO MATCH.
                    self.delegate?.metadataDidFailToGetAlbumArtwork("No results returned from iTunes search.")
                    self.delegate?.metadataDidGetNewiTunesURL(nil)
                }
            } else {
                self.delegate?.metadataDidFailToGetAlbumArtwork("Unable to parse response from iTunes search.")
                self.delegate?.metadataDidGetNewiTunesURL(nil)
            }
            
        } catch {
            self.delegate?.metadataDidFailToGetAlbumArtwork("Error parsing JSON data from iTunes.")
            self.delegate?.metadataDidGetNewiTunesURL(nil)
            print("ERROR: \(error)")
        }
    }
    
    func requestImage(url: NSURL) {
        let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration(), delegate: nil, delegateQueue: nil)
        
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "GET"
        request.addValue("WVBU iOS v1.0", forHTTPHeaderField: "User-Agent")
        
        let task = session.dataTaskWithRequest(request, completionHandler: handleNewImageResult)
        task.resume()
    }

    
    func handleNewImageResult(data: NSData?, response: NSURLResponse?, error: NSError?) {
        if (error == nil) {
            if data != nil {
                if let image = UIImage(data: data!) {
                    self.currentSongAlbumArtwork = image
                    dispatch_async(dispatch_get_main_queue(), { 
                        self.delegate?.metadataDidGetNewAlbumArtwork(image)
                    })
                } else {
                    self.delegate?.metadataDidFailToGetAlbumArtwork("Could not parse image response.")
                }
            } else {
                self.delegate?.metadataDidFailToGetAlbumArtwork("Image data was nil.")
            }
        } else {
            self.delegate?.metadataDidFailToGetAlbumArtwork("NSURLSession responded with an error.")
        }
    }
    
    func sendRequest(searchTerm: String, completionHandler: (data: NSData?, response: NSURLResponse?, error: NSError?) -> Void) {
        let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration(), delegate: nil, delegateQueue: nil)
        
        guard var URL = NSURL(string: "https://itunes.apple.com/search") else {return}
        let URLParams = [
            "country": "US",
            "term": searchTerm,
            "entity": "song",
            ]
        URL = URL.URLByAppendingQueryParameters(URLParams)
        let request = NSMutableURLRequest(URL: URL)
        request.HTTPMethod = "GET"
        request.addValue("WVBU iOS v1.0", forHTTPHeaderField: "User-Agent")
        
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

