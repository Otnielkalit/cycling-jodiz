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

    private var coordCL: [CLLocationCoordinate2D] {
        config.coordinates.map(\.clLocationCoordinate2D)
    }

    var body: some View {
        
        Map(position: $cameraPosition) {
            MapPolyline(coordinates: coordCL)
                .stroke(Color.cycleAccent, style: polylineStrokeStyle)

            UserAnnotation {
                CycleLiveTrackUserAnnotation(location: locationManager.currentLocation)
            }

            activeRideAnnotations
        }
        .mapStyle(CycleMapDisplayStyle.resolved(from: mapStyleRaw).toMapStyle())
        .mapControls { MapUserLocationButton() }
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            turnInstructionPill
                .allowsHitTesting(false)
                .padding(.horizontal, 20)
                .padding(.top, 12)
        }
        .overlay(alignment: .bottom) {
            bottomHudLightDesign
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            rideStartedAt = Date()
            fitCameraToRoute()
        }
        .onChange(of: locationManager.currentLocation?.timestamp.timeIntervalSince1970 ?? 0) { _, _ in
            accumulateOdometer()
        }
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

    
    private var turnInstructionPill: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.cycleAccent.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: "arrow.turn.up.right")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.cycleAccent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "On route"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.cyclePrimaryText)
                Text(String(localized: "Follow the highlighted route"))
                    .font(.subheadline)
                    .foregroundStyle(Color.cycleSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.cycleCardSurface, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.cycleBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 6)
        .frame(maxWidth: 400)
    }

    
    private var bottomHudLightDesign: some View {
        VStack(spacing: 20) {
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
                HStack(spacing: 8) {
                    Image(systemName: "stop.circle.fill")
                    Text(String(localized: "End Ride"))
                }
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 220 / 255, green: 38 / 255, blue: 38 / 255))
        }
        .padding(20)
        .frame(maxWidth: 400)
        .background(Color.cycleCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.cycleBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
        
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
    }

    private var hudColumnDivider: some View {
        Rectangle()
            .fill(Color.cycleBorder.opacity(0.85))
            .frame(width: 1)
            .padding(.vertical, 6)
    }

    private func hudColumnDesign(label: String, value: String, unit: String, valueAccent: Bool) -> some View {
        VStack(spacing: 6) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(Color.cycleSecondaryText)
            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(valueAccent ? Color.cycleAccent : Color.cyclePrimaryText)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(unit)
                .font(.caption)
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

    private func fitCameraToRoute() {
        let coords = coordCL
        guard !coords.isEmpty else { return }
        var minLat = 90.0, maxLat = -90.0, minLon = 180.0, maxLon = -180.0
        for c in coords {
            minLat = min(minLat, c.latitude)
            maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude)
            maxLon = max(maxLon, c.longitude)
        }
        let mid = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let dLat = max((maxLat - minLat) * 1.35, 0.004)
        let dLon = max((maxLon - minLon) * 1.35, 0.004)
        cameraPosition = .region(MKCoordinateRegion(center: mid, span: MKCoordinateSpan(latitudeDelta: dLat, longitudeDelta: dLon)))
    }

    private func endRide() {
        let ended = Date()
        let payload = RideSummaryPayload(
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
