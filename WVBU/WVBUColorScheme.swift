//
//  WVBUColorScheme.swift
//  WVBU
//
//  Created by Joe Duvall on 5/1/16.
//  Copyright © 2016 Joe Duvall. All rights reserved.
//

import UIKit

class WVBUColorScheme {
    
    enum ColorMode {
        case lightMode
        case darkMode
    }
    
    static let shared = WVBUColorScheme()
    
    var currentMode: ColorMode = .lightMode
    
    func textColor() -> UIColor {
        switch currentMode {
        case .darkMode:
            return UIColor(hexValue: 0xFFFFFF)
        case .lightMode:
            return UIColor(hexValue: 0x000000)
        }
    }
    
    func buttonColor() -> UIColor {
        switch currentMode {
        case .darkMode:
            return UIColor(hexValue: 0xFFFFFF)
        case .lightMode:
            return UIColor(hexValue: 0x004B8E)
        }
    }
    
    func backgroundColor() -> UIColor {
        switch currentMode {
        case .darkMode:
            return UIColor(hexValue: 0x505050)
        case .lightMode:
            return UIColor(hexValue: 0xFFFFFF)
        }
    }
    
    func navigationBarColor() -> UIColor {
        switch currentMode {
        case .darkMode:
            return UIColor(hexValue: 0x4A4A4A)
        case .lightMode:
            return UIColor(hexValue: 0xFFFFFF)
        }
    }
    
    func statusBarColor() -> UIColor {
        switch currentMode {
        case .darkMode:
            return UIColor(hexValue: 0xFFFFFF)
        case .lightMode:
            return UIColor(hexValue: 0x000000)
        }
    }
    
}

extension UIColor {
    ///
    /// Initializes and returns a color object using the specified opacity and hex value.
    /// - Parameter hexValue: The color's hex value.
    /// - Parameter alpha: The color's alpha value. Valid values range from 0.0 to 1.0. This parameter defaults to 1.0 if omitted.
    /// - Returns: An initialized color object.
    /// - Note: [Credit to mbigatti on GitHub Gist.](https://gist.github.com/mbigatti/c6be210a6bbc0ff25972)
    ///
    convenience init(hexValue: UInt, alpha: CGFloat = 1.0) {
        let red = CGFloat((hexValue & 0xFF0000) >> 16) / 255
        let green = CGFloat((hexValue & 0xFF00) >> 8) / 255
        let blue = CGFloat(hexValue & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    convenience init(redValue: CGFloat, greenValue: CGFloat, blueValue: CGFloat, alpha: CGFloat) {
        self.init(red: redValue/255.0, green: greenValue/255.0, blue: blueValue/255.0, alpha: alpha)
    }
    
}
