//
//  AppDelegate.swift
//  WVBU
//
//  Created by Joe Duvall on 4/16/16.
//  Copyright © 2016 Joe Duvall. All rights reserved.
//

import UIKit
import AVFoundation
import AlamofireNetworkActivityIndicator
import MediaPlayer

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        NetworkActivityIndicatorManager.sharedManager.isEnabled = true
        setAudioSessionActive(true, callingFunction: #function)
        
        MPRemoteCommandCenter.sharedCommandCenter().seekForwardCommand.enabled = false
        MPRemoteCommandCenter.sharedCommandCenter().nextTrackCommand.enabled = false
        MPRemoteCommandCenter.sharedCommandCenter().seekBackwardCommand.enabled = false
        MPRemoteCommandCenter.sharedCommandCenter().previousTrackCommand.enabled = false
        //MPRemoteCommandCenter.sharedCommandCenter().pauseCommand.enabled = false
        
        MPRemoteCommandCenter.sharedCommandCenter().playCommand.enabled = true
        MPRemoteCommandCenter.sharedCommandCenter().playCommand.addTarget(WVBUAudioManager.sharedManager, action: #selector(WVBUAudioManager.sharedManager.play))
        MPRemoteCommandCenter.sharedCommandCenter().pauseCommand.enabled = true
        MPRemoteCommandCenter.sharedCommandCenter().pauseCommand.addTarget(WVBUAudioManager.sharedManager, action: #selector(WVBUAudioManager.sharedManager.pause))
        
        
        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        NSNotificationCenter.defaultCenter().postNotificationName(Notifications.applicationWillEnterForeground.rawValue, object: nil)
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

}

