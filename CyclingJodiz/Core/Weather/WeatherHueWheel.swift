//
//  WeatherHueWheel.swift
//  CyclingJodiz
//

import SwiftUI

/// HSB-based fills for the home weather card. Each mood = **satu segmen hue** di roda (0…1);
/// latar = saturasi rendah + brightness tinggi; suhu = **hue sama** dengan kroma lebih tinggi (harmoni analog).
enum WeatherHueWheel {
    // MARK: Hue anchors (SwiftUI `Color(hue:)` — 0 = merah, putaran penuh = 1)

    /// ~24° — selaras aksen app / “hari enak”.
    private static let orange: Double = 24 / 360
    /// ~208° — langit / sejuk.
    private static let azure: Double = 208 / 360
    /// ~265° — awan (violet lembut, analog dengan biru).
    private static let violet: Double = 265 / 360
    /// ~188° — air / hujan (teal).
    private static let teal: Double = 188 / 360
    /// ~38° — peringatan (amber, kontras harmonis dengan segmen teal).
    private static let amber: Double = 38 / 360
    /// ~8° — panas (merah–oranye).
    private static let scarlet: Double = 8 / 360

    static func cardBackground(for mood: WeatherCardPalette) -> Color {
        switch mood {
        case .fair:
            fill(hue: orange, chroma: 0.06, bright: 0.995)
        case .clearSky:
            fill(hue: azure, chroma: 0.07, bright: 0.99)
        case .softCloud:
            fill(hue: violet, chroma: 0.06, bright: 0.985)
        case .wet:
            fill(hue: teal, chroma: 0.08, bright: 0.99)
        case .caution:
            fill(hue: amber, chroma: 0.09, bright: 0.985)
        case .warm:
            fill(hue: scarlet, chroma: 0.08, bright: 0.99)
        case .neutral:
            Color.cycleCanvasBackground
        }
    }

    static func temperatureTint(for mood: WeatherCardPalette) -> Color {
        switch mood {
        case .fair:
            accent(hue: orange, chroma: 0.72, bright: 0.92)
        case .clearSky:
            accent(hue: azure, chroma: 0.62, bright: 0.52)
        case .softCloud:
            accent(hue: violet, chroma: 0.42, bright: 0.48)
        case .wet:
            accent(hue: teal, chroma: 0.58, bright: 0.45)
        case .caution:
            accent(hue: amber, chroma: 0.78, bright: 0.48)
        case .warm:
            accent(hue: scarlet, chroma: 0.85, bright: 0.52)
        case .neutral:
            Color.cycleSecondaryText
        }
    }

    private static func fill(hue: Double, chroma: Double, bright: Double) -> Color {
        Color(hue: hue, saturation: chroma, brightness: bright)
    }

    private static func accent(hue: Double, chroma: Double, bright: Double) -> Color {
        Color(hue: hue, saturation: chroma, brightness: bright)
    }
}
