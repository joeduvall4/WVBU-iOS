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
    func metadataDidGetNewAlbumArtwork(_ artworkImage: UIImage)
    func metadataDidGetNewSong(_ song: Song)
    func metadataDidFailToGetAlbumArtwork(_ errorString: String?)
    func metadataDidFailToGetSongAndArtist(_ errorString: String?)
    func metadataDidGetNewiTunesURL(_ url: URL?)
    func metadataDidGetNewTrackID(_ trackID: String?)
}

// Default empty implementations of delegate methods we want to be optional.
//  We do this because in order to declare a protocol method as optional, @objc must be used.
//  If @objc is used, Swift structs cannot be used as parameters.
extension WVBUMetadataManagerDelegate {
    func metadataDidGetNewiTunesURL(_ url: URL?) { }
    func metadataDidGetNewTrackID(_ trackID: String?) { }
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
                updateOSNowPlayingInfoCenter(.songOnly)
                searchForAlbumArtwork(song: currentSong!.title, artist: currentSong!.artist)
            }
        }
    }
    var currentSongiTunesURL: URL? {
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
            updateOSNowPlayingInfoCenter(.artworkOnly)
        }
    }
    
    fileprivate enum MetadataURLString: String {
        case NowPlayingTextFile = "http://eg.bucknell.edu/~wvbu/current.txt"
        case iTunesBaseURL = "https://itunes.apple.com/search"
        case AppUserAgent = "WVBU iOS v1.0"
        case SearchCountryParameter = "US"
        case SearchEntityTypeParameter = "song"
        case HTTPMethod = "GET"
    }
    
    enum MetadataError: Error {
        case nowPlaying(description: String)
        case search(description: String)
    }
    
    enum UpdateType {
        case songAndArtwork, songOnly, artworkOnly
    }
    
    func updateOSNowPlayingInfoCenter(_ updateType: UpdateType) {
        #if os(watchOS)
            return
        #else
            var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo
            if nowPlayingInfo == nil {
                nowPlayingInfo = [String : AnyObject]()
            }
            if updateType == .songAndArtwork || updateType == .songOnly {
                if currentSong != nil {
                    nowPlayingInfo![MPMediaItemPropertyTitle] = currentSong!.title
                    nowPlayingInfo![MPMediaItemPropertyArtist] = currentSong!.artist
                }
            }
            if updateType == .songAndArtwork || updateType == .artworkOnly {
                if currentSongAlbumArtwork != nil {
                    nowPlayingInfo![MPMediaItemPropertyArtwork] = MPMediaItemArtwork(image: currentSongAlbumArtwork!)
                } else {
                    nowPlayingInfo![MPMediaItemPropertyArtwork] = MPMediaItemArtwork(image: UIImage(named: "PlaceholderArtwork")!)
                }
            }
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        #endif
    }
    
}

// MARK: - Retrieve Now Playing Metadata

extension WVBUMetadataManager {
    
    func requestMetadataUpdate() {
        startURLSessionDataTask(MetadataURLString.NowPlayingTextFile.rawValue, completionHandler: handleNowPlayingResult)
    }

