import MapKit
import SwiftUI

struct RideSummaryView: View {
    @Binding var path: NavigationPath
    let payload: RideSummaryPayload

    @AppStorage(CycleMapDisplayStyle.storageKey) private var mapStyleRaw: String = CycleMapDisplayStyle.standard.rawValue
    @State private var mapCamera: MapCameraPosition = .automatic

    private var coordCL: [CLLocationCoordinate2D] {
        payload.routeCoordinates.map(\.clLocationCoordinate2D)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(String(localized: "Great ride! 🎉"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.cyclePrimaryText)

                Text(formattedStartLine)
                    .font(.subheadline)
                    .foregroundStyle(Color.cycleSecondaryText)

                statsGrid

                mapThumbnail
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(Color.cycleCanvasBackground)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Text(String(localized: "Ride Complete"))
                        .font(.headline.weight(.bold))
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.cycleSuccess)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button {
                    path = NavigationPath()
                } label: {
                    Text(String(localized: "Save Activity"))
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.cycleAccent)

                Button {
                    path = NavigationPath()
                } label: {
                    Text(String(localized: "Discard"))
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.bordered)
                .tint(Color(red: 220 / 255, green: 38 / 255, blue: 38 / 255))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
        .onAppear { fitThumbnailCamera() }
    }

    private var formattedStartLine: String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: payload.startedAt)
    }

    private var statsGrid: some View {
        let distKm = payload.riddenDistanceMeters / 1000
        let timeStr = formatRideDuration(payload.totalSeconds)
        let avg = payload.avgSpeedKmh

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            summaryTile(
                big: String(format: "%.1f km", distKm),
                small: String(localized: "Total Distance"),
                valueColor: Color.cycleAccent
            )
            summaryTile(
                big: timeStr,
                small: String(localized: "Total Time")
            )
            summaryTile(
                big: String(format: "%.1f km/h", avg),
                small: String(localized: "Avg Speed")
            )
            summaryTile(
                big: payload.routeTitle,
                small: String(localized: "Route Used"),
                valueColor: Color.cycleAccent
            )
        }
    }

    private func summaryTile(big: String, small: String, valueColor: Color = Color.cyclePrimaryText) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(big)
                .font(.title3.weight(.bold))
                .foregroundStyle(valueColor)
            Text(small)
                .font(.caption)
                .foregroundStyle(Color.cycleSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.cycleCardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    private var mapThumbnail: some View {
        Map(position: $mapCamera, interactionModes: []) {
            MapPolyline(coordinates: coordCL)
                .stroke(Color.cycleAccent, style: StrokeStyle(lineWidth: 4))
        }
        .mapStyle(CycleMapDisplayStyle.resolved(from: mapStyleRaw).toMapStyle())
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.cycleBorder.opacity(0.55), lineWidth: 1)
        )
    }

    private func fitThumbnailCamera() {
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
        let dLat = max((maxLat - minLat) * 1.4, 0.003)
        let dLon = max((maxLon - minLon) * 1.4, 0.003)
        mapCamera = .region(MKCoordinateRegion(center: mid, span: MKCoordinateSpan(latitudeDelta: dLat, longitudeDelta: dLon)))
    }

    private func formatRideDuration(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded()))
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        }
        return String(format: "%02d:%02d", m, sec)
    }
}
