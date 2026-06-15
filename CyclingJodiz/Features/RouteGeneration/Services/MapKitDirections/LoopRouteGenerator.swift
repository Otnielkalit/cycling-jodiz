//
//  LoopRouteGenerator.swift
//  CyclingJodiz
//
//  Created by otnielkalit on 16/06/26.
//

import CoreLocation
import MapKit
import SwiftUI

enum LoopRouteGenerator {
    static func routesForLoop(
        center: CLLocationCoordinate2D,
        targetKm: Double
    ) async throws -> [RouteCardModel] {
        let anchor = await tunedLoopAnchorMeters(center: center, targetKm: targetKm)
        let bearings: [Double] = [0, 125, 250]
        let targetMeters = targetKm * 1000

        var cards: [RouteCardModel] = []
        var index = 0
        var sawPureCycling = false

        for bearing in bearings {
            let dest = GeospatialMath.offset(from: center, distanceMeters: anchor, bearingDegrees: bearing)
            let outs = await loopOutboundOptions(center: center, dest: dest)
            guard let back = await loopReturnRoute(dest: dest, center: center) else { continue }
            for out in outs {
                let outCoords = GeospatialMath.coordinates(from: out.route.polyline)
                let inCoords = GeospatialMath.coordinates(from: back.route.polyline)
                guard !outCoords.isEmpty, !inCoords.isEmpty else { continue }

                let merged = GeospatialMath.mergeCoordinatesJoiningNearby(outCoords, inCoords)
                guard merged.count > 2 else { continue }

                let totalDist = out.route.distance + back.route.distance
                let bothCycling = out.kind == .cycling && back.kind == .cycling
                if bothCycling { sawPureCycling = true }

                let duration: TimeInterval = bothCycling
                    ? (out.route.expectedTravelTime + back.route.expectedTravelTime)
                    : MapKitRouteDirectionsBuilder.estimatedCyclingDuration(distanceMeters: totalDist)

                let badge: RouteCardModel.RouteTransportKind = bothCycling ? .cycling : .cyclingRoadEstimate
                let baseSubtitle = loopRoundTripSentence(
                    outRoute: out.route,
                    inRoute: back.route,
                    outKind: out.kind,
                    inKind: back.kind,
                    bothCycling: bothCycling,
                    center: center,
                    dest: dest
                )
                let subtitle = baseSubtitle + "\n\n" + loopVersusTargetAppendix(routeMeters: totalDist, targetKm: targetKm)

                let m = MapKitRouteDirectionsBuilder.routeDetailMetrics(
                    coordinates: merged,
                    breakdownRoutes: [out.route, back.route],
                    routeMeters: totalDist,
                    durationSeconds: duration
                )

                index += 1
                cards.append(
                    RouteCardModel(
                        id: UUID(),
                        title: String(localized: "Loop option") + " \(index)",
                        subtitle: subtitle,
                        distanceLabel: GeospatialMath.formatDistance(meters: totalDist),
                        timeLabel: GeospatialMath.formatDuration(duration),
                        isRecommended: false,
                        lineColor: index % 2 == 1 ? Color.cycleSuccess : Color.cycleAccent,
                        coordinates: merged,
                        transportKind: badge,
                        crowFliesMeters: nil,
                        targetPreferredKm: targetKm,
                        routeMeters: totalDist,
                        plannedDurationSeconds: m.plannedDurationSeconds,
                        impliedAverageSpeedKmh: m.impliedAverageSpeedKmh,
                        sharpTurnEstimateCount: m.sharpTurnEstimateCount,
                        breakdownRows: m.breakdownRows,
                        elevationGainMeters: nil,
                        recommendationTag: nil
                    )
                )
            }
        }

        if sawPureCycling {
            let dest0 = GeospatialMath.offset(from: center, distanceMeters: anchor, bearingDegrees: bearings[0])
            if let outCar = await MapKitDirectionsService.calculateRoutesSafe(
                from: center,
                to: dest0,
                transport: .automobile,
                requestsAlternateRoutes: false
            ).first,
                let inCar = await MapKitDirectionsService.calculateRoutesSafe(
                    from: dest0,
                    to: center,
                    transport: .automobile,
                    requestsAlternateRoutes: false
                ).first
            {
                let outC = GeospatialMath.coordinates(from: outCar.polyline)
                let inC = GeospatialMath.coordinates(from: inCar.polyline)
                if !outC.isEmpty, !inC.isEmpty {
                    let merged = GeospatialMath.mergeCoordinatesJoiningNearby(outC, inC)
                    let totalCar = outCar.distance + inCar.distance
                    if totalCar <= targetMeters + MapKitRouteDirectionsBuilder.maxMetersOverPreferredRouteLength {
                        let durCar = outCar.expectedTravelTime + inCar.expectedTravelTime
                        let baseCarSubtitle = String(localized: "Same loop shape — car clock from Apple Maps (not bike time).")
                        let subtitleCar = baseCarSubtitle + "\n\n" + loopVersusTargetAppendix(routeMeters: totalCar, targetKm: targetKm)
                        let m = MapKitRouteDirectionsBuilder.routeDetailMetrics(
                            coordinates: merged,
                            breakdownRoutes: [outCar, inCar],
                            routeMeters: totalCar,
                            durationSeconds: durCar
                        )
                        cards.append(
                            RouteCardModel(
                                id: UUID(),
                                title: String(localized: "Driving (comparison)"),
                                subtitle: subtitleCar,
                                distanceLabel: GeospatialMath.formatDistance(meters: outCar.distance + inCar.distance),
                                timeLabel: GeospatialMath.formatDuration(outCar.expectedTravelTime + inCar.expectedTravelTime),
                                isRecommended: false,
                                lineColor: Color(red: 37 / 255, green: 99 / 255, blue: 235 / 255),
                                coordinates: merged,
                                transportKind: .automobile,
                                crowFliesMeters: nil,
                                targetPreferredKm: targetKm,
                                routeMeters: totalCar,
                                plannedDurationSeconds: m.plannedDurationSeconds,
                                impliedAverageSpeedKmh: m.impliedAverageSpeedKmh,
                                sharpTurnEstimateCount: m.sharpTurnEstimateCount,
                                breakdownRows: m.breakdownRows,
                                elevationGainMeters: nil,
                                recommendationTag: nil
                            )
                        )
                    }
                }
            }
        }

        guard !cards.isEmpty else { throw MapKitRouteDirectionsError.noRoutes }
        let filtered = cards.filter { $0.routeMeters <= targetMeters + MapKitRouteDirectionsBuilder.maxMetersOverPreferredRouteLength }
        guard !filtered.isEmpty else { throw MapKitRouteDirectionsError.noRoutesWithinTargetLengthCap }
        return MapKitRouteDirectionsBuilder.orderedRoutesWithRankStyling(markLoopRecommended(filtered, targetKm: targetKm))
    }

