import CoreLocation
import MapKit
import SwiftUI

struct RouteSearchHubView: View {
    @Binding var path: NavigationPath
    @Bindable var locationManager: LocationManager

    @AppStorage(CycleMapDisplayStyle.storageKey) private var mapStyleRaw: String = CycleMapDisplayStyle.standard.rawValue
    @State private var form = RouteHubFormModel()
    @State private var mapCamera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var showLoopRouteSheet = false
    @State private var showABRouteSheet = false

    private static let fallbackMapCenter = CLLocationCoordinate2D(latitude: -6.2, longitude: 106.82)

    

    
    private static let heroContentHeight: CGFloat = 258
    
    private static let cardOverlapIntoHero: CGFloat = 118
    
    private static let mapInnerHeight: CGFloat = 188
    private static let outerHorizontalPadding: CGFloat = 16
    private static let cardCornerRadius: CGFloat = 22
    private static let mapCornerRadius: CGFloat = 16

    var body: some View {
        ZStack(alignment: .top) {
            Color.cycleCanvasBackground
                .ignoresSafeArea()

            heroHeaderSection
                .frame(height: Self.heroContentHeight)
                .frame(maxWidth: .infinity)
                .clipped()
                .ignoresSafeArea(edges: .top)
                .zIndex(0)

            ScrollView {
                gojekHubCard
                    .padding(.horizontal, Self.outerHorizontalPadding)
                    .padding(.top, Self.heroContentHeight - Self.cardOverlapIntoHero)
                    .padding(.bottom, 36)
            }
            .scrollIndicators(.visible)
            .scrollContentBackground(.hidden)
            .scrollClipDisabled(true)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .zIndex(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(RouteHubNavigationBarHost())
        .navigationTitle(String(localized: "Rute baru"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                CycleMapStylePickerMenu(lightContent: true)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            syncRegionFromLocation()
        }
        .onChange(of: locationManager.currentLocation) { _, _ in
            syncRegionFromLocation()
        }
        .sheet(isPresented: $showLoopRouteSheet, onDismiss: {
            if form.scenario == .loop {
                form.clearScenario()
            }
        }) {
            RouteLoopSearchSheet(
                form: form,
                isPresented: $showLoopRouteSheet,
                locationManager: locationManager,
                path: $path
            )
        }
        .sheet(isPresented: $showABRouteSheet, onDismiss: {
            if form.scenario == .pointToPoint {
                form.clearScenario()
            }
        }) {
            RouteABSearchSheet(
                form: form,
                isPresented: $showABRouteSheet,
                locationManager: locationManager,
                path: $path
            )
        }
    }

    private var heroHeaderSection: some View {
        ZStack(alignment: .bottomLeading) {
            Image("RouteHubHeroCyclist")
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity)
                .frame(height: Self.heroContentHeight + 28)
                .clipped()
                .accessibilityHidden(true)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.52),
                    Color.black.opacity(0.1),
                    Color.black.opacity(0.45)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text(shortGreeting(at: context.date))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                }
                Text(String(localized: "Ready to plan a ride?"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.95))
            }
            .shadow(color: .black.opacity(0.45), radius: 8, x: 0, y: 2)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private var mapInnerCard: some View {
        Map(position: $mapCamera) {
            UserAnnotation {
                CycleLiveTrackUserAnnotation(location: locationManager.currentLocation)
            }
        }
        .mapStyle(CycleMapDisplayStyle.resolved(from: mapStyleRaw).toMapStyle())
        .frame(height: Self.mapInnerHeight)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Self.mapCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Self.mapCornerRadius, style: .continuous)
                .strokeBorder(Color.cycleBorder.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
        .allowsHitTesting(true)
        .accessibilityLabel(String(localized: "Map showing your area"))
    }

    private var gojekHubCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            mapInnerCard
                .padding(.horizontal, 12)
                .padding(.top, 14)
                .padding(.bottom, 6)

            Divider()
                .opacity(0.35)
                .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 18) {
                planYourRideHeader
                scenarioCardsRow
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cycleCardSurface)
        .clipShape(RoundedRectangle(cornerRadius: Self.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Self.cardCornerRadius, style: .continuous)
                .strokeBorder(Color.cycleBorder.opacity(0.45), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 24, x: 0, y: 12)
    }

    private func shortGreeting(at date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5 ..< 12:
            return String(localized: "Good morning")
        case 12 ..< 17:
            return String(localized: "Good afternoon")
        case 17 ..< 22:
            return String(localized: "Good evening")
        default:
            return String(localized: "Hey there")
        }
    }

    private var planYourRideHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "Plan Your Ride"))
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.cyclePrimaryText)
            Text(String(localized: "Choose your preferred routing style."))
                .font(.subheadline)
                .foregroundStyle(Color.cycleSecondaryText)
        }
    }

    private var scenarioCardsRow: some View {
        HStack(alignment: .top, spacing: 12) {
            scenarioPlanCard(
                title: String(localized: "Loop Route"),
                subtitle: String(localized: "Create a route starting and ending here"),
                systemImage: "arrow.trianglehead.2.clockwise.rotate.90",
                iconStyle: .accentFill
            ) {
                showLoopRouteSheet = true
            }

            scenarioPlanCard(
                title: String(localized: "Point A to B"),
                subtitle: String(localized: "Plan a one-way trip to a destination"),
                systemImage: "arrow.right.circle.fill",
                iconStyle: .accentSoft
            ) {
                showABRouteSheet = true
            }
        }
        .frame(maxWidth: .infinity)
    }

    private enum ScenarioCardIconStyle {
        case accentFill
        case accentSoft
    }

    private func scenarioPlanCard(
        title: String,
        subtitle: String,
        systemImage: String,
        iconStyle: ScenarioCardIconStyle,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(iconStyle == .accentFill ? Color.cycleAccent.opacity(0.2) : Color.cycleAccent.opacity(0.14))
                        .frame(width: 42, height: 42)
                    Image(systemName: systemImage)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.cycleAccent)
                }

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.cyclePrimaryText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.cycleSecondaryText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .minimumScaleFactor(0.88)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13)
            .background(Color(red: 248 / 255, green: 247 / 255, blue: 245 / 255))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.cycleBorder.opacity(0.55), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func syncRegionFromLocation() {
        let center = locationManager.currentLocation?.coordinate ?? Self.fallbackMapCenter
        form.updateSearchRegion(center: center)
    }
}

#Preview {
    NavigationStack {
        RouteSearchHubView(path: .constant(NavigationPath()), locationManager: LocationManager())
    }
}
