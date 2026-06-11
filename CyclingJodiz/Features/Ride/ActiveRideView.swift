//
//  ActiveRideView.swift
//  CyclingJodiz
//
//  Created by otnielkalit on 11/06/26.
//

import CoreLocation
import MapKit
import Observation
import SwiftUI

struct ActiveRideView: View {
    @Binding var path: NavigationPath
    let config: ActiveRideConfig
    @Bindable var locationManager: LocationManager

    @AppStorage(CycleMapDisplayStyle.storageKey) private var mapStyleRaw: String = CycleMapDisplayStyle.standard.rawValue

    @State private var rideStartedAt = Date()
    @State private var odometerMeters: Double = 0
    @State private var lastOdometerLocation: CLLocation?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var didApplyFollowCameraAfterFirstFix = false
    @State private var showRideStatsCard = false
    /// When the map style supports pitch, this toggles between follow-with-heading (flat) and an explicit pitched `MapCamera` on the rider.
    @State private var rideViewUsesPitchedCamera = true
    @State private var lastPitchedFollowCameraAt = Date.distantPast
    @Namespace private var rideMapScope

    private var rideMapStyle: CycleMapDisplayStyle {
        CycleMapDisplayStyle.resolved(from: mapStyleRaw)
    }

    private let rideHudBottomInsetExpanded: CGFloat = 178
    private let rideHudBottomInsetCollapsed: CGFloat = 28

    private var coordCL: [CLLocationCoordinate2D] {
        config.coordinates.map(\.clLocationCoordinate2D)
    }