    private static func loopGeodesicAnchorMeters(forTargetKm targetKm: Double) -> Double {
        let straight = (targetKm * 1000) / 2.35
        return min(max(straight, 600), 14000)
    }

    private static func tunedLoopAnchorMeters(center: CLLocationCoordinate2D, targetKm: Double) async -> Double {
        var m = loopGeodesicAnchorMeters(forTargetKm: targetKm)
        let dest = GeospatialMath.offset(from: center, distanceMeters: m, bearingDegrees: 0)
        guard let outPair = await loopOutboundOptions(center: center, dest: dest).first,
              let backPair = await loopReturnRoute(dest: dest, center: center)
        else {
            return m
        }
        let total = outPair.route.distance + backPair.route.distance
        let goal = targetKm * 1000
        if total > 50, goal > 50 {
            m *= min(max(goal * 1.04 / total, 0.5), 1.55)
        }
        return min(max(m, 400), 18000)
    }

    private static func loopOutboundOptions(
        center: CLLocationCoordinate2D,
        dest: CLLocationCoordinate2D
    ) async -> [(route: MKRoute, kind: RouteCardModel.RouteTransportKind)] {
        let cycling = await MapKitDirectionsService.calculateRoutesSafe(
            from: center,
            to: dest,
            transport: .cycling,
            requestsAlternateRoutes: true
        )
        if !cycling.isEmpty {
            return Array(cycling.prefix(2)).map { ($0, .cycling) }
        }
        let cars = await MapKitDirectionsService.calculateRoutesSafe(
            from: center,
            to: dest,
            transport: .automobile,
            requestsAlternateRoutes: true
        )
        return Array(cars.prefix(2)).map { ($0, .automobile) }
    }

