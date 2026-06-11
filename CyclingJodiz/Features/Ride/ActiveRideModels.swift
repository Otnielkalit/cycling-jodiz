//
//  ActiveRideModels.swift
//  CyclingJodiz
//
//  Created by otnielkalit on 11/06/26.
//

import CoreLocation
import Foundation

struct ActiveRideConfig: Hashable, Codable {
    let routeTitle: String
    let coordinates: [MapCoordinate]
    
    let totalRouteMeters: Double
    let pickContext: RoutePickContext

    static func polylineLengthMeters(_ coords: [CLLocationCoordinate2D]) -> Double {
        guard coords.count >= 2 else { return 0 }
        var sum: CLLocationDistance = 0
        for i in 1 ..< coords.count {
            let a = CLLocation(latitude: coords[i - 1].latitude, longitude: coords[i - 1].longitude)
            let b = CLLocation(latitude: coords[i].latitude, longitude: coords[i].longitude)
            sum += a.distance(from: b)
        }
        return sum
    }

    static func from(route: RouteCardModel, pickContext: RoutePickContext) -> ActiveRideConfig {
        let meters = polylineLengthMeters(route.coordinates)
        return ActiveRideConfig(
            routeTitle: route.title,
            coordinates: route.coordinates.map { MapCoordinate($0) },
            totalRouteMeters: meters,
            pickContext: pickContext
        )
    }

    
    static func demoRidgeLoop() -> ActiveRideConfig {
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: -6.198, longitude: 106.805),
            CLLocationCoordinate2D(latitude: -6.208, longitude: 106.818),
            CLLocationCoordinate2D(latitude: -6.218, longitude: 106.808),
            CLLocationCoordinate2D(latitude: -6.210, longitude: 106.798)
        ]
        let center = coords[0]
        return ActiveRideConfig(
            routeTitle: String(localized: "Ridge Loop"),
            coordinates: coords.map { MapCoordinate($0) },
            totalRouteMeters: polylineLengthMeters(coords),
            pickContext: .loop(center: MapCoordinate(center), targetKm: 24)
        )
    }
}

struct RideSummaryPayload: Identifiable, Codable, Hashable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let riddenDistanceMeters: Double
    let routeTitle: String
    let routeCoordinates: [MapCoordinate]

    var totalSeconds: TimeInterval { endedAt.timeIntervalSince(startedAt) }

    var avgSpeedKmh: Double {
        let hours = totalSeconds / 3600
        guard hours > 0.05 else { return 0 }
        return (riddenDistanceMeters / 1000) / hours
    }
}
