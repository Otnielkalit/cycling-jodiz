//
//  Cycling_WatchApp.swift
//  Cycling Watch Watch App
//
//  Created by otnielkalit on 11/06/26.
//

import SwiftUI

@main
struct Cycling_Watch_Watch_AppApp: App {
    init() {
        _ = PhoneSessionManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
