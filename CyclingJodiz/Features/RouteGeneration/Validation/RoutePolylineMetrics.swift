//
//  RoutePolylineMetrics.swift
//  CyclingJodiz
//
//  Created by otnielkalit on 11/06/26.
//

import CoreLocation
import Foundation
import MapKit

struct RouteBreakdownRow: Hashable, Sendable {
    var title: String
    var distanceMeters: CLLocationDistance
    var symbolName: String
}

enum RoutePolylineMetrics {
    static func sharpTurnEstimateCount(
        coordinates: [CLLocationCoordinate2D],
        minSegmentLengthMeters: CLLocationDistance = 12,
        minTurnDegrees: Double = 58,
        maxTurnDegrees: Double = 165,
        mergeNearbyMeters: CLLocationDistance = 42
    ) -> Int {
        guard coordinates.count >= 3 else { return 0 }

        struct Segment {
            var bearing: Double
            var end: CLLocationCoordinate2D
        }

        var segments: [Segment] = []
        segments.reserveCapacity(coordinates.count)

        for i in 1 ..< coordinates.count {
            let a = coordinates[i - 1]
            let b = coordinates[i]
            let d = CLLocation(latitude: a.latitude, longitude: a.longitude)
                .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
            guard d >= minSegmentLengthMeters else { continue }
            let br = bearingDegrees(from: a, to: b)
            segments.append(Segment(bearing: br, end: b))
        }

        guard segments.count >= 2 else { return 0 }

        var hitEnds: [CLLocationCoordinate2D] = []
        for j in 1 ..< segments.count {
            let delta = abs(angleDifferenceDegrees(segments[j - 1].bearing, segments[j].bearing))
            guard delta >= minTurnDegrees, delta <= maxTurnDegrees else { continue }
            let end = segments[j].end
            if let last = hitEnds.last {
                let gap = CLLocation(latitude: last.latitude, longitude: last.longitude)
                    .distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude))
                if gap < mergeNearbyMeters { continue }
            }
            hitEnds.append(end)
        }
        return hitEnds.count
    }

    private static func bearingDegrees(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let φ1 = a.latitude * .pi / 180
        let φ2 = b.latitude * .pi / 180
        let Δλ = (b.longitude - a.longitude) * .pi / 180
        let y = sin(Δλ) * cos(φ2)
        let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(Δλ)
        var θ = atan2(y, x) * 180 / .pi
        θ = (θ + 360).truncatingRemainder(dividingBy: 360)
        return θ
    }

    private static func angleDifferenceDegrees(_ a: Double, _ b: Double) -> Double {
        var d = (b - a).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }
        return d
    }

    

    static func breakdownRows(from routes: [MKRoute], maxRows: Int = 8) -> [RouteBreakdownRow] {
        var rows: [RouteBreakdownRow] = []
        rows.reserveCapacity(maxRows)
        outer: for route in routes {
            for step in route.steps {
                guard rows.count < maxRows else { break outer }
                let raw = step.instructions.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !raw.isEmpty else { continue }
                rows.append(
                    RouteBreakdownRow(
                        title: raw,
                        distanceMeters: step.distance,
                        symbolName: symbolName(for: step.transportType)
                    )
                )
            }
        }
        return rows
    }

    static func breakdownRows(from route: MKRoute, maxRows: Int = 8) -> [RouteBreakdownRow] {
        breakdownRows(from: [route], maxRows: maxRows)
    }

    private static func symbolName(for transport: MKDirectionsTransportType) -> String {
        switch transport {
        case .cycling:
            return "bicycle"
        case .walking:
            return "figure.walk"
        case .automobile:
            return "car.fill"
        default:
            return "arrow.triangle.turn.up.right.diamond"
        }
    }
}
