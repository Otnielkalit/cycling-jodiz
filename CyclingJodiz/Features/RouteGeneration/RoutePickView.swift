//
//  RoutePickView.swift
//  CyclingJodiz
//

import MapKit
import SwiftUI

struct RoutePickView: View {
    @Binding var path: NavigationPath

    let context: RoutePickContext

    @AppStorage(CycleMapDisplayStyle.storageKey) private var mapStyleRaw: String = CycleMapDisplayStyle.standard.rawValue
    @State private var routes: [RouteCardModel] = []
    @State private var selectedIndex: Int = 0
    @State private var cameraPosition: MapCameraPosition
    @State private var isLoading = true
    @State private var loadError: String?

    init(path: Binding<NavigationPath>, context: RoutePickContext) {
        _path = path
        self.context = context
        _cameraPosition = State(initialValue: .region(Self.initialRegion(for: context)))
    }

    var body: some View {
        VStack(spacing: 0) {
            mapSection
                .frame(maxHeight: 260)

            if let loadError {
                Text(loadError)
                    .font(.footnote)
                    .foregroundStyle(Color.cycleSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
            }

            ScrollView {
                VStack(spacing: 12) {
                    if routes.isEmpty, !isLoading {
                        Text(String(localized: "No routes to show."))
                            .font(.subheadline)
                            .foregroundStyle(Color.cycleSecondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                    } else {
                        ForEach(Array(routes.enumerated()), id: \.element.id) { index, route in
                            routeCard(route: route, index: index)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 12)
            }
            .background(Color.cycleCanvasBackground)
        }
        .background(Color.cycleCanvasBackground)
        .navigationTitle(String(localized: "Choose route"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                CycleMapStylePickerMenu()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                startRideTapped()
            } label: {
                Label(String(localized: "Start ride"), systemImage: "arrow.right")
                    .font(.subheadline.weight(.semibold))
                    .labelStyle(.titleAndIcon)
                    .imageScale(.small)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(Color.cycleAccent)
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 5)
            .background(.ultraThinMaterial)
        }
        .toolbar(.hidden, for: .tabBar)
        .task(id: context) {
            await loadRoutes()
        }
    }

    private var mapSection: some View {
        ZStack {
            Map(position: $cameraPosition) {
                ForEach(Array(routes.enumerated()), id: \.element.id) { index, route in
                    MapPolyline(coordinates: route.coordinates)
                        .stroke(
                            route.lineColor.opacity(index == selectedIndex ? 1 : 0.35),
                            style: routePolylineStrokeStyle(selected: index == selectedIndex)
                        )
                }
                mapAnnotations
            }
            .mapStyle(CycleMapDisplayStyle.resolved(from: mapStyleRaw).toMapStyle())

            if isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                    Text(String(localized: "Loading routes…"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.cycleSecondaryText)
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    @MapContentBuilder
    private var mapAnnotations: some MapContent {
        switch context {
        case .pointToPoint(let start, let end, _):
            let s = start.clLocationCoordinate2D
            let e = end.clLocationCoordinate2D
            Annotation(String(localized: "Start"), coordinate: s) {
                routePin(color: Color.cycleSuccess)
            }
            Annotation(String(localized: "End"), coordinate: e) {
                routePin(color: Color.cycleAccent)
            }
        case .loop(let center, _):
            let c = center.clLocationCoordinate2D
            Annotation(String(localized: "Loop start"), coordinate: c) {
                routePin(color: Color.cycleAccent)
            }
        }
    }

    private func routePin(color: Color) -> some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 14, height: 14)
            Circle()
                .strokeBorder(color, lineWidth: 3)
                .frame(width: 14, height: 14)
        }
    }

    private func routePolylineStrokeStyle(selected: Bool) -> StrokeStyle {
        let width: CGFloat = selected ? 5 : 3
        return StrokeStyle(lineWidth: width)
    }

    private func routeCard(route: RouteCardModel, index: Int) -> some View {
        let selected = index == selectedIndex
        return Button {
            selectedIndex = index
        } label: {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(route.lineColor.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: routeIconName(for: route.transportKind))
                        .font(.title3)
                        .foregroundStyle(route.lineColor)
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(route.title)
                            .font(.headline)
                            .foregroundStyle(Color.cyclePrimaryText)
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(route.distanceLabel)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.cycleSecondaryText)
                            Text(route.timeLabel)
                                .font(.headline)
                                .foregroundStyle(selected ? route.lineColor : Color.cyclePrimaryText)
                        }
                    }
                    HStack(spacing: 8) {
                        if route.isRecommended {
                            Text(String(localized: "Recommended"))
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.cycleSuccess.opacity(0.15))
                                .foregroundStyle(Color.cycleSuccess)
                                .clipShape(Capsule())
                        }
                        if route.transportKind == .walking {
                            Text(String(localized: "Walking path"))
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.cycleAccent.opacity(0.12))
                                .foregroundStyle(Color.cycleAccent)
                                .clipShape(Capsule())
                        }
                        if route.transportKind == .cycling {
                            Text(String(localized: "Maps cycling"))
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.cycleSuccess.opacity(0.12))
                                .foregroundStyle(Color.cycleSuccess)
                                .clipShape(Capsule())
                        }
                        if route.transportKind == .cyclingRoadEstimate {
                            Text(String(localized: "Roads · bike ETA"))
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.cycleAccent.opacity(0.12))
                                .foregroundStyle(Color.cycleAccent)
                                .clipShape(Capsule())
                        }
                        if route.transportKind == .automobile {
                            Text(String(localized: "Driving"))
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.cycleAccent.opacity(0.12))
                                .foregroundStyle(Color.cycleAccent)
                                .clipShape(Capsule())
                        }
                    }
                    Text(route.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.cycleSecondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
            .background(Color.cycleCardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        selected ? route.lineColor : Color.cycleBorder.opacity(0.55),
                        lineWidth: selected ? 2 : 1
                    )
            )
            .shadow(color: .black.opacity(selected ? 0.08 : 0.04), radius: selected ? 10 : 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func routeIconName(for kind: RouteCardModel.RouteTransportKind) -> String {
        switch kind {
        case .cycling, .cyclingRoadEstimate:
            return "bicycle"
        case .walking:
            return "figure.walk"
        case .automobile:
            return "car.fill"
        }
    }

    private func startRideTapped() {
        guard !routes.isEmpty, routes.indices.contains(selectedIndex) else { return }
        let route = routes[selectedIndex]
        let config = ActiveRideConfig.from(route: route, pickContext: context)
        path.append(RouteFlow.activeRide(config))
    }

    private func loadRoutes() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            let built = try await MapKitRouteDirectionsBuilder.buildRouteCards(context: context)
            routes = built
            selectedIndex = 0
            if let firstRecommended = built.firstIndex(where: { $0.isRecommended }) {
                selectedIndex = firstRecommended
            }
            fitMap(to: built)
        } catch {
            loadError = error.localizedDescription
            routes = []
        }
    }

    private func fitMap(to routes: [RouteCardModel]) {
        let all = routes.flatMap(\.coordinates)
        guard !all.isEmpty else { return }
        var minLat = 90.0
        var maxLat = -90.0
        var minLon = 180.0
        var maxLon = -180.0
        for c in all {
            minLat = min(minLat, c.latitude)
            maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude)
            maxLon = max(maxLon, c.longitude)
        }
        let mid = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let dLat = max((maxLat - minLat) * 1.45, 0.006)
        let dLon = max((maxLon - minLon) * 1.45, 0.006)
        cameraPosition = .region(
            MKCoordinateRegion(center: mid, span: MKCoordinateSpan(latitudeDelta: dLat, longitudeDelta: dLon))
        )
    }

    private static func initialRegion(for context: RoutePickContext) -> MKCoordinateRegion {
        switch context {
        case .pointToPoint(let start, let end, _):
            let s = start.clLocationCoordinate2D
            let e = end.clLocationCoordinate2D
            let mid = CLLocationCoordinate2D(latitude: (s.latitude + e.latitude) / 2, longitude: (s.longitude + e.longitude) / 2)
            let dLat = max(abs(s.latitude - e.latitude) * 2.2, 0.02)
            let dLon = max(abs(s.longitude - e.longitude) * 2.2, 0.02)
            return MKCoordinateRegion(center: mid, span: MKCoordinateSpan(latitudeDelta: dLat, longitudeDelta: dLon))
        case .loop(let center, _):
            return MKCoordinateRegion(
                center: center.clLocationCoordinate2D,
                span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
            )
        }
    }
}

#Preview {
    NavigationStack {
        RoutePickView(
            path: .constant(NavigationPath()),
            context: .pointToPoint(
                start: MapCoordinate(CLLocationCoordinate2D(latitude: -7.29, longitude: 112.75)),
                end: MapCoordinate(CLLocationCoordinate2D(latitude: -7.31, longitude: 112.78)),
                preferredLengthKm: 20
            )
        )
    }
}
