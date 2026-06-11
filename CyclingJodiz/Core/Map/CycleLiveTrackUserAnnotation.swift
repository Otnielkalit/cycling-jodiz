//
//  CycleLiveTrackUserAnnotation.swift
//  CyclingJodiz
//
//  Created by otnielkalit on 11/06/26.
//

import CoreLocation
import SwiftUI

struct CycleLiveTrackUserAnnotation: View {
    
    var courseDegrees: CLLocationDirection?
    private var markerSize: CGFloat

    private static let assetName = "LiveTrackUserPuck"
    private static let defaultMarkerSize: CGFloat = 44

    private var rotation: Angle {
        guard let c = courseDegrees, c >= 0, c <= 360, c.isFinite else {
            return .zero
        }
        return .degrees(c)
    }

    var body: some View {
        Image(Self.assetName)
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(width: markerSize, height: markerSize)
            .rotationEffect(rotation)
            .shadow(color: .black.opacity(0.22), radius: 3, x: 0, y: 1)
            .accessibilityLabel(String(localized: "Your location on the map"))
    }
}

extension CycleLiveTrackUserAnnotation {
    
    init(location: CLLocation?, markerSize: CGFloat = Self.defaultMarkerSize) {
        self.courseDegrees = Self.validCourse(from: location)
        self.markerSize = markerSize
    }

    private static func validCourse(from location: CLLocation?) -> CLLocationDirection? {
        guard let location else { return nil }
        let c = location.course
        guard c >= 0, c <= 360, c.isFinite else { return nil }
        return c
    }
}
