//
//  HomeView.swift
//  CyclingJodiz
//
//  Created by otnielkalit on 11/06/26.
//

import CoreLocation
import MapKit
import SwiftUI
import WeatherKit

struct HomeView: View {
    private static let defaultMapCenter = CLLocationCoordinate2D(latitude: -6.2, longitude: 106.82)

    @State private var path = NavigationPath()
    @State private var locationManager = LocationManager()
    @State private var weatherViewModel = HomeWeatherViewModel()
    @State private var savedPlans: [SavedRoutePlan] = []
    @State private var lastActivity: RideSummaryPayload? = nil
    var body: some View {
        NavigationStack(path: $path) {
            homeScrollView
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .navigationDestination(for: RouteFlow.self) { step in
                    switch step {
                    case .hub:
                        RouteSearchHubView(path: $path, locationManager: locationManager)
                    case .pick(let context):
                        RoutePickView(path: $path, context: context)
                    case .activeRide(let config):
                        ActiveRideView(path: $path, config: config, locationManager: locationManager)
                    case .rideSummary(let payload):
                        RideSummaryView(path: $path, payload: payload)
                    }
                }
        }
        .tint(Color.cycleAccent)
        .onAppear {
            locationManager.requestWhenInUseAuthorization()
            locationManager.startUpdatingLocation()
            weatherViewModel.refresh(for: locationManager.currentLocation)
            loadPersistedData()
        }
        .onChange(of: locationManager.currentLocation) { _, newValue in
            weatherViewModel.refresh(for: newValue)
        }
        .onChange(of: path) { _, _ in
            loadPersistedData()
        }
    }

    private func loadPersistedData() {
        savedPlans = SavedRoutePlansPersistence.load()
        lastActivity = ActivityPersistence.loadLast()
    }

    @ViewBuilder
    private var homeScrollView: some View {
        ScrollView {
            homeMainColumn
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 28)
        }
        .scrollContentBackground(.hidden)
        .background(Color.cycleCanvasBackground)
    }

    @ViewBuilder
    private var homeMainColumn: some View {
        VStack(alignment: .leading, spacing: 22) {
            homeGreetingSection
            HomePrimaryGenerateRouteCard {
                path.append(RouteFlow.hub)
            }
            homeUpNextHeader
            HomePlannedRouteCard(
                plan: savedPlans.first,
                locationManager: locationManager,
                onStartRide: {
                    if let firstPlan = savedPlans.first {
                        path.append(RouteFlow.activeRide(firstPlan.config))
                    } else {
                        path.append(RouteFlow.activeRide(.demoRidgeLoop()))
                    }
                }
            )
            homeLastRideHeader
            HomeLastRideStatsRow(lastActivity: lastActivity)
        }
    }

    @ViewBuilder
    private var homeGreetingSection: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            HomeHeaderGreetingRow(
                periodLabel: greetingPeriodLabel(at: context.date),
                headline: greetingHeadline(at: context.date),
                weatherViewModel: weatherViewModel
            )
        }
    }

    private var homeUpNextHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(String(localized: "Up Next"))
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.cyclePrimaryText)
            Spacer()
            Button(String(localized: "See All")) {
                
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.cycleAccent)
        }
    }

    private var homeLastRideHeader: some View {
        Text(String(localized: "Last Ride"))
            .font(.headline.weight(.bold))
            .foregroundStyle(Color.cyclePrimaryText)
    }

    private func greetingPeriodLabel(at date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5 ..< 12:
            return String(localized: "Good morning")
        case 12 ..< 17:
            return String(localized: "Good afternoon")
        case 17 ..< 22:
            return String(localized: "Good evening")
        default:
            return String(localized: "Good night")
        }
    }

    private func greetingHeadline(at _: Date) -> String {
        String(localized: "Hey, ready to ride?")
    }
}

private struct HomeHeaderGreetingRow: View {
    let periodLabel: String
    let headline: String
    let weatherViewModel: HomeWeatherViewModel

    private var cheerEnglish: String {
        WeatherHomeCheerEnglish.line(
            isLoading: weatherViewModel.isLoading,
            symbolName: weatherViewModel.symbolName,
            condition: weatherViewModel.weatherCondition
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    
                    Text(periodLabel)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.cycleSecondaryText)

                    
                    Text(headline)
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.cyclePrimaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HomeWeatherHeaderCompact(viewModel: weatherViewModel)
                    .padding(.top, 2)
            }

            Text(verbatim: cheerEnglish)
                .font(.subheadline)
                .fontWeight(.regular)
                .foregroundStyle(Color.cycleSecondaryText)
                .multilineTextAlignment(.leading)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HomeWeatherHeaderCompact: View {
    let viewModel: HomeWeatherViewModel

    var body: some View {
        HStack(spacing: 8) {
            WeatherHeaderIconOrb(
                symbolName: viewModel.symbolName,
                condition: viewModel.weatherCondition,
                isLoading: viewModel.isLoading,
                diameter: 52,
                animated: false
            )

            Text(viewModel.temperatureText)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(viewModel.palette.temperatureTint)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
                .contentTransition(.numericText())
        }
        .padding(.leading, 6)
        .padding(.trailing, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(Color.cycleBorder.opacity(0.22))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.cycleBorder.opacity(0.45), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "Weather") + ", " + viewModel.temperatureText
        )
    }
}

