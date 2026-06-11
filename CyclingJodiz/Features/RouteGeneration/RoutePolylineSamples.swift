//
//  RoutePolylineSamples.swift
//  CyclingJodiz
//
//  Created by otnielkalit on 11/06/26.
//

import CoreLocation
import MapKit

enum RoutePolylineSamples {
    
    static func coordinates(center: CLLocationCoordinate2D, index: Int, pointCount: Int = 24) -> [CLLocationCoordinate2D] {
        let baseRadiusDegrees = 0.004 + Double(index) * 0.0008
        let phase = Double(index) * (.pi / 3)
        return (0 ..< pointCount).map { i in
            let t = Double(i) / Double(pointCount) * 2 * .pi
            let lat = center.latitude + baseRadiusDegrees * cos(t + phase)
            let lon = center.longitude + baseRadiusDegrees * 1.3 * sin(t + phase)
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }
}
