//
//  CycleMapDisplayStyle.swift
//  CyclingJodiz
//
//  Created by otnielkalit on 11/06/26.
//

import MapKit
import SwiftUI

enum CycleMapDisplayStyle: String, CaseIterable, Identifiable {
    case standard
    /// Standard map with realistic elevation (buildings / terrain) plus a pitched camera when framing routes.
    case standard3D
    case hybrid
    case imagery

    var id: String { rawValue }

    static let storageKey = "cycleMapDisplayStyle"

    var title: String {
        switch self {
        case .standard:
            return String(localized: "Standard")
        case .standard3D:
            return String(localized: "3D")
        case .hybrid:
            return String(localized: "Hybrid")
        case .imagery:
            return String(localized: "Satellite")
        }
    }

    var symbolName: String {
        switch self {
        case .standard:
            return "map"
        case .standard3D:
            return "cube.fill"
        case .hybrid:
            return "square.stack.3d.up.fill"
        case .imagery:
            return "globe.americas.fill"
        }
    }

    /// When true, route framing uses a tilted `MapCamera` so the 3D map reads clearly.
    var prefersPitchedMapCamera: Bool {
        switch self {
        case .standard3D: return true
        default: return false
        }
    }

    func toMapStyle() -> MapStyle {
        switch self {
        case .standard:
            return .standard(elevation: .automatic)
        case .standard3D:
            return .standard(elevation: .realistic)
        case .hybrid:
            return .hybrid(elevation: .automatic)
        case .imagery:
            return .imagery(elevation: .automatic)
        }
    }

    static func resolved(from raw: String) -> CycleMapDisplayStyle {
        CycleMapDisplayStyle(rawValue: raw) ?? .standard
    }
}

/// Builds `MapCameraPosition` for flat vs 3D route previews.
enum CycleMapCameraFraming {
    private static let defaultPitchDegrees: Double = 52

    static func position(region: MKCoordinateRegion, displayStyle: CycleMapDisplayStyle) -> MapCameraPosition {
        guard displayStyle.prefersPitchedMapCamera else {
            return .region(region)
        }
        let center = region.center
        let latRad = center.latitude * .pi / 180
        let metersPerDegLat = 111_320.0
        let metersPerDegLon = max(cos(latRad) * 111_320.0, 1.0)
        let visibleNorthSouth = region.span.latitudeDelta * metersPerDegLat
        let visibleEastWest = region.span.longitudeDelta * metersPerDegLon
        let footprint = max(visibleNorthSouth, visibleEastWest)
        let pitch = defaultPitchDegrees
        let pitchRad = pitch * .pi / 180
        let distance = min(max(footprint / (1.85 * max(cos(pitchRad), 0.18)), 420), 90_000)
        let cam = MapCamera(
            centerCoordinate: center,
            distance: distance,
            heading: 0,
            pitch: pitch
        )
        return .camera(cam)
    }
}

struct CycleMapStylePickerMenu: View {
    @AppStorage(CycleMapDisplayStyle.storageKey) private var mapStyleRaw: String = CycleMapDisplayStyle.standard.rawValue

    var lightContent: Bool = false
    /// Larger, high-contrast control (e.g. full-screen map / satellite) so the menu stays easy to spot.
    var prominent: Bool = false

    var body: some View {
        Menu {
            Picker(String(localized: "Map type"), selection: $mapStyleRaw) {
                ForEach(CycleMapDisplayStyle.allCases) { style in
                    Label(style.title, systemImage: style.symbolName)
                        .tag(style.rawValue)
                }
            }
        } label: {
            if prominent {
                let resolved = CycleMapDisplayStyle.resolved(from: mapStyleRaw)
                Image(systemName: resolved.symbolName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 13)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.cycleAccent)
                            .shadow(color: .black.opacity(0.38), radius: 12, x: 0, y: 5)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.38), lineWidth: 1)
                    )
            } else {
                Image(systemName: CycleMapDisplayStyle.resolved(from: mapStyleRaw).symbolName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(lightContent ? Color.white : Color.primary)
            }
        }
        .accessibilityLabel(String(localized: "Map type"))
    }
}
