//
//  CycleAppColorScheme.swift
//  CyclingJodiz
//
//  Created by otnielkalit on 11/06/26.
//

import SwiftUI

enum CycleAppColorScheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    static let storageKey = "cycleAppColorScheme"

    var title: String {
        switch self {
        case .system:
            return String(localized: "System Default")
        case .light:
            return String(localized: "Light")
        case .dark:
            return String(localized: "Dark")
        }
    }

    var iconName: String {
        switch self {
        case .system:
            return "iphone"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        }
    }

    var resolvedColorScheme: ColorScheme? {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil
        }
    }
}