    private static func loopReturnRoute(
        dest: CLLocationCoordinate2D,
        center: CLLocationCoordinate2D
    ) async -> (route: MKRoute, kind: RouteCardModel.RouteTransportKind)? {
        if let r = await MapKitDirectionsService.calculateRoutesSafe(
            from: dest,
            to: center,
            transport: .cycling,
            requestsAlternateRoutes: false
        ).first {
            return (r, .cycling)
        }
        if let r = await MapKitDirectionsService.calculateRoutesSafe(
            from: dest,
            to: center,
            transport: .automobile,
            requestsAlternateRoutes: false
        ).first {
            return (r, .automobile)
        }
        return nil
    }

    private static func loopRoundTripSentence(
        outRoute: MKRoute,
        inRoute: MKRoute,
        outKind: RouteCardModel.RouteTransportKind,
        inKind: RouteCardModel.RouteTransportKind,
        bothCycling: Bool,
        center: CLLocationCoordinate2D,
        dest: CLLocationCoordinate2D
    ) -> String {
        if bothCycling {
            return String(
                localized: "Apple Maps cycling round trip. Still check traffic, turns, and road surface yourself."
            )
        }

        let crowRound = max(GeospatialMath.straightLineMeters(from: center, to: dest) * 2, 1)
        var driveMeters: CLLocationDistance = 0
        var driveTime: TimeInterval = 0
        if outKind == .automobile {
            driveMeters += outRoute.distance
            driveTime += outRoute.expectedTravelTime
        }
        if inKind == .automobile {
            driveMeters += inRoute.distance
            driveTime += inRoute.expectedTravelTime
        }

        let hint: String
        if driveTime > 5, driveMeters > 5 {
            hint = MapKitRouteDirectionsBuilder.legRoadCharacterHint(
                distance: driveMeters,
                time: driveTime,
                straight: crowRound,
                fromDrivingDirections: true
            )
        } else {
            hint = String(
                localized: "Uses Maps cycling for one leg and driving roads for the other — check both halves on-site."
            )
        }

        return String(localized: "No full cycling loop in Maps — line follows driving roads where needed. ")
            + hint
            + " "
            + MapKitRouteDirectionsBuilder.bikeEtaFootnote()
    }

    private static func loopVersusTargetAppendix(routeMeters: CLLocationDistance, targetKm: Double) -> String {
        let goal = targetKm * 1000
        let delta = routeMeters - goal
        let t = String(format: "%.1f", targetKm)
        if abs(delta) < MapKitRouteDirectionsBuilder.loopVersusTargetCloseMeters {
            return String(localized: "Round trip is close to your ~\(t) km target.")
        }
        if delta >= MapKitRouteDirectionsBuilder.loopVersusTargetCloseMeters {
            let d = GeospatialMath.formatDistance(meters: delta)
            return String(localized: "About \(d) longer than your ~\(t) km target.")
        }
        let d = GeospatialMath.formatDistance(meters: -delta)
        return String(localized: "About \(d) shorter than your ~\(t) km target.")
    }

    private static func markLoopRecommended(_ cards: [RouteCardModel], targetKm: Double) -> [RouteCardModel] {
        let goal = targetKm * 1000
        let eligible = cards.indices.filter { cards[$0].transportKind != .automobile }
        guard !eligible.isEmpty else { return cards }
        guard
            let best = eligible.min(by: { abs(cards[$0].routeMeters - goal) < abs(cards[$1].routeMeters - goal) })
        else { return cards }
        return cards.enumerated().map { i, c in
            c.settingRecommended(
                i == best,
                recommendationTag: i == best ? String(localized: "Best match") : nil
            )
        }
    }
}
