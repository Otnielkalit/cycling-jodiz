//
//  CyclingJodizApp.swift
//  CyclingJodiz
//
//  Created by otnielkalit on 11/06/26.
//

import SwiftUI

@main
struct CyclingJodizApp: App {
    @AppStorage(CycleAppColorScheme.storageKey) private var appColorSchemeRaw: String = CycleAppColorScheme.system.rawValue

    init() {
        _ = WatchSessionManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(CycleAppColorScheme(rawValue: appColorSchemeRaw)?.resolvedColorScheme)
        }
    }
}
