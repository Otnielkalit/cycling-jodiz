import Foundation
import WeatherKit

enum WeatherHomeCheerEnglish {
    static func line(
        isLoading: Bool,
        symbolName: String,
        condition: WeatherCondition?
    ) -> String {
        if isLoading {
            return "Checking the sky for you…"
        }
        if symbolName == "location.slash" {
            return "Turn on Location — we’ll hype you up with a live forecast."
        }
        if symbolName == "exclamationmark.triangle" {
            return "Forecast’s playing hard to get — your legs still work, though."
        }
        if let condition {
            return condition.cyclingCheerEnglish()
        }
        return "Skies are curious — roll out whenever you’re ready."
    }
}

extension WeatherCondition {
    func cyclingCheerEnglish() -> String {
        switch self {
        case .clear, .mostlyClear:
            return "Wow — blue skies! Today looks perfect for a ride."
        case .partlyCloudy:
            return "Sun’s peeking through — gorgeous day to get on the bike."
        case .mostlyCloudy, .cloudy:
            return "Soft light, easy pace — still a solid day to spin."
        case .foggy, .haze:
            return "Moody skies — take it smooth and enjoy the quiet roads."
        case .rain, .drizzle, .sunShowers:
            return "A little wet out — fenders on, grin on, let’s roll."
        case .heavyRain, .freezingRain, .freezingDrizzle:
            return "Proper rain — maybe shorten the loop, not the fun."
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms:
            return "Storm energy — safety first, epic coffee ride second."
        case .snow, .flurries, .heavySnow, .blizzard, .blowingSnow, .sleet, .sunFlurries:
            return "Winter postcard vibes — dress warm, ride proud."
        case .windy, .breezy:
            return "Breezy! Low gear, big smile — you’ve got this."
        case .hot:
            return "Sun’s cranked up — hydrate, pace yourself, still rideable."
        case .frigid:
            return "Crisp air — layers on, heart rate up, classic winter miles."
        case .hurricane, .tropicalStorm:
            return "Serious weather — skip the ride, dream up the next route."
        case .hail:
            return "Hail’s no joke — shelter up, plan tomorrow’s sunny loop."
        case .smoky, .blowingDust:
            return "Air’s thick — short spin or rest day, you choose."
        @unknown default:
            return "Conditions are mixing — check the sky, then clip in."
        }
    }
}