    fileprivate func handleNowPlayingResult(_ data: Data?, response: URLResponse?, error: Error?) {
        guard error == nil && data != nil else {
            failedToUpdateNowPlayingMetadata("Unable to get currently-playing song (an error occurred).")
            return
        }
        if let nowPlayingString = String(data: data!, encoding: String.Encoding.utf8) {
            let nowPlayingStringCleaned = nowPlayingString.replacingOccurrences(of: "^", with: "")
            let currentSongAttributes = nowPlayingStringCleaned.components(separatedBy: "-")
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
    
    fileprivate func failedToUpdateNowPlayingMetadata(_ errorString: String?) {
        delegate?.metadataDidFailToGetSongAndArtist(errorString)
        currentSongAlbumArtwork = nil
        currentSongiTunesURL = nil
        currentSongTrackID = nil
    }

}

// MARK: - Download Album Artwork

extension WVBUMetadataManager {

    fileprivate enum AlbumArtworkSize: String {
        case Large =    "600x600"
        case Small =    "300x300"
        case Default =  "100x100"
    }
    
    fileprivate func searchForAlbumArtwork(song: String, artist: String) {
        let searchSong = song.components(separatedBy: CharacterSet(charactersIn: "[]()"))[0] // make sure we search for only the title of the song.
        let searchArtist = artist.components(separatedBy: CharacterSet(charactersIn: "[]()"))[0] // make sure we search for only for first part of artist.
        sendiTunesRequest("\(searchSong) \(searchArtist)")
    }
    
    fileprivate func getAlbumArtworkSizeForCurrentPlatform() -> AlbumArtworkSize {
        #if os(watchOS)
            return .Small
        #else
            return .Large
        #endif
    }
    
    fileprivate func sendiTunesRequest(_ searchTerm: String) {
        sendiTunesSearchRequest(searchTerm) { (data: Data?, response: URLResponse?, error: Error?) in
            guard error == nil && data != nil else {
                self.delegate?.metadataDidFailToGetAlbumArtwork("Request to iTunes API returned an error.")
                self.currentSongiTunesURL = nil
                self.currentSongTrackID = nil
                return
            }
            self.parseiTunesJSONResponse(data!)
        }
    }

    fileprivate func parseiTunesJSONResponse(_ data: Data) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String : AnyObject] {
                if let results = json["results"] as? [[String: AnyObject]] {
                    if results.count > 0 {
                        // WE HAVE A MATCH!
                        if let albumArtworkURLString = results[0]["artworkUrl100"] as? String {
                            getAlbumArtwork(URLString: albumArtworkURLString)
                        } else {
                            self.delegate?.metadataDidFailToGetAlbumArtwork("Could not get URL from iTunes search results.")
                        }
                        if let currentSongiTunesString = results[0]["trackViewUrl"] as? String {
                            self.currentSongiTunesURL = URL(string: currentSongiTunesString)
                        } else {
                            throw MetadataError.search(description: "iTunes URL was nil.")
                        }
                        self.currentSongTrackID = results[0]["trackId"] as? String
                    } else {
                        throw MetadataError.search(description: "No results for iTunes search.")
                    }
                } else {
                    throw MetadataError.search(description: "Unable to parse response from iTunes search.")
                }
            } else {
                throw MetadataError.search(description: "Unable to cast JSON into dictionary.")
            }
        } catch MetadataError.search(let description) {
            self.delegate?.metadataDidFailToGetAlbumArtwork(description)
            self.currentSongiTunesURL = nil
            self.currentSongTrackID = nil
        } catch {
            self.delegate?.metadataDidFailToGetAlbumArtwork("Error parsing data from iTunes: \(error)")
            self.currentSongiTunesURL = nil
            self.currentSongTrackID = nil
        }
    }
    
    fileprivate func getAlbumArtwork(URLString albumArtworkURLString: String) {
        let albumArtworkURLStringHighRes = albumArtworkURLString.replacingOccurrences(of: AlbumArtworkSize.Default.rawValue, with: getAlbumArtworkSizeForCurrentPlatform().rawValue)
        startURLSessionDataTask(albumArtworkURLStringHighRes, completionHandler: handleNewImageResult)
    }
    
    fileprivate func handleNewImageResult(_ data: Data?, response: URLResponse?, error: Error?) {
        guard error == nil && data != nil else {
            self.delegate?.metadataDidFailToGetAlbumArtwork("Could not parse artwork image response.")
            return
        }
        if let image = UIImage(data: data!) {
            self.currentSongAlbumArtwork = image
            DispatchQueue.main.async(execute: { 
                self.delegate?.metadataDidGetNewAlbumArtwork(image)
            })
        } else {
            self.delegate?.metadataDidFailToGetAlbumArtwork("Could not parse image response.")
        }
    }
    
    fileprivate func sendiTunesSearchRequest(_ searchTerm: String, completionHandler: @escaping (_ data: Data?, _ response: URLResponse?, _ error: Error?) -> Void) {
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
    
    fileprivate func startURLSessionDataTask(_ URLString: String, URLParameters: [String : String]? = nil, completionHandler: @escaping (_ data: Data?, _ response: URLResponse?, _ error: Error?) -> Void) {
        let session = URLSession(configuration: URLSessionConfiguration.default, delegate: nil, delegateQueue: nil)
        guard var URL = URL(string: URLString) else {
            completionHandler(nil, nil, nil)
            return
        }
        if URLParameters != nil {
            URL = URL.URLByAppendingQueryParameters(parametersDictionary: URLParameters!)
        }
        var request = URLRequest(url: URL)
        request.httpMethod = MetadataURLString.HTTPMethod.rawValue
        request.addValue(MetadataURLString.AppUserAgent.rawValue, forHTTPHeaderField: "User-Agent")
        let task = session.dataTask(with: request, completionHandler: completionHandler)
        task.resume()
    }
    
}

// MARK: - Extensions

// These extensions were automatically generated by Paw ( https://luckymarmot.com/paw ), which was used to assemble some of the NSURLSession code. Modified for Swift 3 by Joe Duvall.

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
                                String(describing: key).addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed)!,
                                String(describing: value).addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed)!)
            parts.append(part as String)
        }
        return parts.joined(separator: "&")
    }
    
}

extension URL {
    /**
     Creates a new URL by adding the given query parameters.
     @param parametersDictionary The query parameter dictionary to add.
     @return A new NSURL.
     */
    func URLByAppendingQueryParameters(parametersDictionary : Dictionary<String, String>) -> URL {
        let URLString : NSString = NSString(format: "%@?%@", self.absoluteString, parametersDictionary.queryParameters)
        return URL(string: URLString as String)!
    }
}

