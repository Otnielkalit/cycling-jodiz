//
//  PhoneSessionManager.swift
//  Cycling Watch Watch App
//
//  Created by otnielkalit on 11/06/26.
//

import Combine
import Foundation
import WatchConnectivity
import WatchKit

final class PhoneSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = PhoneSessionManager()

    @Published var speed: Double = 0
    @Published var distanceRemaining: Double = 0
    @Published var elapsedTime: String = "00:00"
    @Published var isRideActive: Bool = false
    @Published var nextTurn: String = ""
    @Published var showSummary: Bool = false
    @Published var summaryDistance: Double = 0
    @Published var summaryAvgSpeed: Double = 0
    @Published var summaryTime: String = "00:00"
    @Published var isReachable: Bool = false

    func pauseRide() {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["action": "pause"], replyHandler: nil, errorHandler: nil)
    }

    func resumeRide() {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["action": "resume"], replyHandler: nil, errorHandler: nil)
    }

    func endRide() {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["action": "end"], replyHandler: nil, errorHandler: nil)
    }

    override init() {
        super.init()

        guard WCSession.isSupported() else { return }

        WCSession.default.delegate = self
        WCSession.default.activate()
        self.isReachable = WCSession.default.isReachable
    }

    private func updateReachability() {
        DispatchQueue.main.async {
            self.isReachable = WCSession.default.isReachable
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        updateReachability()
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("WCSession activation failed: \(error.localizedDescription)")
            return
        }
        guard activationState == .activated else { return }
        updateReachability()
        // iPhone may have sent context before the watch finished activating.
        let ctx = session.receivedApplicationContext
        if !ctx.isEmpty {
            updateData(from: ctx)
        }
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        if let action = message["action"] as? String, action == "ping" {
            WKInterfaceDevice.current().play(.click)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                WKInterfaceDevice.current().play(.notification)
            }
            return
        }
        updateData(from: message)
    }

    func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        updateData(from: applicationContext)
    }

    private func updateData(from dict: [String: Any]) {
        DispatchQueue.main.async {
            let newIsActive = Self.plistBool(dict["isRideActive"])
            if self.isRideActive && !newIsActive {
                self.summaryDistance = Self.plistDouble(dict["summaryDistance"])
                self.summaryAvgSpeed = Self.plistDouble(dict["summaryAvgSpeed"])
                self.summaryTime = dict["summaryTime"] as? String ?? self.elapsedTime
                self.showSummary = true
            }
            
            self.speed = Self.plistDouble(dict["speed"])
            self.distanceRemaining = Self.plistDouble(dict["distanceRemaining"])
            self.elapsedTime = dict["elapsedTime"] as? String ?? "00:00"
            self.isRideActive = newIsActive
            self.nextTurn = dict["nextTurn"] as? String ?? ""
        }
    }

    private static func plistBool(_ value: Any?) -> Bool {
        switch value {
        case let b as Bool:
            return b
        case let n as NSNumber:
            return n.boolValue
        case let i as Int:
            return i != 0
        default:
            return false
        }
    }

    private static func plistDouble(_ value: Any?) -> Double {
        switch value {
        case let d as Double:
            return d
        case let f as Float:
            return Double(f)
        case let n as NSNumber:
            return n.doubleValue
        case let i as Int:
            return Double(i)
        default:
            return 0
        }
    }
}

