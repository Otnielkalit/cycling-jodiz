import CoreLocation
import Foundation
import Observation
import WeatherKit

@MainActor
@Observable
final class HomeWeatherViewModel {
    private(set) var temperatureText: String = "—"
    private(set) var summaryText: String = String(localized: "Waiting for location…")
    private(set) var symbolName: String = "location.circle"
    
    private(set) var weatherCondition: WeatherCondition?
    private(set) var palette: WeatherCardPalette = .neutral
    private(set) var isLoading: Bool = false

    private var fetchTask: Task<Void, Never>?

    private let temperatureFormatter: MeasurementFormatter = {
        let f = MeasurementFormatter()
        f.unitStyle = .medium
        f.numberFormatter.maximumFractionDigits = 0
        return f
    }()

    private let windFormatter: MeasurementFormatter = {
        let f = MeasurementFormatter()
        f.unitStyle = .short
        f.numberFormatter.maximumFractionDigits = 0
        return f
    }()

    func refresh(for location: CLLocation?) {
        fetchTask?.cancel()
        guard let location else {
            temperatureText = "—"
            summaryText = String(localized: "Turn on Location to load weather.")
            symbolName = "location.slash"
            weatherCondition = nil
            palette = .neutral
            return
        }

        fetchTask = Task { [location] in
            await self.load(for: location)
        }
    }

    private func load(for location: CLLocation) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let weather = try await WeatherService.shared.weather(for: location)

            if Task.isCancelled { return }

            let current = weather.currentWeather

            temperatureText = temperatureFormatter.string(from: current.temperature)
            symbolName = current.symbolName
            weatherCondition = current.condition

            let condition = current.condition
            palette = WeatherCardPalette.palettePreferFair(for: condition)

            var summary = condition.cyclingSummarySentence()
            let kph = current.wind.speed.converted(to: .kilometersPerHour).value
            if kph > 15 {
                let windText = windFormatter.string(from: current.wind.speed)
                summary += " · " + String(localized: "Wind") + " " + windText
            }
            summaryText = summary
        } catch {
            temperatureText = "—"
            summaryText = Self.userFacingWeatherErrorMessage(for: error)
            symbolName = "exclamationmark.triangle"
            weatherCondition = nil
            palette = .neutral
        }
    }

    private static func userFacingWeatherErrorMessage(for error: Error) -> String {
        let ns = error as NSError
        if isWeatherKitJWTAuthenticatorError(ns) {
            return String(localized: "WeatherKit couldn’t get an Apple auth token for this install. Fix: (1) developer.apple.com → Identifiers → your App ID → enable WeatherKit → Save; (2) Xcode → Signing & Capabilities → same Team, refresh automatic signing; (3) delete the app from the device, Clean Build Folder, reinstall. Needs a Paid Apple Developer Program team—free/personal teams often hit this error.")
        }
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                return String(localized: "No internet connection. Weather can’t load right now.")
            default:
                break
            }
        }
        let detail = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        #if DEBUG
        let base = String(localized: "Weather failed to load.")
        if detail.isEmpty { return base }
        return base + "\n" + detail
        #else
        _ = detail
        return String(localized: "Weather couldn’t load. In Apple Developer, enable WeatherKit for this app’s identifier, then clean build and run again.")
        #endif
    }

    
    private static func isWeatherKitJWTAuthenticatorError(_ ns: NSError) -> Bool {
        ns.domain.contains("WDSJWTAuthenticator") && ns.code == 2
    }
}