private struct HomePrimaryGenerateRouteCard: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.cycleAccent.opacity(0.14))
                            .frame(width: 48, height: 48)
                        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath.fill")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color.cycleAccent)
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "Plan Your Journey"))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.cyclePrimaryText)
                            .multilineTextAlignment(.leading)
                        Text(
                            String(
                                localized: "Loop or A to B—pick style, place, and distance. Let the app generate the perfect route for your cycling performance."
                            )
                        )
                        .font(.subheadline)
                        .foregroundStyle(Color.cycleSecondaryText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack {
                    Text(String(localized: "Generate Route"))
                        .font(.headline.weight(.semibold))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(Color.cycleAccent)
                .clipShape(Capsule())
            }
            .padding(20)
            .background(Color.cycleCardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.cycleBorder.opacity(0.45), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.07), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Generate Route"))
        .accessibilityHint(String(localized: "Opens route planning."))
    }
}

private struct HomePlannedRouteCard: View {
    let plan: SavedRoutePlan?
    var locationManager: LocationManager
    var onStartRide: () -> Void

    private var titleText: String {
        plan?.config.routeTitle ?? String(localized: "Ridge Loop")
    }

    private var distanceText: String {
        if let plan {
            return String(format: "%.1f km", plan.config.totalRouteMeters / 1000)
        }
        return String(localized: "24 km")
    }

    private var durationText: String {
        if let plan {
            let seconds = plan.config.totalRouteMeters / 5.0
            let minutes = max(1, Int(seconds / 60))
            return "\(minutes) min"
        }
        return String(localized: "55 min")
    }

    private var coordinates: [CLLocationCoordinate2D] {
        if let plan {
            return plan.config.coordinates.map(\.clLocationCoordinate2D)
        }
        return [
            CLLocationCoordinate2D(latitude: -6.198, longitude: 106.805),
            CLLocationCoordinate2D(latitude: -6.208, longitude: 106.818),
            CLLocationCoordinate2D(latitude: -6.218, longitude: 106.808),
            CLLocationCoordinate2D(latitude: -6.210, longitude: 106.798)
        ]
    }

    private var initialCameraPosition: MapCameraPosition {
        let coords = coordinates
        guard !coords.isEmpty else { return .userLocation(fallback: .automatic) }
        var minLat = 90.0, maxLat = -90.0, minLon = 180.0, maxLon = -180.0
        for c in coords {
            minLat = min(minLat, c.latitude)
            maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude)
            maxLon = max(maxLon, c.longitude)
        }
        let mid = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let dLat = max((maxLat - minLat) * 1.5, 0.015)
        let dLon = max((maxLon - minLon) * 1.5, 0.015)
        return .region(MKCoordinateRegion(center: mid, span: MKCoordinateSpan(latitudeDelta: dLat, longitudeDelta: dLon)))
    }

    private static let mapPreviewHeight: CGFloat = 156

    @AppStorage(CycleMapDisplayStyle.storageKey) private var mapStyleRaw: String = CycleMapDisplayStyle.standard.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                Map(initialPosition: initialCameraPosition) {
                    UserAnnotation {
                        CycleLiveTrackUserAnnotation(location: locationManager.currentLocation)
                    }
                    MapPolyline(coordinates: coordinates)
                        .stroke(Color(red: 0.2, green: 0.55, blue: 1.0), lineWidth: 4)
                }
                .mapStyle(CycleMapDisplayStyle.resolved(from: mapStyleRaw).toMapStyle())
                .frame(height: Self.mapPreviewHeight)
                .allowsHitTesting(false)
                .environment(\.colorScheme, .dark)

                Text(plan == nil ? String(localized: "VERIFIED ROUTE") : String(localized: "PLANNED RIDE"))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.cycleAccent)
                    .clipShape(Capsule())
                    .padding(.leading, 12)
                    .padding(.top, 10)
            }
            .allowsHitTesting(false)

            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(titleText)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.cyclePrimaryText)

                    HStack(spacing: 18) {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.and.ellipse")
                                .imageScale(.small)
                            Text(distanceText)
                        }
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                            Text(durationText)
                        }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.cycleSecondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onStartRide) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.cyclePrimaryText)
                        .frame(width: 50, height: 50)
                        .background(Color.cycleBorder.opacity(0.85))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Start ride"))
            }
            .padding(16)
            .background(Color.cycleCardSurface)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.cycleBorder.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

private struct HomeLastRideStatsRow: View {
    let lastActivity: RideSummaryPayload?

    var body: some View {
        HStack(spacing: 12) {
            if let lastActivity {
                HomeStatMiniCard(
                    title: String(localized: "AVG SPEED"),
                    valuePrimary: String(format: "%.1f", lastActivity.avgSpeedKmh),
                    valueSuffix: String(localized: " km/h"),
                    accentPrimary: true
                )
                HomeStatMiniCard(
                    title: String(localized: "TIME"),
                    valuePrimary: String(format: "%d", max(1, Int(lastActivity.totalSeconds / 60))),
                    valueSuffix: String(localized: " min"),
                    accentPrimary: false
                )
            } else {
                HomeStatMiniCard(
                    title: String(localized: "AVG SPEED"),
                    valuePrimary: "—",
                    valueSuffix: String(localized: " km/h"),
                    accentPrimary: true
                )
                HomeStatMiniCard(
                    title: String(localized: "TIME"),
                    valuePrimary: "—",
                    valueSuffix: String(localized: " min"),
                    accentPrimary: false
                )
            }
        }
    }
}

private struct HomeStatMiniCard: View {
    let title: String
    let valuePrimary: String
    let valueSuffix: String
    var accentPrimary: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.cycleSecondaryText)
                .textCase(.uppercase)
                .tracking(0.4)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(valuePrimary)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(accentPrimary ? Color.cycleAccent : Color.cyclePrimaryText)
                Text(valueSuffix)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.cyclePrimaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.cycleBorder.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.cycleBorder.opacity(0.4), lineWidth: 1)
        )
    }
}

#Preview {
    HomeView()
}
