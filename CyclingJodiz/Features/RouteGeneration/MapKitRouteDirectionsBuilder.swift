import CoreLocation
import Foundation
import MapKit
import SwiftUI

/// Apple throttles `MKDirections` (commonly 50 requests / 60 s per app). Space calls out and wait when the window is full.
private actor MapDirectionsRequestThrottle {
    private var requestTimes: [Date] = []
    /// Stay under Apple’s short-window cap so route generation stays reliable during dev / “Find routes” retries.
    private let maxRequestsPerWindow = 35
    private let windowDuration: TimeInterval = 60

    func acquire() async {
        while true {
            let now = Date()
            requestTimes.removeAll { now.timeIntervalSince($0) > windowDuration }
            if requestTimes.count < maxRequestsPerWindow {
                requestTimes.append(now)
                return
            }
            guard let oldest = requestTimes.min() else {
                requestTimes.append(now)
                return
            }
            let wait = oldest.addingTimeInterval(windowDuration).timeIntervalSince(now) + 0.12
            let sleepSec = max(0.2, min(wait, 62))
            try? await Task.sleep(for: .seconds(sleepSec))
        }
    }
}

enum MapKitRouteDirectionsError: LocalizedError {
    case noRoutes
    case noRoutesWithinTargetLengthCap
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .noRoutes:
            return String(localized: "No routes returned from Maps.")
        case .noRoutesWithinTargetLengthCap:
            return String(localized: "No routes within 2 km over your target length. Try different places or distance.")
        case .underlying(let error):
            return error.localizedDescription
        }
    }
}

enum MapKitRouteDirectionsBuilder {

    private static let directionsThrottle = MapDirectionsRequestThrottle()

    
    private static let assumedCyclingSpeedKmh: Double = 18

    private static let maxMetersOverPreferredRouteLength: CLLocationDistance = 2000

    private static let loopVersusTargetCloseMeters: CLLocationDistance = 300

    static func buildRouteCards(context: RoutePickContext) async throws -> [RouteCardModel] {
        switch context {
        case .pointToPoint(let start, let end, let preferredLengthKm):
            try await routesForAB(
                start: start.clLocationCoordinate2D,
                end: end.clLocationCoordinate2D,
                preferredLengthKm: preferredLengthKm
            )
        case .loop(let center, let targetKm):
            try await routesForLoop(center: center.clLocationCoordinate2D, targetKm: targetKm)
        }
    }

    private static func estimatedCyclingDuration(distanceMeters: CLLocationDistance) -> TimeInterval {
        let mps = assumedCyclingSpeedKmh / 3.6
        return distanceMeters / max(mps, 0.01)
    }

