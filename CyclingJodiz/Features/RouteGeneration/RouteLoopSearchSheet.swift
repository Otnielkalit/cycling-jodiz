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
                    loopCenterCard
                    distanceSection
                    loopCompletionsSection
                    findRoutesSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 20)
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

    private var loopCenterCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                loopCenterIconColumn
                loopCenterFieldRow
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

    private var loopCenterIconColumn: some View {
        ZStack {
            Circle()
                .fill(Color.cycleSuccess)
                .frame(width: 24, height: 24)
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 26)
        .padding(.top, 2)
        .accessibilityHidden(true)
    }

    private var loopCenterFieldRow: some View {
        HStack(spacing: 8) {
            TextField(
                "",
                text: $form.loopLocationQuery,
                prompt: Text(String(localized: "Loop center…"))
                    .font(.subheadline)
                    .foregroundStyle(Color.cycleSecondaryText)
            )
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

            loopYourLocationButton
        }
        .padding(.vertical, 6)
    }

    private var loopYourLocationButton: some View {
        Button {
            Task {
                await form.applyYourLocation(slot: .loopCenter, location: locationManager.currentLocation)
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
        .accessibilityLabel(String(localized: "Use current location as loop center"))
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

    private var loopCompletionsSection: some View {
        Group {
            if form.loopCenterItem == nil, !form.completions.isEmpty, focusedField != .distance {
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
                let centerCoord = form.loopCenterItem!.placemark.coordinate
                let km = form.parsedDistanceKm ?? 20
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
