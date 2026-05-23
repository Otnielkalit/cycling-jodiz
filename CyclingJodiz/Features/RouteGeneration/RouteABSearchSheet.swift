//
//  RouteABSearchSheet.swift
//  CyclingJodiz
//

import CoreLocation
import MapKit
import SwiftUI

/// Modal ala Gojek/Grab: titik jemput + tujuan bertumpuk, jarak, saran MapKit di bawah.
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
                VStack(alignment: .leading, spacing: 12) {
                    gojekStackedInputsCard
                    distanceSection
                    completionsList
                    findRoutesSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.cycleCanvasBackground)
            .navigationTitle(String(localized: "Set pickup & destination"))
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

    private var gojekStackedInputsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                gojekIconColumn
                VStack(spacing: 0) {
                    startFieldRow
                    Divider().padding(.leading, 0)
                    endFieldRow
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(Color.cycleCardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    private var gojekIconColumn: some View {
        VStack(spacing: 0) {
            pickupPin
            dashedConnector
            destinationPin
        }
        .frame(width: 26)
    }

    private var pickupPin: some View {
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

    private var destinationPin: some View {
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
            TextField(String(localized: "Pickup location"), text: $form.startQuery)
                .focused($focusedField, equals: .start)
                .textInputAutocapitalization(.words)
                .submitLabel(.search)
                .foregroundStyle(Color.cyclePrimaryText)
                .tint(Color.cycleAccent)
                .font(.subheadline)
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
        HStack(spacing: 8) {
            TextField(String(localized: "Destination"), text: $form.endQuery)
                .focused($focusedField, equals: .end)
                .textInputAutocapitalization(.words)
                .submitLabel(.search)
                .foregroundStyle(Color.cyclePrimaryText)
                .tint(Color.cycleAccent)
                .font(.subheadline)
                .onChange(of: form.endQuery) { _, _ in
                    guard focusedField == .end else { return }
                    form.setActiveSlot(.end)
                    form.scheduleCompleterQueryUpdate()
                }
                .onSubmit { form.scheduleCompleterQueryUpdate() }

            yourLocationButton(slot: .end)
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
        .accessibilityLabel(String(localized: "Your location"))
    }

    private var distanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Target distance (km)"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.cycleSecondaryText)

            TextField(String(localized: "e.g. 20"), text: $form.distanceKmText)
                .focused($focusedField, equals: .distance)
                .keyboardType(.decimalPad)
                .font(.subheadline)
                .foregroundStyle(Color.cyclePrimaryText)
                .tint(Color.cycleAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.cycleCardSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.cycleBorder, lineWidth: 1)
                )

            Text(
                String(
                    localized: "This is a rough ride length you’d like — Maps won’t match it exactly. Start and end stay fixed; we may suggest a longer detour if you want much more distance than the shortest path."
                )
            )
            .font(.caption2)
            .foregroundStyle(Color.cycleSecondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Saran MapKit disembunyikan setelah pickup & destination sudah ter-resolve (hemat ruang saat keyboard terbuka).
    private var shouldShowMapSuggestions: Bool {
        !(form.startItem != nil && form.endItem != nil)
    }

    private var completionsList: some View {
        Group {
            if shouldShowMapSuggestions, !form.completions.isEmpty, focusedField != .distance {
                VStack(alignment: .leading, spacing: 0) {
                    Text(String(localized: "Map suggestions"))
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

