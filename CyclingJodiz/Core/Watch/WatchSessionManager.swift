//
//  WatchSessionManager.swift
//  CyclingJodiz
//
//  Created by otnielkalit on 01/06/26.
//

import Combine
import Foundation
import OSLog
import WatchConnectivity

/// Sends ride telemetry to the watch app via `updateApplicationContext`.
/// Queues payloads until `WCSession` finishes activating (avoids silent drops on `try?`).
final class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "CyclingJodiz", category: "WatchConnectivity")
    private let lock = NSLock()
    private var pendingContext: [String: Any] = [:]

    private override init() {
        super.init()
        guard WCSession.isSupported() else {
            logger.notice("WCSession not supported on this device")
            return
        }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendRideData(_ data: [String: Any]) {
        lock.lock()
        for (key, value) in data {
            pendingContext[key] = value
        }
        let snapshot = pendingContext
        lock.unlock()
        trySend(snapshot)
    }

    private func trySend(_ context: [String: Any]) {
        guard !context.isEmpty else { return }
        let session = WCSession.default
        guard session.activationState == .activated else {
            logger.debug("WCSession not activated yet; holding context (keys: \(context.keys.sorted(), privacy: .public))")
            return
        }
        #if os(iOS)
        logger.debug("WCSession state — paired: \(session.isPaired), watchAppInstalled: \(session.isWatchAppInstalled), reachable: \(session.isReachable)")
        #endif
        do {
            try session.updateApplicationContext(context)
            logger.debug("updateApplicationContext succeeded")
        } catch {
            logger.error("updateApplicationContext failed: \(error.localizedDescription, privacy: .public)")
        }
        // When the watch app is open, a message arrives immediately; applicationContext can lag on simulator.
        if session.isReachable {
            session.sendMessage(context, replyHandler: nil) { err in
                self.logger.error("sendMessage failed: \(err.localizedDescription, privacy: .public)")
            }
            logger.debug("sendMessage issued (watch reachable)")
        }
    }

    /// Pairing / install state changed — flush queued payload so the watch picks up `isRideActive` after install.
    func sessionWatchStateDidChange(_ session: WCSession) {
        logger.debug("sessionWatchStateDidChange paired=\(session.isPaired) installed=\(session.isWatchAppInstalled)")
        flushPending()
    }

    private func flushPending() {
        lock.lock()
        let snapshot = pendingContext
        lock.unlock()
        trySend(snapshot)
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error {
            logger.error("WCSession activation failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        guard activationState == .activated else { return }
        logger.debug("WCSession activated")
        flushPending()
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
