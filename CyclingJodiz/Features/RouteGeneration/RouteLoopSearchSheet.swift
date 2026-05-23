import CoreLocation
import MapKit
import SwiftUI

struct RouteLoopSearchSheet: View {
    @Bindable var form: RouteHubFormModel
    @Binding var isPresented: Bool
    var locationManager: LocationManager
    @Binding var path: NavigationPath

    @FocusState private var focusedField: LoopSheetFocus?

    private enum LoopSheetFocus: Hashable {
        case loopCenter
        case distance
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    loopSearchSection
                    distanceSection
                    loopCompletionsSection
                    findRoutesSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.cycleCanvasBackground)
            .navigationTitle(String(localized: "Loop route"))
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
            form.setScenario(.loop)
            syncRegionFromLocation()
            form.setActiveSlot(.loopCenter)
        }
        .onChange(of: locationManager.currentLocation) { _, _ in
            syncRegionFromLocation()
        }
        .onChange(of: focusedField) { _, newValue in
            switch newValue {
            case .loopCenter:
                form.setActiveSlot(.loopCenter)
                form.scheduleCompleterQueryUpdate()
            case .distance:
                form.clearCompletions()
            case .none:
                break
            }
        }
    }

    private var loopSearchSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "Start point"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.cycleSecondaryText)

            HStack(spacing: 10) {
                Circle()
                    .fill(Color.cycleAccent)
                    .frame(width: 10, height: 10)

                TextField(String(localized: "Search on map"), text: $form.loopLocationQuery)
                    .focused($focusedField, equals: .loopCenter)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.search)
                    .font(.subheadline)
                    .foregroundStyle(Color.cyclePrimaryText)
                    .tint(Color.cycleAccent)
                    .onChange(of: form.loopLocationQuery) { _, _ in
                        guard focusedField == .loopCenter else { return }
                        form.setActiveSlot(.loopCenter)
                        form.scheduleCompleterQueryUpdate()
                    }
                    .onSubmit { form.scheduleCompleterQueryUpdate() }

                Button {
                    Task {
                        await form.applyYourLocation(slot: .loopCenter, location: locationManager.currentLocation)
                        form.clearCompletions()
                    }
                } label: {
                    Label(String(localized: "Your location"), systemImage: "location.fill")
                        .font(.caption2.weight(.semibold))
                        .labelStyle(.iconOnly)
                        .foregroundStyle(Color.cycleAccent)
                        .padding(8)
                        .background(Color.cycleAccent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Your location"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.cycleCanvasBackground.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.cycleBorder, lineWidth: 1)
            )
        }
    }

    private var distanceSection: some View {
        VStack(alignment: .leading, spacing: 4) {
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

            Text(String(localized: "Paths return to your start. Distance on each card is the full round trip in Maps."))
                .font(.caption2)
                .foregroundStyle(Color.cycleSecondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(String(localized: "We aim for your target km (round trip). If Maps has no cycling line, we use driving roads as a shape hint and show an estimated bike time (~18 km/h) — not car clock time."))
                .font(.caption2)
                .foregroundStyle(Color.cycleSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var loopCompletionsSection: some View {
        Group {
            if form.loopCenterItem == nil, !form.completions.isEmpty, focusedField != .distance {
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
                                    if form.loopCenterItem != nil {
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
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)

                            if index < form.completions.count - 1 {
                                Divider()
                            }
                        }
                    }
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
                let centerCoord = form.loopCenterItem!.placemark.coordinate
                let km = Double(form.distanceKmText.replacingOccurrences(of: ",", with: ".")) ?? 20
                let ctx = RoutePickContext.loop(center: MapCoordinate(centerCoord), targetKm: km)
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
