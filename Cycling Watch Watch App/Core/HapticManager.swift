//
//  HapticManager.swift
//  Cycling Watch Watch App
//
//  Created by otnielkalit on 11/06/26.
//

import WatchKit

class HapticManager {
    static let shared = HapticManager()
    
    func turnRight() {
        // 3 ketukan pendek
        WKInterfaceDevice.current()
            .play(.directionUp)
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.3) {
            WKInterfaceDevice.current()
                .play(.directionUp)
        }
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.6) {
            WKInterfaceDevice.current()
                .play(.directionUp)
        }
    }
    
    func turnLeft() {
        // 2 ketukan panjang
        WKInterfaceDevice.current()
            .play(.directionDown)
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.5) {
            WKInterfaceDevice.current()
                .play(.directionDown)
        }
    }
    
    func approachingTurn() {
        // Warning 200m sebelum belok
        WKInterfaceDevice.current()
            .play(.notification)
    }
    
    func weatherAlert() {
        WKInterfaceDevice.current()
            .play(.failure)
    }
}
