//
//  WVBUUITests.swift
//  WVBUUITests
//
//  Created by Joe Duvall on 4/16/16.
//  Copyright © 2016 Joe Duvall. All rights reserved.
//

import XCTest

class WVBUUITests: XCTestCase {
    
    let app = XCUIApplication()
        
    override func setUp() {
        super.setUp()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        app.launch()

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testUIElementsAppearAtAppLaunch() {
        let playButton = app.buttons["Play"]
        XCTAssert(playButton.exists, "Play button did not appear at app startup.")
        
        let songLabel = app.staticTexts["Song"]
        XCTAssert(songLabel.exists, "Song label did not appear at app startup.")
        
        let artistLabel = app.staticTexts["Artist"]
        XCTAssert(artistLabel.exists, "Artist label did not appear at app startup.")
        
        let appleMusicButton = app.buttons["Apple Music"]
        XCTAssert(appleMusicButton.exists, "Apple Music button did not appear at app startup.")
        
        let albumArtwork = app.images["Album art"]
        XCTAssert(albumArtwork.exists, "Album artwork did not appear at app startup.")
        
        let navigationBarTitleView = app.navigationBars["WVBU.View"]
        XCTAssert(navigationBarTitleView.exists, "Custom navigation bar title view did not appear at app startup.")
        
        let navigationBarTitleViewHasImage = navigationBarTitleView.images.count > 0
        XCTAssert(navigationBarTitleViewHasImage, "No image found in custom navigation bar title view at app startup.")
    }
    
    func testPlayButtonChangesToPauseWhenTapped() {
        let playButton = app.buttons["Play"]
        let pauseButton = app.buttons["Pause"]
        
        XCTAssert(playButton.exists, "Play button not found.")
        playButton.tap()
        XCTAssert(pauseButton.exists, "Pause button did not appear after tapping play.")
    }
    
}
