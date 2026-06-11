//
//  ActivityView.swift
//  CyclingJodiz
//
//  Created by otnielkalit on 11/06/26.
//

import MapKit
import CoreLocation
import SwiftUI
        
struct ActivityView: View {
    @State private var activities: [RideSummaryPayload] = []

    var body: some View {
        NavigationStack {
            Group {
                if activities.isEmpty {
                    ContentUnavailableView(
                        "No Rides Yet",
                        systemImage: "figure.outdoor.cycle",
                        description: Text("Start riding to see your journey history here.")
                    )
                } else {
                    List {
                        ForEach(activities) { activity in
                            ActivityRowCard(activity: activity)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                        .onDelete(perform: deleteActivity)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.cycleCanvasBackground)
                }
            }
            .navigationTitle("My Rides")
            .background(Color.cycleCanvasBackground)
            .onAppear {
                activities = ActivityPersistence.load()
            }
        }
    }

    private func deleteActivity(at offsets: IndexSet) {
        ActivityPersistence.delete(at: offsets)
        activities = ActivityPersistence.load()
    }
}

private struct ActivityRowCard: View {
    let activity: RideSummaryPayload
    @AppStorage(CycleMapDisplayStyle.storageKey) private var mapStyleRaw: String = CycleMapDisplayStyle.standard.rawValue

        private var coordCL: [CLLocationCoordinate2D] {
        activity.routeCoordinates.map(\.clLocationCoordinate2D)
    }

    private var formattedDate: String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: activity.startedAt)
    }

    private var durationText: String {
        let s = max(0, Int(activity.totalSeconds.rounded()))
        let h = s / 3600
        let m = (s % 3600) / 60
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(m) min"
    }

    private var initialCameraPosition: MapCameraPosition {
        let coords = coordCL
        guard !coords.isEmpty else { return .automatic }
        var minLat = 90.0, maxLat = -90.0, minLon = 180.0, maxLon = -180.0
        for c in coords {
            minLat = min(minLat, c.latitude)
            maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude)
            maxLon = max(maxLon, c.longitude)
        }
        let mid = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let dLat = max((maxLat - minLat) * 1.5, 0.003)
        let dLon = max((maxLon - minLon) * 1.5, 0.003)
        return .region(MKCoordinateRegion(center: mid, span: MKCoordinateSpan(latitudeDelta: dLat, longitudeDelta: dLon)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.cycleAccent.opacity(0.12))
                        .frame(width: 42, height: 42)
                    Image(systemName: "figure.outdoor.cycle")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.cycleAccent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(activity.routeTitle)
                        .font(.headline)
                        .foregroundStyle(Color.cyclePrimaryText)
                        .lineLimit(1)
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundStyle(Color.cycleSecondaryText)
                }
                Spacer()
            }

            
            HStack(spacing: 8) {
                ActivityMetricBadge(
                    value: String(format: "%.2f", activity.riddenDistanceMeters / 1000),
                    unit: "km",
                    systemImage: "arrow.triangle.pull"
                )
                ActivityMetricBadge(
                    value: durationText,
                    unit: "",
                    systemImage: "clock"
                )
                ActivityMetricBadge(
                    value: String(format: "%.1f", activity.avgSpeedKmh),
                    unit: "km/h",
                    systemImage: "speedometer"
                )
            }

            
            if !coordCL.isEmpty {
                Map(initialPosition: initialCameraPosition) {
                    MapPolyline(coordinates: coordCL)
                        .stroke(Color.cycleAccent, style: StrokeStyle(lineWidth: 3.5))
                }
                .mapStyle(CycleMapDisplayStyle.resolved(from: mapStyleRaw).toMapStyle())
                .frame(height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.cycleBorder.opacity(0.4), lineWidth: 1)
                )
            }
        }
        .padding(14)
        .background(Color.cycleCardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.cycleBorder.opacity(0.65), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
}

private struct ActivityMetricBadge: View {
    let value: String
    let unit: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(Color.cycleSecondaryText)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.cyclePrimaryText)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.cycleSecondaryText)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Color.cycleBorder.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

#Preview {
    ActivityView()
}
