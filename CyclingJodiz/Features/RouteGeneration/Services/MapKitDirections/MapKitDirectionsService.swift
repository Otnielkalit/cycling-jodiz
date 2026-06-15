//
//  MapKitDirectionsService.swift
//  CyclingJodiz
//
//  Created by otnielkalit on 16/06/26.
//

import CoreLocation
import MapKit

actor MapDirectionsRequestThrottle {
    private var requestTimes: [Date] = []
    private let maxRequestsPerWindow = 35
    private let windowDuration: TimeInterval = 60

    func acquire() async {
        while true {
            let now = Date()
            requestTimes.removeAll { now.timeIntervalSince($0) > windowDuration }
            if requestTimes.count < maxRequestsPerWindow {
                requestTimes.append(now)
                return
            }
            guard let oldest = requestTimes.min() else {
                requestTimes.append(now)
                return
            }
            let wait = oldest.addingTimeInterval(windowDuration).timeIntervalSince(now) + 0.12
            let sleepSec = max(0.2, min(wait, 62))
            try? await Task.sleep(for: .seconds(sleepSec))
        }
    }
}

enum MapKitDirectionsService {
    private static let directionsThrottle = MapDirectionsRequestThrottle()

    static func calculateRoutes(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        transport: MKDirectionsTransportType,
        requestsAlternateRoutes: Bool
    ) async throws -> [MKRoute] {
        await directionsThrottle.acquire()
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = transport
        request.requestsAlternateRoutes = requestsAlternateRoutes
        do {
            let response = try await MKDirections(request: request).calculate()
            return response.routes
        } catch {
            let ns = error as NSError
            if ns.domain == "GEOErrorDomain", ns.code == -3 {
                try await Task.sleep(for: .seconds(8))
                await directionsThrottle.acquire()
                let response = try await MKDirections(request: request).calculate()
                return response.routes
            }
            throw error
        }
    }

    static func calculateRoutesSafe(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        transport: MKDirectionsTransportType,
        requestsAlternateRoutes: Bool
    ) async -> [MKRoute] {
        do {
            return try await calculateRoutes(
                from: from,
                to: to,
                transport: transport,
                requestsAlternateRoutes: requestsAlternateRoutes
            )
        } catch {
            return []
        }
    }

    static func advisorySubtitle(for route: MKRoute, transport: MKDirectionsTransportType) -> String {
        let named = route.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !named.isEmpty {
            return named
        }
        switch transport {
        case .cycling:
            return String(localized: "Apple Maps cycling directions.")
        case .walking:
            return String(localized: "Apple Maps walking directions.")
        case .automobile:
            return String(localized: "Apple Maps driving directions.")
        default:
            return String(localized: "Apple Maps.")
        }
    }
}
