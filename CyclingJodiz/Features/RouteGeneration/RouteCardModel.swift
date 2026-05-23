//
//  RouteCardModel.swift
//  CyclingJodiz
//

import CoreLocation
import SwiftUI

struct RouteCardModel: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let distanceLabel: String
    let timeLabel: String
    let isRecommended: Bool
    let lineColor: Color
    /// Polyline untuk `MapPolyline` — dari `MKRoute.polyline`.
    let coordinates: [CLLocationCoordinate2D]
    let transportKind: RouteTransportKind
    /// Garis lurus A→B (meter); hanya diisi untuk konteks hub A→B.
    let crowFliesMeters: CLLocationDistance?
    /// Target panjang dari form (km); perkiraan, bukan syarat persis.
    let targetPreferredKm: Double?
    /// Panjang rute di jalan (MapKit / jumlah kaki); untuk rekomendasi & teks bantuan.
    let routeMeters: CLLocationDistance

    enum RouteTransportKind: Hashable {
        case cycling
        /// Jalur jalan kaki dari MapKit bila cycling tidak tersedia di wilayah ini.
        case walking
        case automobile
        /// Garis dari arah **mobil** di Maps, ditampilkan untuk pesepeda dengan **ETA perkiraan** kecepatan sepeda.
        case cyclingRoadEstimate
    }

    /// Salin kartu dengan flag rekomendasi baru (dipakai builder setelah membandingkan jarak vs target).
    func settingRecommended(_ value: Bool) -> RouteCardModel {
        RouteCardModel(
            id: id,
            title: title,
            subtitle: subtitle,
            distanceLabel: distanceLabel,
            timeLabel: timeLabel,
            isRecommended: value,
            lineColor: lineColor,
            coordinates: coordinates,
            transportKind: transportKind,
            crowFliesMeters: crowFliesMeters,
            targetPreferredKm: targetPreferredKm,
            routeMeters: routeMeters
        )
    }
}

extension RouteCardModel {
    /// Placeholder untuk preview / fallback UI.
    static func mockRoutes(center: CLLocationCoordinate2D) -> [RouteCardModel] {
        let coords0 = RoutePolylineSamples.coordinates(center: center, index: 0)
        let coords1 = RoutePolylineSamples.coordinates(center: center, index: 1)
        let coords2 = RoutePolylineSamples.coordinates(center: center, index: 2)
        return [
            RouteCardModel(
                id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-000000000001")!,
                title: String(localized: "Scenic Path"),
                subtitle: String(localized: "22.4 km · Coastal view"),
                distanceLabel: String(localized: "22.4 km"),
                timeLabel: String(localized: "1h 05m"),
                isRecommended: false,
                lineColor: Color.cycleAccent,
                coordinates: coords0,
                transportKind: .cycling,
                crowFliesMeters: nil,
                targetPreferredKm: nil,
                routeMeters: 22_400
            ),
            RouteCardModel(
                id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-000000000002")!,
                title: String(localized: "Fastest Route"),
                subtitle: String(localized: "20.5 km · Bike path & road"),
                distanceLabel: String(localized: "20.5 km"),
                timeLabel: String(localized: "58 min"),
                isRecommended: true,
                lineColor: Color.cycleSuccess,
                coordinates: coords1,
                transportKind: .cycling,
                crowFliesMeters: nil,
                targetPreferredKm: nil,
                routeMeters: 20_500
            ),
            RouteCardModel(
                id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-000000000003")!,
                title: String(localized: "City Explorer"),
                subtitle: String(localized: "19.2 km · Urban core"),
                distanceLabel: String(localized: "19.2 km"),
                timeLabel: String(localized: "1h 12m"),
                isRecommended: false,
                lineColor: Color(red: 37 / 255, green: 99 / 255, blue: 235 / 255),
                coordinates: coords2,
                transportKind: .cycling,
                crowFliesMeters: nil,
                targetPreferredKm: nil,
                routeMeters: 19_200
            )
        ]
    }
}
