//
//  JDHelpers.swift
//  WVBU
//
//  Created by Joe Duvall on 4/16/16.
//  Copyright © 2016 Joe Duvall. All rights reserved.
//

import UIKit
import AVFoundation

// MARK: - URLs

enum URLStrings: String {
    case MainStream = "http://stream.bucknell.edu:90/wvbu.m3u"
}

// MARK: - NSNotificationCenter Constants

enum Notifications: String {
    case applicationWillEnterForeground
}

// MARK: - Error Logging

enum ErrorSeverity: Int {
    case Critical = 5
    case Severe = 4
    case Important = 3
    case Normal = 2
    case Informational = 1
    case Debug = 0
}

func printError(error: NSError, callingFunction: String?, severity: ErrorSeverity = .Normal, customString: String? = nil) {
    print("ERROR ((\(severity.rawValue)) [\(callingFunction)]: \(error.localizedDescription)\n\(customString)")
}

func setAudioSessionActive(active: Bool, callingFunction: String? = nil) {
    let audioSession = AVAudioSession.sharedInstance()
    do {
        try audioSession.setActive(active)
        try audioSession.setCategory(AVAudioSessionCategoryPlayback)
    } catch let error as NSError {
        printError(error, callingFunction: callingFunction, severity: .Important, customString: "Error setting audio category.")
    }
}

extension UIImage {
    convenience init?(contentsOfURL url: NSURL) {
        if let data = NSData(contentsOfURL: url) {
            self.init(data: data)
        } else {
            return nil
        }
    }
}