//
//  CycleColors.swift
//  CyclingJodiz
//
//  Created by otnielkalit on 11/06/26.
//

import SwiftUI

extension Color {
    
    private static func dynamicColor(light: Color, dark: Color) -> Color {
        Color(uiColor: UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }

    
    static let cycleAccent = dynamicColor(
        light: Color(red: 242 / 255, green: 100 / 255, blue: 25 / 255),
        dark: Color(red: 250 / 255, green: 115 / 255, blue: 45 / 255)
    )

    
    static let cycleCanvasBackground = dynamicColor(
        light: Color(red: 247 / 255, green: 247 / 255, blue: 245 / 255),
        dark: Color(red: 18 / 255, green: 18 / 255, blue: 20 / 255)
    )

    
    static let cycleCardSurface = dynamicColor(
        light: Color.white,
        dark: Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)
    )

    
    static let cycleBorder = dynamicColor(
        light: Color(red: 232 / 255, green: 230 / 255, blue: 225 / 255),
        dark: Color(red: 44 / 255, green: 44 / 255, blue: 46 / 255)
    )

    
    static let cyclePrimaryText = dynamicColor(
        light: Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255),
        dark: Color(red: 242 / 255, green: 242 / 255, blue: 247 / 255)
    )

    
    static let cycleSecondaryText = dynamicColor(
        light: Color(red: 107 / 255, green: 107 / 255, blue: 107 / 255),
        dark: Color(red: 174 / 255, green: 174 / 255, blue: 178 / 255)
    )

    
    static let cycleWeatherPositiveBackground = dynamicColor(
        light: Color(red: 240 / 255, green: 253 / 255, blue: 244 / 255),
        dark: Color(red: 20 / 255, green: 48 / 255, blue: 30 / 255)
    )

    
    static let cycleSuccess = dynamicColor(
        light: Color(red: 22 / 255, green: 163 / 255, blue: 74 / 255),
        dark: Color(red: 52 / 255, green: 199 / 255, blue: 89 / 255)
    )
}
