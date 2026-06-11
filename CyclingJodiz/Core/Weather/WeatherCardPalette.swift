//
//  WeatherCardPalette.swift
//  CyclingJodiz
//
//  Created by otnielkalit on 11/06/26.
//

import SwiftUI
import WeatherKit

enum WeatherCardPalette: Equatable {
    case fair
    case clearSky
    case softCloud
    case wet
    case caution
    case warm
    case neutral

    var cardBackground: Color {
        WeatherHueWheel.cardBackground(for: self)
    }

    var temperatureTint: Color {
        WeatherHueWheel.temperatureTint(for: self)
    }
}

extension WeatherCardPalette {
    
    static func palettePreferFair(for condition: WeatherCondition) -> WeatherCardPalette {
        switch condition {
        case .clear, .partlyCloudy:
            return .fair
        case .mostlyClear:
            return .clearSky
        case .mostlyCloudy, .cloudy, .foggy, .haze, .smoky, .breezy:
            return .softCloud
        case .hot:
            return .warm
        case .rain, .drizzle, .freezingRain, .freezingDrizzle, .sunShowers, .heavyRain, .sunFlurries:
            return .wet
        case .hail, .hurricane, .tropicalStorm, .thunderstorms, .isolatedThunderstorms,
             .scatteredThunderstorms, .strongStorms, .blizzard, .blowingSnow, .heavySnow, .snow,
             .flurries, .sleet, .windy, .blowingDust, .frigid:
            return .caution
        @unknown default:
            return .neutral
        }
    }
}

extension WeatherCondition {
    
    func cyclingSummarySentence() -> String {
        switch self {
        case .clear, .mostlyClear:
            return String(localized: "Great conditions for a ride")
        case .partlyCloudy:
            return String(localized: "Mostly fine — a few clouds")
        case .mostlyCloudy, .cloudy:
            return String(localized: "Cloudy — still rideable")
        case .foggy, .haze:
            return String(localized: "Low visibility — take care")
        case .rain, .drizzle, .sunShowers, .heavyRain:
            return String(localized: "Wet roads — plan accordingly")
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms:
            return String(localized: "Storm risk — consider delaying")
        case .snow, .flurries, .heavySnow, .blizzard, .blowingSnow, .sleet, .freezingDrizzle, .freezingRain, .sunFlurries:
            return String(localized: "Slippery possible — slow down")
        case .windy, .breezy:
            return String(localized: "Windy — stay stable on the bike")
        case .hot:
            return String(localized: "Hot — hydrate and pace yourself")
        case .frigid:
            return String(localized: "Very cold — dress for warmth")
        case .hurricane, .tropicalStorm:
            return String(localized: "Severe weather — avoid riding")
        case .hail:
            return String(localized: "Hail risk — seek shelter")
        case .smoky, .blowingDust:
            return String(localized: "Air quality may be poor")
        @unknown default:
            return String(localized: "Check conditions before you head out")
        }
    }
}
