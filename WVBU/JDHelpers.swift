//
//  JDHelpers.swift
//  WVBU
//
//  Created by Joe Duvall on 4/16/16.
//  Copyright © 2016 Joe Duvall. All rights reserved.
//

import UIKit
import AVFoundation

// MARK: - NSNotificationCenter Constants

enum Notifications: String {
    case applicationWillEnterForeground
}

// MARK: - Error Logging

enum ErrorSeverity: Int {
    case critical = 5
    case severe = 4
    case important = 3
    case normal = 2
    case informational = 1
    case debug = 0
}

func printError(_ error: NSError, callingFunction: String?, severity: ErrorSeverity = .normal, customString: String? = nil) {
    print("ERROR ((\(severity.rawValue)) [\(callingFunction)]: \(error.localizedDescription)\n\(customString)")
}

func setAudioSessionActive(_ active: Bool, callingFunction: String? = nil) {
    let audioSession = AVAudioSession.sharedInstance()
    do {
        try audioSession.setActive(active)
        try audioSession.setCategory(AVAudioSessionCategoryPlayback)
    } catch let error as NSError {
        printError(error, callingFunction: callingFunction, severity: .important, customString: "Error setting audio category.")
    }
}

extension UIImage {
    convenience init?(contentsOfURL url: URL) {
        if let data = try? Data(contentsOf: url) {
            self.init(data: data)
        } else {
            return nil
        }
    }
}
