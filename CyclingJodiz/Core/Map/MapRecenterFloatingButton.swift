//
//  MapRecenterFloatingButton.swift
//  CyclingJodiz
//
//  Created by otnielkalit on 11/06/26.
//

import MapKit
import SwiftUI

/// Floating control (Google Maps–style) to snap the map back after the user pans or zooms.
struct MapRecenterFloatingButton: View {
    let action: () -> Void
    var systemImage: String = "scope"
    var accessibilityLabel: String = String(localized: "Recenter map")

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
    /// Shows the recenter affordance when the map reports `MapCameraPosition.positionedByUser` (after pan/zoom), and hides it after programmatic camera updates.
    func mapRecenterGestureTracking(position: Binding<MapCameraPosition>, showRecenter: Binding<Bool>) -> some View {
        onMapCameraChange(frequency: .onEnd) {
            showRecenter.wrappedValue = position.wrappedValue.positionedByUser
        }
    }
}
