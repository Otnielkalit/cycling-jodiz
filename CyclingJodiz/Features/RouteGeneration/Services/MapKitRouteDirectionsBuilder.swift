//
//  MapKitRouteDirectionsBuilder.swift
//  CyclingJodiz
//
//  Created by otnielkalit on 11/06/26.
//

import CoreLocation
import Foundation
import MapKit
import SwiftUI

enum MapKitRouteDirectionsBuilder {
    static let assumedCyclingSpeedKmh: Double = 18
    static let maxMetersOverPreferredRouteLength: CLLocationDistance = 2000
    static let loopVersusTargetCloseMeters: CLLocationDistance = 300

    static func buildRouteCards(context: RoutePickContext) async throws -> [RouteCardModel] {
        switch context {
        case .pointToPoint(let start, let end, let preferredLengthKm):
            return try await PointToPointRouteGenerator.routesForAB(
                start: start.clLocationCoordinate2D,
                end: end.clLocationCoordinate2D,
                preferredLengthKm: preferredLengthKm
            )
        case .loop(let center, let targetKm):
            return try await LoopRouteGenerator.routesForLoop(
                center: center.clLocationCoordinate2D,
                targetKm: targetKm
            )
        }
    }

    static func estimatedCyclingDuration(distanceMeters: CLLocationDistance) -> TimeInterval {
        let mps = assumedCyclingSpeedKmh / 3.6
        return distanceMeters / max(mps, 0.01)
    }

    static func bikeEtaFootnote() -> String {
        String(localized: "Time ≈ riding at \(Int(assumedCyclingSpeedKmh)) km/h (rough plan).")
    }

    static func legRoadCharacterHint(
        distance: CLLocationDistance,
        time: TimeInterval,
        straight: CLLocationDistance,
        fromDrivingDirections: Bool
    ) -> String {
        guard fromDrivingDirections, time > 5, straight > 5, distance > 5 else {
            return String(localized: "Follow local rules; verify shoulders and traffic on-site.")
        }
        let impliedKmh = (distance / 1000) / (time / 3600)
        let sinuosity = distance / straight
        if impliedKmh >= 32, sinuosity < 1.42 {
            return String(
                localized: "Driving path looks relatively direct — likely more main or higher-speed roads; expect more traffic."
            )
        }
        if sinuosity >= 1.52 || impliedKmh < 24 {
            return String(
                localized: "Driving path winds more — often smaller links, turns, or neighborhoods; may be calmer but slower."
            )
        }
        return String(
            localized: "Mix of straighter links and turns — some busier segments possible; scout before you commit."
        )
    }

    static func routeDetailMetrics(
        coordinates: [CLLocationCoordinate2D],
        breakdownRoutes: [MKRoute],
        routeMeters: CLLocationDistance,
        durationSeconds: TimeInterval
    ) -> (
        plannedDurationSeconds: TimeInterval,
        impliedAverageSpeedKmh: Double,
        sharpTurnEstimateCount: Int,
        breakdownRows: [RouteBreakdownRow]
    ) {
        let dur = max(durationSeconds, 1)
        let implied = (routeMeters / dur) * 3.6
        let sharp = RoutePolylineMetrics.sharpTurnEstimateCount(coordinates: coordinates)
        let rows = breakdownRoutes.isEmpty ? [] : RoutePolylineMetrics.breakdownRows(from: breakdownRoutes)
        return (dur, implied, sharp, rows)
    }

    private static func rankLineColor(forRank rank: Int) -> Color {
        switch rank {
        case 0: return Color.cycleSuccess
        case 1: return Color.cycleAccent
        default: return Color.indigo
        }
    }

    static func orderedRoutesWithRankStyling(_ cards: [RouteCardModel]) -> [RouteCardModel] {
        guard !cards.isEmpty else { return cards }
        let goalM = cards.compactMap(\.targetPreferredKm).first.map { $0 * 1000 }
        let sorted = cards.sorted { a, b in
            if a.isRecommended != b.isRecommended {
                return a.isRecommended && !b.isRecommended
            }
            let aAuto = a.transportKind == .automobile
            let bAuto = b.transportKind == .automobile
            if aAuto != bAuto {
                return !aAuto && bAuto
            }
            guard let g = goalM else {
                return a.routeMeters < b.routeMeters
            }
            let da = abs(a.routeMeters - g)
            let db = abs(b.routeMeters - g)
            if abs(da - db) > 1 {
                return da < db
            }
            return a.routeMeters < b.routeMeters
        }
        return sorted.enumerated().map { rank, card in
            RouteCardModel(
                id: card.id,
                title: card.title,
                subtitle: card.subtitle,
                distanceLabel: card.distanceLabel,
                timeLabel: card.timeLabel,
                isRecommended: rank == 0,
                lineColor: rankLineColor(forRank: rank),
                coordinates: card.coordinates,
                transportKind: card.transportKind,
                crowFliesMeters: card.crowFliesMeters,
                targetPreferredKm: card.targetPreferredKm,
                routeMeters: card.routeMeters,
                plannedDurationSeconds: card.plannedDurationSeconds,
                impliedAverageSpeedKmh: card.impliedAverageSpeedKmh,
                sharpTurnEstimateCount: card.sharpTurnEstimateCount,
                breakdownRows: card.breakdownRows,
                elevationGainMeters: card.elevationGainMeters,
                recommendationTag: rank == 0 ? (card.recommendationTag ?? String(localized: "Best match")) : nil
            )
        }
    }
}