    var body: some View {
        
        Map(position: $cameraPosition, scope: rideMapScope) {
            MapPolyline(coordinates: coordCL)
                .stroke(Color.cycleAccent, style: polylineStrokeStyle)

            UserAnnotation {
                CycleLiveTrackUserAnnotation(location: locationManager.currentLocation, markerSize: 36)
                    // Nudge artwork slightly below the GPS anchor so the puck clears the top instruction card.
                    .offset(y: 14)
            }

            activeRideAnnotations
        }
        .mapStyle(rideMapStyle.toMapStyle())
        // Suppress MapKit’s automatic top-trailing compass / scale / pitch chrome; we place `MapCompass(scope:)` in the overlay stack.
        .mapControlVisibility(.hidden)
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            turnInstructionPill
                .allowsHitTesting(false)
                .padding(.horizontal, 16)
                .padding(.top, 6)
        }
        .overlay(alignment: .trailing) {
            VStack {
                Spacer()
                rideRightMapControlsStack
                Spacer()
            }
            .padding(.trailing, 12)
            // Re-enable scoped map controls only in this stack (middle trailing).
            .mapControlVisibility(.visible)
        }
        .overlay(alignment: .bottom) {
            if showRideStatsCard {
                bottomHudLightDesign
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottomTrailing) {
            rideTrailingControlStack
                .padding(.trailing, 14)
                .padding(.bottom, showRideStatsCard ? rideHudBottomInsetExpanded : rideHudBottomInsetCollapsed)
        }
        .animation(.easeInOut(duration: 0.28), value: showRideStatsCard)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            rideStartedAt = Date()
            applyRideStartCamera()
            if locationManager.currentLocation != nil {
                didApplyFollowCameraAfterFirstFix = true
            }
            WatchSessionManager.shared.sendRideData([
                "isRideActive": true,
                "speed": 0.0,
                "distanceRemaining": config.totalRouteMeters / 1000.0,
                "elapsedTime": "00:00",
                "nextTurn": "Follow the route"
            ])
        }
        .onChange(of: mapStyleRaw) { _, newRaw in
            let style = CycleMapDisplayStyle.resolved(from: newRaw)
            if style.prefersPitchedMapCamera {
                rideViewUsesPitchedCamera = true
            }
            applyRideStartCamera()
        }
        .onChange(of: locationManager.currentLocation?.timestamp.timeIntervalSince1970 ?? 0) { _, _ in
            accumulateOdometer()
            if !didApplyFollowCameraAfterFirstFix, locationManager.currentLocation != nil {
                didApplyFollowCameraAfterFirstFix = true
                applyRideStartCamera()
            } else if rideMapStyle.prefersPitchedMapCamera, rideViewUsesPitchedCamera {
                maybeRefreshPitchedFollowCamera()
            }
            
            let remaining = max(0, config.totalRouteMeters - odometerMeters)
            let elapsedSec = Date().timeIntervalSince(rideStartedAt)
            let m = Int(elapsedSec) / 60
            let s = Int(elapsedSec) % 60
            let formattedTime = String(format: "%02d:%02d", m, s)
            
            WatchSessionManager.shared.sendRideData([
                "speed": currentSpeedKmh,
                "distanceRemaining": remaining / 1000.0,
                "elapsedTime": formattedTime,
                "isRideActive": true,
                "nextTurn": "Follow the route"
            ])
        }
        .mapScope(rideMapScope)
    }

    private var polylineStrokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: 5)
    }

    @MapContentBuilder
    private var activeRideAnnotations: some MapContent {
        switch config.pickContext {
        case .pointToPoint(let start, let end, _):
            let s = start.clLocationCoordinate2D
            let e = end.clLocationCoordinate2D
            Annotation(String(localized: "Start"), coordinate: s) {
                ridePin(color: Color.cycleSuccess)
            }
            Annotation(String(localized: "End"), coordinate: e) {
                ridePin(color: Color.cycleAccent)
            }
        case .loop(let center, _):
            let c = center.clLocationCoordinate2D
            Annotation(String(localized: "Loop start"), coordinate: c) {
                ridePin(color: Color.cycleAccent)
            }
        }
    }

    private func ridePin(color: Color) -> some View {
        ZStack {
            Circle().fill(Color.white).frame(width: 12, height: 12)
            Circle().strokeBorder(color, lineWidth: 2).frame(width: 12, height: 12)
        }
    }

    
    /// System map compass, optional 2D/3D, and map type stacked on the middle trailing edge.
    private var rideRightMapControlsStack: some View {
        VStack(spacing: 10) {
            MapCompass(scope: rideMapScope)
            if rideMapStyle.prefersPitchedMapCamera {
                ridePitchToggleButton
            }
            CycleMapStylePickerMenu(lightContent: true, prominent: true)
        }
    }

    private var ridePitchToggleButton: some View {
        Button {
            rideViewUsesPitchedCamera.toggle()
            applyRideStartCamera()
        } label: {
            Text(rideViewUsesPitchedCamera ? "2D" : "3D")
                .font(.caption.weight(.heavy))
                .foregroundStyle(Color.cycleAccent)
                .frame(width: 44, height: 44)
                .background {
                    ZStack {
                        Circle().fill(.ultraThinMaterial)
                        Circle().fill(Color.black.opacity(0.32))
                    }
                }
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
                .shadow(color: .black.opacity(0.22), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            rideViewUsesPitchedCamera
                ? String(localized: "Switch to flat map view")
                : String(localized: "Switch to tilted map view")
        )
    }

    private var rideTrailingControlStack: some View {
        VStack(spacing: 10) {
            rideCenterOnUserFloatingButton
            if !showRideStatsCard {
                rideShowStatsFloatingButton
            }
        }
    }

    /// Single control to snap the camera back onto the rider (same as the old pan-only recenter).
    private var rideCenterOnUserFloatingButton: some View {
        Button {
            applyRideStartCamera()
        } label: {
            Image(systemName: "location.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.cyclePrimaryText)
                .frame(width: 48, height: 48)
                .background(Color.cycleCardSurface, in: Circle())
                .overlay(Circle().strokeBorder(Color.cycleBorder, lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Center map on your location"))
    }

    private var rideShowStatsFloatingButton: some View {
        Button {
            showRideStatsCard = true
        } label: {
            Image(systemName: "speedometer")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.cyclePrimaryText)
                .frame(width: 48, height: 48)
                .background(Color.cycleCardSurface, in: Circle())
                .overlay(Circle().strokeBorder(Color.cycleBorder, lineWidth: 1))
                .shadow(color: .black.opacity(0.14), radius: 9, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Show ride stats"))
    }

    private var turnInstructionPill: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.cycleAccent.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: "arrow.turn.up.right")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.cycleAccent)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(String(localized: "On route"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.cyclePrimaryText)
                Text(String(localized: "Follow the highlighted route"))
                    .font(.caption2)
                    .foregroundStyle(Color.cycleSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.cycleCardSurface, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.cycleBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        .frame(maxWidth: 300)
    }

    
    private var bottomHudLightDesign: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 12) {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    HStack(spacing: 0) {
                        hudColumnDesign(
                            label: String(localized: "Speed"),
                            value: speedText,
                            unit: String(localized: "km/h"),
                            valueAccent: false
                        )
                        hudColumnDivider
                        hudColumnDesign(
                            label: String(localized: "Remaining"),
                            value: remainingKmText,
                            unit: String(localized: "km"),
                            valueAccent: false
                        )
                        hudColumnDivider
                        hudColumnDesign(
                            label: String(localized: "Elapsed"),
                            value: elapsedText(at: timeline.date),
                            unit: String(localized: "min:sec"),
                            valueAccent: true
                        )
                    }
                }

                Button(role: .destructive) {
                    endRide()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.circle.fill")
                        Text(String(localized: "End Ride"))
                    }
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 220 / 255, green: 38 / 255, blue: 38 / 255))
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 12)
            .frame(maxWidth: 360)

            Button {
                showRideStatsCard = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.cycleSecondaryText)
                    .frame(width: 30, height: 30)
                    .background(Color.cycleBorder.opacity(0.28), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            .padding(.trailing, 8)
            .accessibilityLabel(String(localized: "Close ride stats"))
        }
        .background(Color.cycleCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.cycleBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
    }

    private var hudColumnDivider: some View {
        Rectangle()
            .fill(Color.cycleBorder.opacity(0.85))
            .frame(width: 1)
            .padding(.vertical, 4)
    }

    private func hudColumnDesign(label: String, value: String, unit: String, valueAccent: Bool) -> some View {
        VStack(spacing: 3) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.45)
                .foregroundStyle(Color.cycleSecondaryText)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(valueAccent ? Color.cycleAccent : Color.cyclePrimaryText)
                .minimumScaleFactor(0.65)
                .lineLimit(1)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(Color.cycleSecondaryText)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private var speedText: String {
        let kmh = currentSpeedKmh
        return String(format: "%.1f", kmh)
    }

    private var currentSpeedKmh: Double {
        if let loc = locationManager.currentLocation, loc.speed >= 0, loc.speed.isFinite {
            return loc.speed * 3.6
        }
        return 0
    }

    private var remainingKmText: String {
        let remaining = max(0, config.totalRouteMeters - odometerMeters)
        return String(format: "%.1f", remaining / 1000)
    }

    private func elapsedText(at now: Date) -> String {
        let sec = now.timeIntervalSince(rideStartedAt)
        let m = Int(sec) / 60
        let s = Int(sec) % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func accumulateOdometer() {
        guard let loc = locationManager.currentLocation else { return }
        if let prev = lastOdometerLocation {
            odometerMeters += loc.distance(from: prev)
        }
        lastOdometerLocation = loc
    }

    /// Tight region around the route start (or route center) when GPS is not ready yet.
    private func compactRouteFallbackRegion() -> MKCoordinateRegion {
        let coords = coordCL
        guard let first = coords.first else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -6.2, longitude: 106.82),
                span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
            )
        }
        if coords.count == 1 {
            return MKCoordinateRegion(center: first, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        }
        let lookAhead = min(coords.count - 1, max(12, coords.count / 24))
        let anchor = coords[lookAhead]
        let mid = CLLocationCoordinate2D(
            latitude: (first.latitude + anchor.latitude) * 0.5,
            longitude: (first.longitude + anchor.longitude) * 0.5
        )
        let spanLat = max(abs(first.latitude - anchor.latitude) * 2.2, 0.006)
        let spanLon = max(abs(first.longitude - anchor.longitude) * 2.2, 0.006)
        return MKCoordinateRegion(center: mid, span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon))
    }

    /// Like Google Maps navigation start: follow the rider with heading; before GPS, show route entry.
    private func applyRideStartCamera() {
        let fallback = compactRouteFallbackRegion()
        guard let loc = locationManager.currentLocation else {
            let style = CycleMapDisplayStyle.resolved(from: mapStyleRaw)
            cameraPosition = CycleMapCameraFraming.position(region: fallback, displayStyle: style)
            return
        }
        if rideMapStyle.prefersPitchedMapCamera, rideViewUsesPitchedCamera {
            applyPitchedFollowCamera(at: loc)
        } else {
            cameraPosition = .userLocation(followsHeading: true, fallback: .region(fallback))
        }
    }

    private func applyPitchedFollowCamera(at location: CLLocation) {
        let coord = location.coordinate
        let course = location.course
        let heading: Double
        if course >= 0, course <= 360 {
            heading = course
        } else {
            heading = 0
        }
        let span = MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
        let latRad = coord.latitude * .pi / 180
        let metersPerDegLat = 111_320.0
        let metersPerDegLon = max(cos(latRad) * 111_320.0, 1.0)
        let visibleNorthSouth = span.latitudeDelta * metersPerDegLat
        let visibleEastWest = span.longitudeDelta * metersPerDegLon
        let footprint = max(visibleNorthSouth, visibleEastWest)
        let pitch = 52.0
        let pitchRad = pitch * .pi / 180
        let distance = min(max(footprint / (1.85 * max(cos(pitchRad), 0.18)), 420), 25_000)
        let cam = MapCamera(centerCoordinate: coord, distance: distance, heading: heading, pitch: pitch)
        cameraPosition = .camera(cam)
    }

    private func maybeRefreshPitchedFollowCamera() {
        let now = Date()
        guard now.timeIntervalSince(lastPitchedFollowCameraAt) >= 0.75 else { return }
        lastPitchedFollowCameraAt = now
        guard let loc = locationManager.currentLocation else { return }
        applyPitchedFollowCamera(at: loc)
    }

    private func endRide() {
        WatchSessionManager.shared.sendRideData(["isRideActive": false])
        let ended = Date()
        let payload = RideSummaryPayload(
            id: UUID(),
            startedAt: rideStartedAt,
            endedAt: ended,
            riddenDistanceMeters: max(odometerMeters, 1),
            routeTitle: config.routeTitle,
            routeCoordinates: config.coordinates
        )
        var next = NavigationPath()
        next.append(RouteFlow.rideSummary(payload))
        path = next
    }
}
