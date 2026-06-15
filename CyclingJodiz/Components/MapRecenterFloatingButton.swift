//
//  MapRecenterFloatingButton.swift
//  CyclingJodiz
//
//  Created by otnielkalit on 11/06/26.
//

import MapKit
import SwiftUI

struct MapRecenterFloatingButton: View {
    let action: () -> Void
    var systemImage: String = "scope"
    var accessibilityLabel: String = .init(localized: "Recenter map")

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.cyclePrimaryText)
                .frame(width: 44, height: 44)
                .background(Color.cycleCardSurface, in: Circle())
                .overlay(Circle().strokeBorder(Color.cycleBorder, lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

extension View {
    func mapRecenterGestureTracking(position: Binding<MapCameraPosition>, showRecenter: Binding<Bool>) -> some View {
        onMapCameraChange(frequency: .onEnd) {
            showRecenter.wrappedValue = position.wrappedValue.positionedByUser
        }
    }
}
