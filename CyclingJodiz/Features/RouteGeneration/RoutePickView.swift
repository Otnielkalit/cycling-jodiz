import CoreLocation
import MapKit
import SwiftUI

struct RoutePickView: View {
    @Binding var path: NavigationPath

    let context: RoutePickContext

    @AppStorage(CycleMapDisplayStyle.storageKey) private var mapStyleRaw: String = CycleMapDisplayStyle.standard.rawValue
    @State private var routes: [RouteCardModel] = []
    @State private var selectedIndex: Int = 0
    @State private var expandedRouteId: UUID?
    @State private var cameraPosition: MapCameraPosition
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var showSaveForLaterSheet = false
    @State private var plannedStartDate = Date().addingTimeInterval(7200)
    @State private var showRouteSavedConfirmation = false

    
    private let mapPreferredMaxHeight: CGFloat = 260

    init(path: Binding<NavigationPath>, context: RoutePickContext) {
        _path = path
        self.context = context
        _cameraPosition = State(initialValue: .region(Self.initialRegion(for: context)))
    }

    var body: some View {
        VStack(spacing: 0) {
            mapSection
                .frame(maxHeight: mapPreferredMaxHeight)

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
                .padding(.bottom, 20)
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
            bottomActionBar
        }
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showSaveForLaterSheet) {
            saveRouteSheet
        }
        .alert(String(localized: "Route saved"), isPresented: $showRouteSavedConfirmation) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(String(localized: "You can start this ride anytime from your saved plans (coming soon on Home)."))
        }
        .task(id: context) {
            await loadRoutes()
        }
    }

    
    private var bottomActionBar: some View {
        VStack(spacing: 10) {
            Button {
                plannedStartDate = Date().addingTimeInterval(7200)
                showSaveForLaterSheet = true
            } label: {
                Label(String(localized: "Save for later"), systemImage: "bookmark")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
            }
            .buttonStyle(.bordered)
            .tint(Color.cycleAccent)

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
            .tint(Color.cycleAccent)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(Color.cycleCanvasBackground)
    }

    private var saveRouteSheet: some View {
        NavigationStack {
            Form {
                Section {
                    if !routes.isEmpty, routes.indices.contains(selectedIndex) {
                        LabeledContent(String(localized: "Route")) {
                            Text(routes[selectedIndex].title)
                                .foregroundStyle(Color.cycleSecondaryText)
                        }
                    }
                    DatePicker(
                        String(localized: "Planned start"),
                        selection: $plannedStartDate,
                        in: Date()...Date.distantFuture,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                } footer: {
                    Text(String(localized: "The route is saved on this device for your chosen time. You’ll be able to open it from Home in a future update."))
                        .font(.footnote)
                }
            }
            .navigationTitle(String(localized: "Save route"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        showSaveForLaterSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) {
                        saveSelectedRouteForLater()
                    }
                    .fontWeight(.semibold)
                    .disabled(routes.isEmpty || !routes.indices.contains(selectedIndex))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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

    @ViewBuilder
    private func routeCard(route: RouteCardModel, index: Int) -> some View {
        let selected = index == selectedIndex
        let isExpanded = expandedRouteId == route.id
        let sheetHasExpansion = expandedRouteId != nil

        if sheetHasExpansion, !isExpanded {
            compactRouteRow(route: route, index: index, selected: selected)
        } else if isExpanded {
            expandedRouteCard(route: route, index: index, selected: selected)
        } else {
            defaultRouteCard(route: route, index: index, selected: selected)
        }
    }

    
    private func compactRouteRow(route: RouteCardModel, index: Int, selected _: Bool) -> some View {
        Button {
            selectedIndex = index
            expandedRouteId = route.id
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(route.lineColor)
                    .frame(width: 4)
                Text(route.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.cycleSecondaryText)
                Spacer(minLength: 8)
                Text("\(route.distanceLabel) · \(route.timeLabel)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.cycleSecondaryText)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.cycleSecondaryText.opacity(0.55))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.cycleCardSurface.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.cycleBorder.opacity(0.45), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint(String(localized: "Shows full route details"))
    }

    private func expandedRouteCard(route: RouteCardModel, index: Int, selected _: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                expandedRouteId = nil
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(route.lineColor)
                        .frame(width: 4)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center) {
                            Text(route.title)
                                .font(.headline)
                                .foregroundStyle(Color.cyclePrimaryText)
                            Spacer(minLength: 8)
                            VStack(spacing: 2) {
                                Image(systemName: "chevron.up")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(route.lineColor)
                                Text(String(localized: "Hide"))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.cycleSecondaryText)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(String(localized: "Collapse route details"))
                        }
                        routeTagRow(for: route)
                        Text(routeSubtitleHeadline(route.subtitle))
                            .font(.subheadline)
                            .foregroundStyle(Color.cycleSecondaryText)
                            .lineLimit(2)
                    }
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            Divider().opacity(0.35)

            expandedPrimaryMetricsGrid(route: route)
                .padding(16)

            routeBreakdownSection(route: route)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
        }
        .background(Color.cycleCardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(route.lineColor, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    private func defaultRouteCard(route: RouteCardModel, index: Int, selected: Bool) -> some View {
        Button {
            selectedIndex = index
            expandedRouteId = route.id
        } label: {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(route.lineColor)
                    .frame(width: 4)
                    .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(route.title)
                            .font(.headline)
                            .foregroundStyle(Color.cyclePrimaryText)
                        Spacer(minLength: 8)
                    }
                    routeTagRow(for: route)
                    Text(routeSubtitleHeadline(route.subtitle))
                        .font(.subheadline)
                        .foregroundStyle(Color.cycleSecondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(2)

                    HStack(alignment: .center, spacing: 10) {
                        Text(route.distanceLabel)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.cyclePrimaryText)
                        Text(route.timeLabel)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(route.lineColor)
                        Spacer(minLength: 8)
                        routeCardDisclosureChevron(accent: route.lineColor, emphasized: selected)
                        routeSelectionIndicator(selected: selected, accent: route.lineColor)
                    }
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
        .accessibilityHint(String(localized: "Shows distance, time, and route breakdown"))
    }

    
    private func routeCardDisclosureChevron(accent: Color, emphasized: Bool) -> some View {
        VStack(spacing: 2) {
            Image(systemName: "chevron.down")
                .font(.body.weight(.semibold))
                .foregroundStyle(emphasized ? accent : Color.cycleSecondaryText.opacity(0.55))
            Text(String(localized: "Details"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.cycleSecondaryText.opacity(0.85))
        }
        .accessibilityHidden(true)
    }

    
    @ViewBuilder
    private func routeTagRow(for route: RouteCardModel) -> some View {
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
            if let tag = route.recommendationTag, !tag.isEmpty {
                Text(tag)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(route.lineColor.opacity(0.14))
                    .foregroundStyle(route.lineColor)
                    .clipShape(Capsule())
            }
            transportChips(for: route)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func transportChips(for route: RouteCardModel) -> some View {
        switch route.transportKind {
        case .walking:
            chip(String(localized: "Walking path"), Color.cycleAccent)
        case .cycling:
            chip(String(localized: "Maps cycling"), Color.cycleSuccess)
        case .cyclingRoadEstimate:
            chip(String(localized: "Roads · bike ETA"), Color.cycleAccent)
        case .automobile:
            chip(String(localized: "Driving"), Color.cycleAccent)
        }
    }

    private func routeSelectionIndicator(selected: Bool, accent: Color) -> some View {
        ZStack {
            Circle()
                .strokeBorder(Color.cycleBorder.opacity(0.9), lineWidth: 2)
                .frame(width: 22, height: 22)
            if selected {
                Circle()
                    .fill(accent)
                    .frame(width: 12, height: 12)
            }
        }
        .accessibilityLabel(selected ? String(localized: "Selected route") : String(localized: "Unselected route"))
    }

    private func chip(_ title: String, _ color: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    
    private func routeSubtitleHeadline(_ subtitle: String) -> String {
        subtitle.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init) ?? subtitle
    }

    
    private func expandedPrimaryMetricsGrid(route: RouteCardModel) -> some View {
        let accent = route.lineColor
        let elev = route.elevationGainMeters.map { String(format: "+%.0f m", $0) }
            ?? String(localized: "—")
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

        return VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: columns, spacing: 12) {
                primaryMetricTile(title: String(localized: "DISTANCE"), value: route.distanceLabel, accent: accent)
                primaryMetricTile(title: String(localized: "EST. TIME"), value: route.timeLabel, accent: accent)
                primaryMetricTile(title: String(localized: "ELEVATION"), value: elev, accent: accent)
                primaryMetricTile(
                    title: String(localized: "INTERSECTIONS"),
                    value: "\(route.sharpTurnEstimateCount)",
                    accent: accent
                )
            }

            Text(String(localized: "Intersection count is estimated from sharp bends along the path, not official map data."))
                .font(.caption2)
                .foregroundStyle(Color.cycleSecondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(expandedMetricsSecondaryLine(for: route))
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.cycleSecondaryText.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func expandedMetricsSecondaryLine(for route: RouteCardModel) -> String {
        var parts: [String] = []
        let kph = String(format: "%.0f", route.impliedAverageSpeedKmh)
        parts.append("~" + kph + " " + String(localized: "km/h planned"))
        let dash = String(localized: "—")
        let target = targetPreferenceSummary(for: route)
        if target != dash {
            parts.append(target)
        }
        let straight = straightLineSummary(for: route)
        if straight != dash {
            parts.append("\(String(localized: "Straight line")) \(straight)")
        }
        return parts.joined(separator: " · ")
    }

    private func primaryMetricTile(title: String, value: String, accent: Color) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.cycleSecondaryText)
                .textCase(.uppercase)
                .tracking(0.45)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(accent)
                .minimumScaleFactor(0.78)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .background(Color.cycleCanvasBackground.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.cycleBorder.opacity(0.55), lineWidth: 1)
        )
    }

    private func straightLineSummary(for route: RouteCardModel) -> String {
        guard let crow = route.crowFliesMeters else {
            return String(localized: "—")
        }
        return formatKm(crow)
    }

    private func targetPreferenceSummary(for route: RouteCardModel) -> String {
        guard let km = route.targetPreferredKm else {
            return String(localized: "—")
        }
        let targetM = km * 1000
        let delta = route.routeMeters - targetM
        if abs(delta) < 120 {
            return String(localized: "~matches target")
        }
        if delta > 0 {
            return String(localized: "+\(formatShortMeters(delta)) vs ~\(String(format: "%.1f", km)) km")
        }
        return String(localized: "−\(formatShortMeters(-delta)) vs ~\(String(format: "%.1f", km)) km")
    }

    private func formatKm(_ meters: CLLocationDistance) -> String {
        String(format: "%.1f km", meters / 1000)
    }

    private func formatShortMeters(_ meters: CLLocationDistance) -> String {
        if meters < 1000 {
            return String(format: "%.0f m", meters)
        }
        return String(format: "%.1f km", meters / 1000)
    }

    @ViewBuilder
    private func routeBreakdownSection(route: RouteCardModel) -> some View {
        if route.breakdownRows.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "ROUTE BREAKDOWN"))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.cycleSecondaryText)
                    .tracking(0.6)

                VStack(spacing: 0) {
                    ForEach(Array(route.breakdownRows.enumerated()), id: \.offset) { idx, row in
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: row.symbolName)
                                .font(.body.weight(.medium))
                                .foregroundStyle(route.lineColor.opacity(0.85))
                                .frame(width: 28, alignment: .center)
                            Text(row.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.cyclePrimaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(2)
                            Text(row.distanceMeters < 1 ? "—" : formatShortMeters(row.distanceMeters))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(route.lineColor)
                                .multilineTextAlignment(.trailing)
                        }
                        .padding(.vertical, 12)
                        if idx < route.breakdownRows.count - 1 {
                            Divider().opacity(0.35)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.cycleCanvasBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.cycleBorder.opacity(0.4), lineWidth: 1)
                )
            }
        }
    }

    private func startRideTapped() {
        guard !routes.isEmpty, routes.indices.contains(selectedIndex) else { return }
        let route = routes[selectedIndex]
        let config = ActiveRideConfig.from(route: route, pickContext: context)
        path.append(RouteFlow.activeRide(config))
    }

    private func saveSelectedRouteForLater() {
        guard !routes.isEmpty, routes.indices.contains(selectedIndex) else { return }
        let route = routes[selectedIndex]
        let config = ActiveRideConfig.from(route: route, pickContext: context)
        let plan = SavedRoutePlan(
            id: UUID(),
            plannedStart: plannedStartDate,
            savedAt: Date(),
            config: config
        )
        SavedRoutePlansPersistence.append(plan)
        showSaveForLaterSheet = false
        showRouteSavedConfirmation = true
    }

    private func loadRoutes() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            let built = try await MapKitRouteDirectionsBuilder.buildRouteCards(context: context)
            routes = built
            expandedRouteId = nil
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
