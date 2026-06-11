//
//  RouteABSearchSheet.swift
//  CyclingJodiz
//
//  Created by otnielkalit on 11/06/26.
//

import CoreLocation
import MapKit
import SwiftUI

struct RouteABSearchSheet: View {
    @Bindable var form: RouteHubFormModel
    @Binding var isPresented: Bool
    var locationManager: LocationManager
    @Binding var path: NavigationPath

    @FocusState private var focusedField: ABSheetFocus?

    private enum ABSheetFocus: Hashable {
        case start
        case end
        case distance
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    routeEndpointsCard
                    distanceSection
                    completionsList
                    findRoutesSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.cycleCanvasBackground)
            .navigationTitle(String(localized: "Point-to-point"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        form.clearScenario()
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.cycleSecondaryText)
                    }
                    .accessibilityLabel(String(localized: "Close"))
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            form.setScenario(.pointToPoint)
            syncRegionFromLocation()
            form.setActiveSlot(.start)
        }
        .onChange(of: locationManager.currentLocation) { _, _ in
            syncRegionFromLocation()
        }
        .onChange(of: focusedField) { _, newValue in
            switch newValue {
            case .start:
                form.setActiveSlot(.start)
            case .end:
                form.setActiveSlot(.end)
            case .distance, .none:
                break
            }
            if newValue == .distance {
                form.clearCompletions()
            } else {
                form.scheduleCompleterQueryUpdate()
            }
        }
    }

    private var routeEndpointsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                routeEndpointIconColumn
                VStack(spacing: 0) {
                    startFieldRow
                    Divider()
                        .padding(.leading, 2)
                        .opacity(0.55)
                    endFieldRow
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Color.cycleCardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.cycleBorder.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    private var routeEndpointIconColumn: some View {
        VStack(spacing: 0) {
            startPin
            dashedConnector
            endPin
        }
        .frame(width: 26)
    }

    private var startPin: some View {
        ZStack {
            Circle()
                .fill(Color.cycleSuccess)
                .frame(width: 24, height: 24)
            Image(systemName: "arrow.up")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
        }
        .accessibilityHidden(true)
    }

    private var endPin: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.cycleAccent, lineWidth: 4)
                .frame(width: 24, height: 24)
            Circle()
                .fill(Color.cycleCardSurface)
                .frame(width: 8, height: 8)
        }
        .accessibilityHidden(true)
    }

    private var dashedConnector: some View {
        VStack(spacing: 4) {
            ForEach(0 ..< 5, id: \.self) { _ in
                Circle()
                    .fill(Color.cycleBorder.opacity(0.75))
                    .frame(width: 2.5, height: 2.5)
            }
        }
        .frame(height: 22)
        .frame(maxWidth: .infinity)
    }

    private var startFieldRow: some View {
        HStack(spacing: 8) {
            TextField(
                "",
                text: $form.startQuery,
                prompt: Text(String(localized: "Start from…"))
                    .font(.subheadline)
                    .foregroundStyle(Color.cycleSecondaryText)
            )
            .focused($focusedField, equals: .start)
            .textInputAutocapitalization(.words)
            .submitLabel(.search)
            .font(.subheadline)
            .foregroundStyle(Color.cyclePrimaryText)
            .tint(Color.cycleAccent)
            .onChange(of: form.startQuery) { _, _ in
                guard focusedField == .start else { return }
                form.setActiveSlot(.start)
                form.scheduleCompleterQueryUpdate()
            }
            .onSubmit { form.scheduleCompleterQueryUpdate() }

            yourLocationButton(slot: .start)
        }
        .padding(.vertical, 6)
    }

    private var endFieldRow: some View {
        HStack(spacing: 0) {
            TextField(
                "",
                text: $form.endQuery,
                prompt: Text(String(localized: "Finish at…"))
                    .font(.subheadline)
                    .foregroundStyle(Color.cycleSecondaryText)
            )
            .focused($focusedField, equals: .end)
            .textInputAutocapitalization(.words)
            .submitLabel(.search)
            .font(.subheadline)
            .foregroundStyle(Color.cyclePrimaryText)
            .tint(Color.cycleAccent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onChange(of: form.endQuery) { _, _ in
                guard focusedField == .end else { return }
                form.setActiveSlot(.end)
                form.scheduleCompleterQueryUpdate()
            }
            .onSubmit { form.scheduleCompleterQueryUpdate() }
        }
        .padding(.vertical, 6)
    }

    private func yourLocationButton(slot: RouteHubFormModel.SearchSlot) -> some View {
        Button {
            Task {
                await form.applyYourLocation(slot: slot, location: locationManager.currentLocation)
                form.clearCompletions()
            }
        } label: {
            Image(systemName: "location.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.cycleAccent)
                .frame(width: 32, height: 32)
                .background(Color.cycleAccent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Use current location as start"))
    }

    private static let quickDistanceKmValues: [Int] = [10, 15, 20, 25, 30, 40, 50]

    private var distanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Target distance"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.cyclePrimaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Self.quickDistanceKmValues, id: \.self) { km in
                        distanceQuickChip(km: km)
                    }
                }
                .padding(.vertical, 2)
            }

            HStack(spacing: 10) {
                TextField(String(localized: "Custom"), text: $form.distanceKmText)
                    .focused($focusedField, equals: .distance)
                    .keyboardType(.decimalPad)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.cyclePrimaryText)
                    .tint(Color.cycleAccent)
                    .multilineTextAlignment(.leading)

                Text(String(localized: "km"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.cycleSecondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.cycleBorder.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.cycleCardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.cycleBorder.opacity(0.55), lineWidth: 1)
            )
        }
    }

    private func distanceQuickChip(km: Int) -> some View {
        let matches = form.parsedDistanceKm.map { abs($0 - Double(km)) < 0.001 } ?? false
        return Button {
            form.distanceKmText = "\(km)"
            focusedField = nil
        } label: {
            Text("\(km)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(matches ? Color.white : Color.cyclePrimaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(matches ? Color.cycleAccent : Color.cycleBorder.opacity(0.32))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(km) \(String(localized: "km"))")
    }

    
    private var shouldShowMapSuggestions: Bool {
        !(form.startItem != nil && form.endItem != nil)
    }

    private var completionsList: some View {
        Group {
            if shouldShowMapSuggestions, !form.completions.isEmpty, focusedField != .distance {
                VStack(alignment: .leading, spacing: 0) {
                    Text(String(localized: "Places"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.cycleSecondaryText)
                        .padding(.bottom, 4)

                    VStack(spacing: 0) {
                        ForEach(Array(form.completions.enumerated()), id: \.offset) { index, completion in
                            Button {
                                Task {
                                    try? await form.selectCompletion(completion)
                                    if form.startItem != nil, form.endItem != nil {
                                        form.clearCompletions()
                                    }
                                    focusedField = nil
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(completion.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.cyclePrimaryText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    if !completion.subtitle.isEmpty {
                                        Text(completion.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(Color.cycleSecondaryText)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)

                            if index < form.completions.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                }
                .padding(10)
                .background(Color.cycleCardSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.cycleBorder, lineWidth: 1)
                )
            }
        }
    }

    private var findRoutesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let hint = form.validationHint, !form.canSubmit {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(Color.cycleSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                let startCoord = form.startItem!.placemark.coordinate
                let endCoord = form.endItem!.placemark.coordinate
                let km = form.parsedDistanceKm ?? 20
                let ctx = RoutePickContext.pointToPoint(
                    start: MapCoordinate(startCoord),
                    end: MapCoordinate(endCoord),
                    preferredLengthKm: km
                )
                path.append(RouteFlow.pick(ctx))
                form.clearScenario()
                isPresented = false
            } label: {
                Text(String(localized: "Find routes"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.cycleAccent)
            .disabled(!form.canSubmit)
        }
    }

    private func syncRegionFromLocation() {
        let center = locationManager.currentLocation?.coordinate
            ?? CLLocationCoordinate2D(latitude: -6.2, longitude: 106.82)
        form.updateSearchRegion(center: center)
    }
}