    private static func straightLineMeters(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> CLLocationDistance {
        CLLocation(latitude: from.latitude, longitude: from.longitude)
            .distance(from: CLLocation(latitude: to.latitude, longitude: to.longitude))
    }

    private static func bikeEtaFootnote() -> String {
        String(localized: "Time ≈ riding at \(Int(assumedCyclingSpeedKmh)) km/h (rough plan).")
    }

    
    private static func legRoadCharacterHint(
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

    private static func abMidpoint(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: (a.latitude + b.latitude) * 0.5, longitude: (a.longitude + b.longitude) * 0.5)
    }

    private static func perpendicularWaypoint(
        mid: CLLocationCoordinate2D,
        bearingAB: Double,
        offsetMeters: Double,
        turnLeft: Bool
    ) -> CLLocationCoordinate2D {
        let perp = turnLeft ? bearingAB - 90 : bearingAB + 90
        let br = ((perp.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
        return offset(from: mid, distanceMeters: offsetMeters, bearingDegrees: br)
    }

    private static func primaryLegAB(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) async -> (route: MKRoute, kind: RouteCardModel.RouteTransportKind)? {
        if let r = await calculateRoutesSafe(
            from: from,
            to: to,
            transport: .cycling,
            requestsAlternateRoutes: false
        ).first {
            return (r, .cycling)
        }
        if let r = await calculateRoutesSafe(
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
        let c1 = coordinates(from: leg1.route.polyline)
        let c2 = coordinates(from: leg2.route.polyline)
        let merged = mergeCoordinatesJoiningNearby(c1, c2)
        guard merged.count > 2 else { return nil }
        let dist = leg1.route.distance + leg2.route.distance
        let bothCycling = leg1.kind == .cycling && leg2.kind == .cycling
        let duration = bothCycling
            ? leg1.route.expectedTravelTime + leg2.route.expectedTravelTime
            : estimatedCyclingDuration(distanceMeters: dist)
        let kind: RouteCardModel.RouteTransportKind = bothCycling ? .cycling : .cyclingRoadEstimate
        return (merged, dist, duration, kind, [leg1.route, leg2.route])
    }

    private static func routeDetailMetrics(
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

    
    private static func abLengthSupplement(
        routeMeters: CLLocationDistance,
        crowMeters: CLLocationDistance,
        targetKm: Double
    ) -> String {
        let targetM = targetKm * 1000
        let vsCrow = max(0, routeMeters - crowMeters)
        let vsTarget = routeMeters - targetM

        let crowLine = formatDistance(meters: crowMeters)

        let partCrow: String
        if vsCrow < 80 {
            partCrow = String(localized: "Road distance is close to straight-line A→B (~\(crowLine)).")
        } else {
            partCrow = String(
                localized: "Straight-line A→B ≈ \(crowLine); on roads this path is about \(formatDistance(meters: vsCrow)) longer (grids, one-way, etc.)."
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
                localized: "Versus your ~\(targetStr) km preference this line is about \(formatDistance(meters: vsTarget)) longer (approximate; same endpoint)."
            )
        } else {
            partTarget = String(
                localized: "Versus your ~\(targetStr) km preference this line is about \(formatDistance(meters: -vsTarget)) shorter (approximate; same endpoint)."
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

        let mid = abMidpoint(start, end)
        let bearingAB = bearingDegrees(from: start, to: end)
        let extra = targetMeters - baselineMeters
        let cap = min(42_000, max(400, extra * 0.78 + crow * 0.22))
        // Fewer samples than before: each offset can cost several MKDirections calls (two legs × mode fallbacks).
        let template: [Double] = [400, 1100, 2800, 6500, 14_000, 26_000, 38_000]
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
                let via = perpendicularWaypoint(mid: mid, bearingAB: bearingAB, offsetMeters: off, turnLeft: turnLeft)
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
            let m = routeDetailMetrics(
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
                    distanceLabel: formatDistance(meters: b.dist),
                    timeLabel: formatDuration(b.duration),
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

    private static func rankLineColor(forRank rank: Int) -> Color {
        switch rank {
        case 0: return Color.cycleSuccess
        case 1: return Color.cycleAccent
        default: return Color.indigo
        }
    }

    private static func orderedRoutesWithRankStyling(_ cards: [RouteCardModel]) -> [RouteCardModel] {
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

    private static func routesForAB(
        start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D,
        preferredLengthKm: Double
    ) async throws -> [RouteCardModel] {
        var cards: [RouteCardModel] = []
        let crow = straightLineMeters(from: start, to: end)
        let targetM = preferredLengthKm * 1000

        let cycling = await calculateRoutesSafe(
            from: start,
            to: end,
            transport: .cycling,
            requestsAlternateRoutes: true
        )

        var baseline: CLLocationDistance?

        for (i, route) in cycling.enumerated() {
            let coords = coordinates(from: route.polyline)
            guard !coords.isEmpty else { continue }
            if baseline == nil || route.distance < baseline! {
                baseline = route.distance
            }
            let advisory = advisorySubtitle(for: route, transport: .cycling)
            let subtitle = abSubtitleAB(
                base: advisory,
                routeMeters: route.distance,
                crow: crow,
                targetKm: preferredLengthKm
            )
            let m = routeDetailMetrics(
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
                    distanceLabel: formatDistance(meters: route.distance),
                    timeLabel: formatDuration(route.expectedTravelTime),
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
            let cars = await calculateRoutesSafe(
                from: start,
                to: end,
                transport: .automobile,
                requestsAlternateRoutes: true
            )
            let topCars = Array(cars.prefix(3))
            for (i, route) in topCars.enumerated() {
                let coords = coordinates(from: route.polyline)
                guard !coords.isEmpty else { continue }
                if baseline == nil || route.distance < baseline! {
                    baseline = route.distance
                }
                let hint = legRoadCharacterHint(
                    distance: route.distance,
                    time: route.expectedTravelTime,
                    straight: crow,
                    fromDrivingDirections: true
                )
                let bikeTime = estimatedCyclingDuration(distanceMeters: route.distance)
                let base = String(localized: "No cycling line in Maps — polyline follows driving directions. ")
                    + hint
                    + " "
                    + bikeEtaFootnote()
                let subtitle = abSubtitleAB(
                    base: base,
                    routeMeters: route.distance,
                    crow: crow,
                    targetKm: preferredLengthKm
                )
                let m = routeDetailMetrics(
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
                        distanceLabel: formatDistance(meters: route.distance),
                        timeLabel: formatDuration(bikeTime),
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
            let walking = await calculateRoutesSafe(
                from: start,
                to: end,
                transport: .walking,
                requestsAlternateRoutes: true
            )
            for (i, route) in walking.enumerated() {
                let coords = coordinates(from: route.polyline)
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
                let m = routeDetailMetrics(
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
                        distanceLabel: formatDistance(meters: route.distance),
                        timeLabel: formatDuration(route.expectedTravelTime),
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
           cards.allSatisfy({ $0.transportKind != .cycling }) {
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

        let autoRoutes = await calculateRoutesSafe(
            from: start,
            to: end,
            transport: .automobile,
            requestsAlternateRoutes: false
        )
        if let route = autoRoutes.first, route.distance <= targetM + maxMetersOverPreferredRouteLength {
            let coords = coordinates(from: route.polyline)
            if !coords.isEmpty {
                let hasCycling = cards.contains(where: { $0.transportKind == .cycling })
                if hasCycling {
                    let m = routeDetailMetrics(
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
                            distanceLabel: formatDistance(meters: route.distance),
                            timeLabel: formatDuration(route.expectedTravelTime),
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
        let filteredAB = cards.filter { $0.routeMeters <= targetM + maxMetersOverPreferredRouteLength }
        guard !filteredAB.isEmpty else { throw MapKitRouteDirectionsError.noRoutesWithinTargetLengthCap }
        return orderedRoutesWithRankStyling(markABRecommended(filteredAB))
    }

    

    
    private static func loopGeodesicAnchorMeters(forTargetKm targetKm: Double) -> Double {
        let straight = (targetKm * 1000) / 2.35
        return min(max(straight, 600), 14_000)
    }

    private static func tunedLoopAnchorMeters(center: CLLocationCoordinate2D, targetKm: Double) async -> Double {
        var m = loopGeodesicAnchorMeters(forTargetKm: targetKm)
        let dest = offset(from: center, distanceMeters: m, bearingDegrees: 0)
        guard let outPair = await loopOutboundOptions(center: center, dest: dest).first,
              let backPair = await loopReturnRoute(dest: dest, center: center) else {
            return m
        }
        let total = outPair.route.distance + backPair.route.distance
        let goal = targetKm * 1000
        if total > 50, goal > 50 {
            m *= min(max(goal * 1.04 / total, 0.5), 1.55)
        }
        return min(max(m, 400), 18_000)
    }

    private static func loopOutboundOptions(
        center: CLLocationCoordinate2D,
        dest: CLLocationCoordinate2D
    ) async -> [(route: MKRoute, kind: RouteCardModel.RouteTransportKind)] {
        let cycling = await calculateRoutesSafe(
            from: center,
            to: dest,
            transport: .cycling,
            requestsAlternateRoutes: true
        )
        if !cycling.isEmpty {
            return Array(cycling.prefix(2)).map { ($0, .cycling) }
        }
        let cars = await calculateRoutesSafe(
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
        if let r = await calculateRoutesSafe(
            from: dest,
            to: center,
            transport: .cycling,
            requestsAlternateRoutes: false
        ).first {
            return (r, .cycling)
        }
        if let r = await calculateRoutesSafe(
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

        let crowRound = max(straightLineMeters(from: center, to: dest) * 2, 1)
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
            hint = legRoadCharacterHint(
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
            + bikeEtaFootnote()
    }

    
    private static func mergeCoordinatesJoiningNearby(
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

    private static func loopVersusTargetAppendix(routeMeters: CLLocationDistance, targetKm: Double) -> String {
        let goal = targetKm * 1000
        let delta = routeMeters - goal
        let t = String(format: "%.1f", targetKm)
        if abs(delta) < loopVersusTargetCloseMeters {
            return String(localized: "Round trip is close to your ~\(t) km target.")
        }
        if delta >= loopVersusTargetCloseMeters {
            let d = formatDistance(meters: delta)
            return String(localized: "About \(d) longer than your ~\(t) km target.")
        }
        let d = formatDistance(meters: -delta)
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

    private static func routesForLoop(
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
            let dest = offset(from: center, distanceMeters: anchor, bearingDegrees: bearing)
            let outs = await loopOutboundOptions(center: center, dest: dest)
            guard let back = await loopReturnRoute(dest: dest, center: center) else { continue }
            for out in outs {
                let outCoords = coordinates(from: out.route.polyline)
                let inCoords = coordinates(from: back.route.polyline)
                guard !outCoords.isEmpty, !inCoords.isEmpty else { continue }

                let merged = mergeCoordinatesJoiningNearby(outCoords, inCoords)
                guard merged.count > 2 else { continue }

                let totalDist = out.route.distance + back.route.distance
                let bothCycling = out.kind == .cycling && back.kind == .cycling
                if bothCycling { sawPureCycling = true }

                let duration: TimeInterval = bothCycling
                    ? (out.route.expectedTravelTime + back.route.expectedTravelTime)
                    : estimatedCyclingDuration(distanceMeters: totalDist)

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

                let m = routeDetailMetrics(
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
                        distanceLabel: formatDistance(meters: totalDist),
                        timeLabel: formatDuration(duration),
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
            let dest0 = offset(from: center, distanceMeters: anchor, bearingDegrees: bearings[0])
            if let outCar = await calculateRoutesSafe(
                from: center,
                to: dest0,
                transport: .automobile,
                requestsAlternateRoutes: false
            ).first,
                let inCar = await calculateRoutesSafe(
                    from: dest0,
                    to: center,
                    transport: .automobile,
                    requestsAlternateRoutes: false
                ).first {
                let outC = coordinates(from: outCar.polyline)
                let inC = coordinates(from: inCar.polyline)
                if !outC.isEmpty, !inC.isEmpty {
                    let merged = mergeCoordinatesJoiningNearby(outC, inC)
                    let totalCar = outCar.distance + inCar.distance
                    if totalCar <= targetMeters + maxMetersOverPreferredRouteLength {
                        let durCar = outCar.expectedTravelTime + inCar.expectedTravelTime
                        let baseCarSubtitle = String(localized: "Same loop shape — car clock from Apple Maps (not bike time).")
                        let subtitleCar = baseCarSubtitle + "\n\n" + loopVersusTargetAppendix(routeMeters: totalCar, targetKm: targetKm)
                        let m = routeDetailMetrics(
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
                                distanceLabel: formatDistance(meters: outCar.distance + inCar.distance),
                                timeLabel: formatDuration(outCar.expectedTravelTime + inCar.expectedTravelTime),
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
        let filtered = cards.filter { $0.routeMeters <= targetMeters + maxMetersOverPreferredRouteLength }
        guard !filtered.isEmpty else { throw MapKitRouteDirectionsError.noRoutesWithinTargetLengthCap }
        return orderedRoutesWithRankStyling(markLoopRecommended(filtered, targetKm: targetKm))
    }

    

    private static func calculateRoutes(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        transport: MKDirectionsTransportType,
        requestsAlternateRoutes: Bool
    ) async throws -> [MKRoute] {
        await directionsThrottle.acquire()
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = transport
        request.requestsAlternateRoutes = requestsAlternateRoutes
        do {
            let response = try await MKDirections(request: request).calculate()
            return response.routes
        } catch {
            let ns = error as NSError
            if ns.domain == "GEOErrorDomain", ns.code == -3 {
                try await Task.sleep(for: .seconds(8))
                await directionsThrottle.acquire()
                let response = try await MKDirections(request: request).calculate()
                return response.routes
            }
            throw error
        }
    }

    
    private static func calculateRoutesSafe(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        transport: MKDirectionsTransportType,
        requestsAlternateRoutes: Bool
    ) async -> [MKRoute] {
        do {
            return try await calculateRoutes(
                from: from,
                to: to,
                transport: transport,
                requestsAlternateRoutes: requestsAlternateRoutes
            )
        } catch {
            return []
        }
    }

    

    private static func coordinates(from polyline: MKPolyline) -> [CLLocationCoordinate2D] {
        let n = polyline.pointCount
        guard n > 0 else { return [] }
        var buffer = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: n)
        polyline.getCoordinates(&buffer, range: NSRange(location: 0, length: n))
        return buffer.filter { CLLocationCoordinate2DIsValid($0) }
    }

    private static func offset(
        from: CLLocationCoordinate2D,
        distanceMeters: Double,
        bearingDegrees: Double
    ) -> CLLocationCoordinate2D {
        let brng = bearingDegrees * .pi / 180
        let cosLat = cos(from.latitude * .pi / 180)
        let dLat = (distanceMeters * cos(brng)) / 111_320.0
        let dLon = (distanceMeters * sin(brng)) / max(111_320.0 * cosLat, 1_000)
        return CLLocationCoordinate2D(latitude: from.latitude + dLat, longitude: from.longitude + dLon)
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

    private static func formatDistance(meters: CLLocationDistance) -> String {
        let km = Measurement(value: meters / 1000, unit: UnitLength.kilometers)
        return distanceFormatter.string(from: km)
    }

    private static func formatDuration(_ interval: TimeInterval) -> String {
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

    private static func advisorySubtitle(for route: MKRoute, transport: MKDirectionsTransportType) -> String {
        let named = route.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !named.isEmpty {
            return named
        }
        switch transport {
        case .cycling:
            return String(localized: "Apple Maps cycling directions.")
        case .walking:
            return String(localized: "Apple Maps walking directions.")
        case .automobile:
            return String(localized: "Apple Maps driving directions.")
        default:
            return String(localized: "Apple Maps.")
        }
    }
}
