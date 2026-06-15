//
//  GeospatialMath.swift
//  CyclingJodiz
//
//  Created by otnielkalit on 16/06/26.
//

import CoreLocation
import MapKit

enum GeospatialMath {
    static func straightLineMeters(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> CLLocationDistance {
        CLLocation(latitude: from.latitude, longitude: from.longitude)
            .distance(from: CLLocation(latitude: to.latitude, longitude: to.longitude))
    }

    static func bearingDegrees(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let φ1 = a.latitude * .pi / 180
        let φ2 = b.latitude * .pi / 180
        let Δλ = (b.longitude - a.longitude) * .pi / 180
        let y = sin(Δλ) * cos(φ2)
        let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(Δλ)
        var θ = atan2(y, x) * 180 / .pi
        θ = (θ + 360).truncatingRemainder(dividingBy: 360)
        return θ
    }

    static func abMidpoint(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: (a.latitude + b.latitude) * 0.5, longitude: (a.longitude + b.longitude) * 0.5)
    }

    static func perpendicularWaypoint(
        mid: CLLocationCoordinate2D,
        bearingAB: Double,
        offsetMeters: Double,
        turnLeft: Bool
    ) -> CLLocationCoordinate2D {
        let perp = turnLeft ? bearingAB - 90 : bearingAB + 90
        let br = ((perp.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
        return offset(from: mid, distanceMeters: offsetMeters, bearingDegrees: br)
    }

    static func offset(
        from: CLLocationCoordinate2D,
        distanceMeters: Double,
        bearingDegrees: Double
    ) -> CLLocationCoordinate2D {
        let brng = bearingDegrees * .pi / 180
        let cosLat = cos(from.latitude * .pi / 180)
        let dLat = (distanceMeters * cos(brng)) / 111320.0
        let dLon = (distanceMeters * sin(brng)) / max(111320.0 * cosLat, 1000)
        return CLLocationCoordinate2D(latitude: from.latitude + dLat, longitude: from.longitude + dLon)
    }

    static func mergeCoordinatesJoiningNearby(
        _ first: [CLLocationCoordinate2D],
        _ second: [CLLocationCoordinate2D],
        joinEpsilonMeters: CLLocationDistance = 40
    ) -> [CLLocationCoordinate2D] {
        guard !first.isEmpty else { return second }
        guard !second.isEmpty else { return first }
        let last = first.last!
        let head = second.first!
        let d = CLLocation(latitude: last.latitude, longitude: last.longitude)
            .distance(from: CLLocation(latitude: head.latitude, longitude: head.longitude))
        if d < joinEpsilonMeters {
            return first + second.dropFirst()
        }
        return first + second
    }

    static func coordinates(from polyline: MKPolyline) -> [CLLocationCoordinate2D] {
        let n = polyline.pointCount
        guard n > 0 else { return [] }
        var buffer = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: n)
        polyline.getCoordinates(&buffer, range: NSRange(location: 0, length: n))
        return buffer.filter { CLLocationCoordinate2DIsValid($0) }
    }

    private static let distanceFormatter: MeasurementFormatter = {
        let f = MeasurementFormatter()
        f.unitOptions = .providedUnit
        f.numberFormatter.maximumFractionDigits = 1
        return f
    }()

    private static let timeFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.unitsStyle = .abbreviated
        return f
    }()

    static func formatDistance(meters: CLLocationDistance) -> String {
        let km = Measurement(value: meters / 1000, unit: UnitLength.kilometers)
        return distanceFormatter.string(from: km)
    }

    static func formatDuration(_ interval: TimeInterval) -> String {
        guard interval > 0, interval.isFinite else { return "—" }
        let totalSeconds = Int(interval.rounded())
        var components = DateComponents()
        components.hour = totalSeconds / 3600
        components.minute = (totalSeconds % 3600) / 60
        if let s = timeFormatter.string(from: components), !s.isEmpty {
            return s
        }
        let m = max(1, totalSeconds / 60)
        return "\(m) min"
    }
}
