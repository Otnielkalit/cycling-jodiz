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
    
    let coordinates: [CLLocationCoordinate2D]
    let transportKind: RouteTransportKind
    
    let crowFliesMeters: CLLocationDistance?
    
    let targetPreferredKm: Double?
    
    let routeMeters: CLLocationDistance
    
    let plannedDurationSeconds: TimeInterval
    
    let impliedAverageSpeedKmh: Double
    
    let sharpTurnEstimateCount: Int
    
    let breakdownRows: [RouteBreakdownRow]
    
    let elevationGainMeters: Double?
    
    let recommendationTag: String?

    enum RouteTransportKind: Hashable {
        case cycling
        
        case walking
        case automobile
        
        case cyclingRoadEstimate
    }

    
    func settingRecommended(_ value: Bool, recommendationTag: String?) -> RouteCardModel {
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
            routeMeters: routeMeters,
            plannedDurationSeconds: plannedDurationSeconds,
            impliedAverageSpeedKmh: impliedAverageSpeedKmh,
            sharpTurnEstimateCount: sharpTurnEstimateCount,
            breakdownRows: breakdownRows,
            elevationGainMeters: elevationGainMeters,
            recommendationTag: value ? recommendationTag : nil
        )
    }
}

extension RouteCardModel {
    
    static func mockRoutes(center: CLLocationCoordinate2D) -> [RouteCardModel] {
        let coords0 = RoutePolylineSamples.coordinates(center: center, index: 0)
        let coords1 = RoutePolylineSamples.coordinates(center: center, index: 1)
        let coords2 = RoutePolylineSamples.coordinates(center: center, index: 2)
        let d0: TimeInterval = 3900
        let d1: TimeInterval = 3480
        let d2: TimeInterval = 4320
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
                routeMeters: 22_400,
                plannedDurationSeconds: d0,
                impliedAverageSpeedKmh: (22_400 / d0) * 3.6,
                sharpTurnEstimateCount: RoutePolylineMetrics.sharpTurnEstimateCount(coordinates: coords0),
                breakdownRows: [],
                elevationGainMeters: nil,
                recommendationTag: nil
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
                routeMeters: 20_500,
                plannedDurationSeconds: d1,
                impliedAverageSpeedKmh: (20_500 / d1) * 3.6,
                sharpTurnEstimateCount: RoutePolylineMetrics.sharpTurnEstimateCount(coordinates: coords1),
                breakdownRows: [],
                elevationGainMeters: nil,
                recommendationTag: String(localized: "Best match")
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
                routeMeters: 19_200,
                plannedDurationSeconds: d2,
                impliedAverageSpeedKmh: (19_200 / d2) * 3.6,
                sharpTurnEstimateCount: RoutePolylineMetrics.sharpTurnEstimateCount(coordinates: coords2),
                breakdownRows: [],
                elevationGainMeters: nil,
                recommendationTag: nil
            )
        ]
    }
}
