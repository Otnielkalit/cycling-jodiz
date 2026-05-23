//
//  WeatherHeaderIconView.swift
//  CyclingJodiz
//

import SwiftUI
import WeatherKit

// MARK: - SF Symbol + effects

/// Ikon cuaca di header: SF Symbol dari WeatherKit + efek halus (opsional).
struct WeatherHeaderIconView: View {
    let symbolName: String
    let condition: WeatherCondition?
    var pointSize: CGFloat = 24
    /// Matikan di chip header kecil supaya tidak “kedip” bersama orb.
    var animatesSymbol: Bool = true

    private var motion: WeatherHeaderIconMotion {
        WeatherHeaderIconMotion.resolve(condition)
    }

    var body: some View {
        Group {
            if animatesSymbol {
                Image(systemName: symbolName)
                    .font(.system(size: pointSize, weight: .medium))
                    .imageScale(.large)
                    .symbolRenderingMode(.multicolor)
                    .contentTransition(.symbolEffect(.replace))
                    .modifier(WeatherHeaderSymbolEffectModifier(motion: motion))
            } else {
                Image(systemName: symbolName)
                    .font(.system(size: pointSize, weight: .medium))
                    .imageScale(.large)
                    .symbolRenderingMode(.multicolor)
                    .contentTransition(.opacity)
            }
        }
    }
}

// MARK: - Orb (gradient ring + breathe)

/// Lingkaran lembut di sekitar ikon; animasi halus hanya saat `animated == true` (orb besar).
struct WeatherHeaderIconOrb: View {
    let symbolName: String
    let condition: WeatherCondition?
    let isLoading: Bool
    /// Outer diameter; default 72 for hero, ~52 for compact header chip.
    var diameter: CGFloat = 72
    /// `false` untuk chip header: tanpa TimelineView / denyut / cincin mutar (menghindari kedip).
    var animated: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var effectiveAnimated: Bool {
        animated && !reduceMotion
    }

    private var iconPointSize: CGFloat {
        max(20, diameter * 0.47)
    }

    private var ringLineWidth: CGFloat {
        diameter >= 64 ? 2.5 : 2
    }

    var body: some View {
        Group {
            if effectiveAnimated {
                TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: false)) { timeline in
                    orbStackAnimated(at: timeline.date)
                }
            } else {
                orbStackStill
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }

    /// Chip header: statis, tidak re-draw tiap frame.
    private var orbStackStill: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.cycleAccent.opacity(0.24),
                            Color.cycleAccent.opacity(0.07)
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: diameter * 0.52
                    )
                )
                .frame(width: diameter, height: diameter)

            Circle()
                .strokeBorder(Color.cycleAccent.opacity(0.22), lineWidth: ringLineWidth)
                .frame(width: diameter + 2, height: diameter + 2)

            if isLoading {
                ProgressView()
                    .controlSize(diameter >= 60 ? .regular : .small)
                    .tint(Color.cycleAccent)
            } else {
                WeatherHeaderIconView(
                    symbolName: symbolName,
                    condition: condition,
                    pointSize: iconPointSize,
                    animatesSymbol: false
                )
            }
        }
        .frame(width: diameter, height: diameter)
    }

    @ViewBuilder
    private func orbStackAnimated(at date: Date) -> some View {
        let t = date.timeIntervalSinceReferenceDate
        let breathe = 1.0 + 0.022 * sin(t * 1.1)
        let ringTurn = (t * 10).truncatingRemainder(dividingBy: 360)

        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.cycleAccent.opacity(0.28),
                            Color.cycleAccent.opacity(0.06)
                        ],
                        center: .center,
                        startRadius: 3,
                        endRadius: diameter * 0.55
                    )
                )
                .frame(width: diameter, height: diameter)

            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            Color.cycleAccent.opacity(0.55),
                            Color.cycleAccent.opacity(0.1),
                            Color.cycleAccent.opacity(0.45),
                            Color.cycleAccent.opacity(0.1)
                        ],
                        center: .center
                    ),
                    lineWidth: ringLineWidth
                )
                .frame(width: diameter + 3, height: diameter + 3)
                .rotationEffect(.degrees(ringTurn))

            if isLoading {
                ProgressView()
                    .controlSize(diameter >= 60 ? .regular : .small)
                    .tint(Color.cycleAccent)
            } else {
                WeatherHeaderIconView(
                    symbolName: symbolName,
                    condition: condition,
                    pointSize: iconPointSize,
                    animatesSymbol: true
                )
            }
        }
        .frame(width: diameter, height: diameter)
        .scaleEffect(isLoading ? 1.0 : breathe)
    }
}

// MARK: - Motion buckets (WeatherKit → SF Symbol effects)

private enum WeatherHeaderIconMotion {
    case none
    case variablePrecipitation
    case breatheClear
    case pulseStorm
    case windLayers

    static func resolve(_ condition: WeatherCondition?) -> WeatherHeaderIconMotion {
        guard let condition else { return .none }
        switch condition {
        case .rain, .drizzle, .heavyRain, .freezingRain, .freezingDrizzle, .sunShowers,
             .snow, .flurries, .heavySnow, .blizzard, .blowingSnow, .sleet, .sunFlurries, .hail:
            return .variablePrecipitation
        case .clear, .mostlyClear, .partlyCloudy, .hot:
            return .breatheClear
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms:
            return .pulseStorm
        case .windy, .breezy:
            return .windLayers
        case .mostlyCloudy, .cloudy, .foggy, .haze, .smoky, .frigid, .hurricane, .tropicalStorm,
             .blowingDust:
            return .none
        @unknown default:
            return .none
        }
    }
}

private struct WeatherHeaderSymbolEffectModifier: ViewModifier {
    let motion: WeatherHeaderIconMotion

    func body(content: Content) -> some View {
        switch motion {
        case .none:
            content
        case .variablePrecipitation:
            content
                .symbolEffect(.variableColor.iterative)
        case .breatheClear:
            content
                .symbolEffect(.breathe)
        case .pulseStorm:
            content
                .symbolEffect(.pulse)
        case .windLayers:
            content
                .symbolEffect(.variableColor.iterative.reversing)
        }
    }
}
