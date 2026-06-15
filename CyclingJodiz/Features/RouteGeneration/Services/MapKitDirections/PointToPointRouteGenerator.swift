//
//  PointToPointRouteGenerator.swift
//  CyclingJodiz
//
//  Created by otnielkalit on 16/06/26.
//

import CoreLocation
import MapKit
import SwiftUI

enum PointToPointRouteGenerator {
    static func routesForAB(
        start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D,
        preferredLengthKm: Double
    ) async throws -> [RouteCardModel] {
        var cards: [RouteCardModel] = []
        let crow = GeospatialMath.straightLineMeters(from: start, to: end)
        let targetM = preferredLengthKm * 1000

        let cycling = await MapKitDirectionsService.calculateRoutesSafe(
            from: start,
            to: end,
            transport: .cycling,
            requestsAlternateRoutes: true
        )

        var baseline: CLLocationDistance?

        for (i, route) in cycling.enumerated() {
            let coords = GeospatialMath.coordinates(from: route.polyline)
            guard !coords.isEmpty else { continue }
            if baseline == nil || route.distance < baseline! {
                baseline = route.distance
            }
            let advisory = MapKitDirectionsService.advisorySubtitle(for: route, transport: .cycling)
            let subtitle = abSubtitleAB(
                base: advisory,
                routeMeters: route.distance,
                crow: crow,
                targetKm: preferredLengthKm
            )
            let m = MapKitRouteDirectionsBuilder.routeDetailMetrics(
                coordinates: coords,
                breakdownRoutes: [route],
                routeMeters: route.distance,
                durationSeconds: route.expectedTravelTime
            )
            cards.append(
                RouteCardModel(
                    id: UUID(),
                    title: String(localized: "Bike route") + (cycling.count > 1 ? " \(i + 1)" : ""),
                    subtitle: subtitle,
                    distanceLabel: GeospatialMath.formatDistance(meters: route.distance),
                    timeLabel: GeospatialMath.formatDuration(route.expectedTravelTime),
                    isRecommended: false,
                    lineColor: i == 0 ? Color.cycleSuccess : Color.cycleAccent,
                    coordinates: coords,
                    transportKind: .cycling,
                    crowFliesMeters: crow,
                    targetPreferredKm: preferredLengthKm,
                    routeMeters: route.distance,
                    plannedDurationSeconds: m.plannedDurationSeconds,
                    impliedAverageSpeedKmh: m.impliedAverageSpeedKmh,
                    sharpTurnEstimateCount: m.sharpTurnEstimateCount,
                    breakdownRows: m.breakdownRows,
                    elevationGainMeters: nil,
                    recommendationTag: nil
                )
            )
        }

        if let b = baseline, !cycling.isEmpty, targetM > b * 1.05 {
            let detours = await abDetourCards(
                start: start,
                end: end,
                crow: crow,
                baselineMeters: b,
                targetMeters: targetM,
                preferredLengthKm: preferredLengthKm,
                existing: cards,
                firstDetourTitleIndex: 1
            )
            cards.append(contentsOf: detours)
        }

        if cards.isEmpty {
            let cars = await MapKitDirectionsService.calculateRoutesSafe(
                from: start,
                to: end,
                transport: .automobile,
                requestsAlternateRoutes: true
            )
            let topCars = Array(cars.prefix(3))
            for (i, route) in topCars.enumerated() {
                let coords = GeospatialMath.coordinates(from: route.polyline)
                guard !coords.isEmpty else { continue }
                if baseline == nil || route.distance < baseline! {
                    baseline = route.distance
                }
                let hint = MapKitRouteDirectionsBuilder.legRoadCharacterHint(
                    distance: route.distance,
                    time: route.expectedTravelTime,
                    straight: crow,
                    fromDrivingDirections: true
                )
                let bikeTime = MapKitRouteDirectionsBuilder.estimatedCyclingDuration(distanceMeters: route.distance)
                let base = String(localized: "No cycling line in Maps — polyline follows driving directions. ")
                    + hint
                    + " "
                    + MapKitRouteDirectionsBuilder.bikeEtaFootnote()
                let subtitle = abSubtitleAB(
                    base: base,
                    routeMeters: route.distance,
                    crow: crow,
                    targetKm: preferredLengthKm
                )
                let m = MapKitRouteDirectionsBuilder.routeDetailMetrics(
                    coordinates: coords,
                    breakdownRoutes: [route],
                    routeMeters: route.distance,
                    durationSeconds: bikeTime
                )
                cards.append(
                    RouteCardModel(
                        id: UUID(),
                        title: String(localized: "Road route for bike") + (topCars.count > 1 ? " \(i + 1)" : ""),
                        subtitle: subtitle,
                        distanceLabel: GeospatialMath.formatDistance(meters: route.distance),
                        timeLabel: GeospatialMath.formatDuration(bikeTime),
                        isRecommended: false,
                        lineColor: i == 0 ? Color.cycleSuccess : Color.cycleAccent,
                        coordinates: coords,
                        transportKind: .cyclingRoadEstimate,
                        crowFliesMeters: crow,
                        targetPreferredKm: preferredLengthKm,
                        routeMeters: route.distance,
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

        if cards.isEmpty {
            let walking = await MapKitDirectionsService.calculateRoutesSafe(
                from: start,
                to: end,
                transport: .walking,
                requestsAlternateRoutes: true
            )
            for (i, route) in walking.enumerated() {
                let coords = GeospatialMath.coordinates(from: route.polyline)
                guard !coords.isEmpty else { continue }
                let base = String(
                    localized: "Cycling and driving weren’t available — walking directions only (very slow vs riding)."
                )
                let subtitle = abSubtitleAB(
                    base: base,
                    routeMeters: route.distance,
                    crow: crow,
                    targetKm: preferredLengthKm
                )
                let m = MapKitRouteDirectionsBuilder.routeDetailMetrics(
                    coordinates: coords,
                    breakdownRoutes: [route],
                    routeMeters: route.distance,
                    durationSeconds: route.expectedTravelTime
                )
                cards.append(
                    RouteCardModel(
                        id: UUID(),
                        title: String(localized: "Route") + (walking.count > 1 ? " \(i + 1)" : ""),
                        subtitle: subtitle,
                        distanceLabel: GeospatialMath.formatDistance(meters: route.distance),
                        timeLabel: GeospatialMath.formatDuration(route.expectedTravelTime),
                        isRecommended: false,
                        lineColor: i == 0 ? Color.cycleSuccess : Color.cycleAccent,
                        coordinates: coords,
                        transportKind: .walking,
                        crowFliesMeters: crow,
                        targetPreferredKm: preferredLengthKm,
                        routeMeters: route.distance,
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

        if let b = baseline, !cards.isEmpty, targetM > b * 1.05,
           cards.allSatisfy({ $0.transportKind != .cycling })
        {
            let detours = await abDetourCards(
                start: start,
                end: end,
                crow: crow,
                baselineMeters: b,
                targetMeters: targetM,
                preferredLengthKm: preferredLengthKm,
                existing: cards,
                firstDetourTitleIndex: 1
            )
            cards.append(contentsOf: detours)
        }

        let autoRoutes = await MapKitDirectionsService.calculateRoutesSafe(
            from: start,
            to: end,
            transport: .automobile,
            requestsAlternateRoutes: false
        )
        if let route = autoRoutes.first, route.distance <= targetM + MapKitRouteDirectionsBuilder.maxMetersOverPreferredRouteLength {
            let coords = GeospatialMath.coordinates(from: route.polyline)
            if !coords.isEmpty {
                let hasCycling = cards.contains(where: { $0.transportKind == .cycling })
                if hasCycling {
                    let m = MapKitRouteDirectionsBuilder.routeDetailMetrics(
                        coordinates: coords,
                        breakdownRoutes: [route],
                        routeMeters: route.distance,
                        durationSeconds: route.expectedTravelTime
                    )
                    cards.append(
                        RouteCardModel(
                            id: UUID(),
                            title: String(localized: "Driving (comparison)"),
                            subtitle: String(localized: "Same A→B — car clock from Apple Maps (not bike time)."),
                            distanceLabel: GeospatialMath.formatDistance(meters: route.distance),
                            timeLabel: GeospatialMath.formatDuration(route.expectedTravelTime),
                            isRecommended: false,
                            lineColor: Color(red: 37 / 255, green: 99 / 255, blue: 235 / 255),
                            coordinates: coords,
                            transportKind: .automobile,
                            crowFliesMeters: crow,
                            targetPreferredKm: preferredLengthKm,
                            routeMeters: route.distance,
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

        guard !cards.isEmpty else { throw MapKitRouteDirectionsError.noRoutes }
        let filteredAB = cards.filter { $0.routeMeters <= targetM + MapKitRouteDirectionsBuilder.maxMetersOverPreferredRouteLength }
        guard !filteredAB.isEmpty else { throw MapKitRouteDirectionsError.noRoutesWithinTargetLengthCap }
        return MapKitRouteDirectionsBuilder.orderedRoutesWithRankStyling(markABRecommended(filteredAB))
    }

    private static func primaryLegAB(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) async -> (route: MKRoute, kind: RouteCardModel.RouteTransportKind)? {
        if let r = await MapKitDirectionsService.calculateRoutesSafe(
            from: from,
            to: to,
            transport: .cycling,
            requestsAlternateRoutes: false
        ).first {
            return (r, .cycling)
        }
        if let r = await MapKitDirectionsService.calculateRoutesSafe(
            from: from,
            to: to,
            transport: .automobile,
            requestsAlternateRoutes: false
        ).first {
            return (r, .automobile)
        }
        return nil
    }

    private static func twoLegMergedAB(
        start: CLLocationCoordinate2D,
        via: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D
    ) async -> (
        coords: [CLLocationCoordinate2D],
        dist: CLLocationDistance,
        duration: TimeInterval,
        kind: RouteCardModel.RouteTransportKind,
        routes: [MKRoute]
    )? {
        guard let leg1 = await primaryLegAB(from: start, to: via),
              let leg2 = await primaryLegAB(from: via, to: end) else { return nil }
        let c1 = GeospatialMath.coordinates(from: leg1.route.polyline)
        let c2 = GeospatialMath.coordinates(from: leg2.route.polyline)
        let merged = GeospatialMath.mergeCoordinatesJoiningNearby(c1, c2)
        guard merged.count > 2 else { return nil }
        let dist = leg1.route.distance + leg2.route.distance
        let bothCycling = leg1.kind == .cycling && leg2.kind == .cycling
        let duration = bothCycling
            ? leg1.route.expectedTravelTime + leg2.route.expectedTravelTime
            : MapKitRouteDirectionsBuilder.estimatedCyclingDuration(distanceMeters: dist)
        let kind: RouteCardModel.RouteTransportKind = bothCycling ? .cycling : .cyclingRoadEstimate
        return (merged, dist, duration, kind, [leg1.route, leg2.route])
    }

    private static func abLengthSupplement(
        routeMeters: CLLocationDistance,
        crowMeters: CLLocationDistance,
        targetKm: Double
    ) -> String {
        let targetM = targetKm * 1000
        let vsCrow = max(0, routeMeters - crowMeters)
        let vsTarget = routeMeters - targetM

        let crowLine = GeospatialMath.formatDistance(meters: crowMeters)

        let partCrow: String
        if vsCrow < 80 {
            partCrow = String(localized: "Road distance is close to straight-line A→B (~\(crowLine)).")
        } else {
            partCrow = String(
                localized: "Straight-line A→B ≈ \(crowLine); on roads this path is about \(GeospatialMath.formatDistance(meters: vsCrow)) longer (grids, one-way, etc.)."
            )
        }

        let targetStr = String(format: "%.1f", targetKm)
        let partTarget: String
        if abs(vsTarget) < 300 {
            partTarget = String(
                localized: "Your ride length preference (~\(targetStr) km) is roughly met — Maps won’t hit exact km; you still finish at B."
            )
        } else if vsTarget > 0 {
            partTarget = String(
                localized: "Versus your ~\(targetStr) km preference this line is about \(GeospatialMath.formatDistance(meters: vsTarget)) longer (approximate; same endpoint)."
            )
        } else {
            partTarget = String(
                localized: "Versus your ~\(targetStr) km preference this line is about \(GeospatialMath.formatDistance(meters: -vsTarget)) shorter (approximate; same endpoint)."
            )
        }

        return partCrow + " " + partTarget
    }

    private static func abSubtitleAB(
        base: String,
        routeMeters: CLLocationDistance,
        crow: CLLocationDistance,
        targetKm: Double
    ) -> String {
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        let sup = abLengthSupplement(routeMeters: routeMeters, crowMeters: crow, targetKm: targetKm)
        if trimmed.isEmpty { return sup }
        return trimmed + "\n\n" + sup
    }

    private static func abDetourCards(
        start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D,
        crow: CLLocationDistance,
        baselineMeters: CLLocationDistance,
        targetMeters: CLLocationDistance,
        preferredLengthKm: Double,
        existing: [RouteCardModel],
        firstDetourTitleIndex: Int
    ) async -> [RouteCardModel] {
        guard targetMeters > baselineMeters * 1.05 else { return [] }

        let mid = GeospatialMath.abMidpoint(start, end)
        let bearingAB = GeospatialMath.bearingDegrees(from: start, to: end)
        let extra = targetMeters - baselineMeters
        let cap = min(42000, max(400, extra * 0.78 + crow * 0.22))
        let template: [Double] = [400, 1100, 2800, 6500, 14000, 26000, 38000]
        let offsets = template.filter { $0 <= cap }
        guard !offsets.isEmpty else { return [] }

        struct Best {
            var dist: CLLocationDistance
            var coords: [CLLocationCoordinate2D]
            var duration: TimeInterval
            var kind: RouteCardModel.RouteTransportKind
            var mkRoutes: [MKRoute]
        }

        func bestForSide(turnLeft: Bool) async -> Best? {
            var winner: Best?
            var bestScore = Double.greatestFiniteMagnitude
            let closeEnoughM: CLLocationDistance = min(500, max(220, targetMeters * 0.04))
            for off in offsets {
                let via = GeospatialMath.perpendicularWaypoint(mid: mid, bearingAB: bearingAB, offsetMeters: off, turnLeft: turnLeft)
                guard let trip = await twoLegMergedAB(start: start, via: via, end: end) else { continue }
                guard trip.dist > baselineMeters + 120 else { continue }
                let score = abs(trip.dist - targetMeters)
                if score < bestScore {
                    bestScore = score
                    winner = Best(
                        dist: trip.dist,
                        coords: trip.coords,
                        duration: trip.duration,
                        kind: trip.kind,
                        mkRoutes: trip.routes
                    )
                    if bestScore <= closeEnoughM { break }
                }
            }
            return winner
        }

        let leftBest = await bestForSide(turnLeft: true)
        let rightBest = await bestForSide(turnLeft: false)

        func isDuplicate(_ dist: CLLocationDistance) -> Bool {
            let pool = existing + out
            return pool.contains { abs($0.routeMeters - dist) < 280 }
        }

        var out: [RouteCardModel] = []
        var idx = firstDetourTitleIndex

        func appendIfNeeded(_ best: Best?) {
            guard let b = best else { return }
            guard !isDuplicate(b.dist) else { return }
            let base = String(
                localized: "Extra distance via a waypoint off the direct corridor — still ends at your destination. Check turns on-site."
            )
            let subtitle = abSubtitleAB(base: base, routeMeters: b.dist, crow: crow, targetKm: preferredLengthKm)
            let m = MapKitRouteDirectionsBuilder.routeDetailMetrics(
                coordinates: b.coords,
                breakdownRoutes: b.mkRoutes,
                routeMeters: b.dist,
                durationSeconds: b.duration
            )
            out.append(
                RouteCardModel(
                    id: UUID(),
                    title: String(localized: "Longer path") + " \(idx)",
                    subtitle: subtitle,
                    distanceLabel: GeospatialMath.formatDistance(meters: b.dist),
                    timeLabel: GeospatialMath.formatDuration(b.duration),
                    isRecommended: false,
                    lineColor: idx % 2 == 0 ? Color.cycleAccent : Color(red: 37 / 255, green: 99 / 255, blue: 235 / 255),
                    coordinates: b.coords,
                    transportKind: b.kind,
                    crowFliesMeters: crow,
                    targetPreferredKm: preferredLengthKm,
                    routeMeters: b.dist,
                    plannedDurationSeconds: m.plannedDurationSeconds,
                    impliedAverageSpeedKmh: m.impliedAverageSpeedKmh,
                    sharpTurnEstimateCount: m.sharpTurnEstimateCount,
                    breakdownRows: m.breakdownRows,
                    elevationGainMeters: nil,
                    recommendationTag: nil
                )
            )
            idx += 1
        }

        appendIfNeeded(leftBest)
        if let R = rightBest {
            let distinctFromLeft = leftBest.map { abs(R.dist - $0.dist) > 450 } ?? true
            if distinctFromLeft {
                appendIfNeeded(rightBest)
            }
        }

        return out
    }

    private static func markABRecommended(_ cards: [RouteCardModel]) -> [RouteCardModel] {
        guard let targetKm = cards.first(where: { $0.targetPreferredKm != nil })?.targetPreferredKm else {
            return cards
        }
        let goal = targetKm * 1000
        let eligible = cards.indices.filter { cards[$0].transportKind != .automobile }
        guard let best = eligible.min(by: { abs(cards[$0].routeMeters - goal) < abs(cards[$1].routeMeters - goal) }) else {
            return cards
        }
        return cards.enumerated().map { i, c in
            c.settingRecommended(
                i == best,
                recommendationTag: i == best ? String(localized: "Best match") : nil
            )
        }
    }
}
