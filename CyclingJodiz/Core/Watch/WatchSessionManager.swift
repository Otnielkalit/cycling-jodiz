//
//  WatchSessionManager.swift
//  CyclingJodiz
//
//  Created by otnielkalit on 11/06/26.
//

import Combine
import Foundation
import OSLog
import WatchConnectivity

final class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "CyclingJodiz", category: "WatchConnectivity")
    private let lock = NSLock()
    private var pendingContext: [String: Any] = [:]

    @Published var isPaired: Bool = false
    @Published var isWatchAppInstalled: Bool = false
    @Published var isReachable: Bool = false

    override private init() {
        super.init()
        guard WCSession.isSupported() else {
            logger.notice("WCSession not supported on this device")
            return
        }
        WCSession.default.delegate = self
        WCSession.default.activate()
        updateSessionStatus()
    }

    private func updateSessionStatus() {
        let session = WCSession.default
        DispatchQueue.main.async {
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isReachable = session.isReachable
        }
    }

    func pingWatch() {
        let session = WCSession.default
        guard session.isReachable else {
            logger.warning("Cannot ping watch: not reachable")
            return
        }
        session.sendMessage(["action": "ping"], replyHandler: nil) { err in
            self.logger.error("Ping failed: \(err.localizedDescription, privacy: .public)")
        }
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
        if session.isReachable {
            session.sendMessage(context, replyHandler: nil) { err in
                self.logger.error("sendMessage failed: \(err.localizedDescription, privacy: .public)")
            }
            logger.debug("sendMessage issued (watch reachable)")
        }
        updateSessionStatus()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        logger.debug("sessionWatchStateDidChange paired=\(session.isPaired) installed=\(session.isWatchAppInstalled)")
        flushPending()
        updateSessionStatus()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        logger.debug("sessionReachabilityDidChange reachable=\(session.isReachable)")
        updateSessionStatus()
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
        updateSessionStatus()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let action = message["action"] as? String {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("WatchAction\(action.capitalized)"), object: nil)
            }
        }
        updateSessionStatus()
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
