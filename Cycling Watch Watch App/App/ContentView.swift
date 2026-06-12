//
//  ContentView.swift
//  Cycling Watch Watch App
//
//  Created by otnielkalit on 11/06/26.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var session = PhoneSessionManager.shared

    var body: some View {
        if session.isRideActive {
            ActiveRideWatchView()
        } else {
            IdleWatchView()
        }
    }
}

struct ActiveRideWatchView: View {
    @ObservedObject private var session = PhoneSessionManager.shared
    @State private var isLocalPaused = false

    var body: some View {
        TabView {
            // Tab 1: Dashboard (Circular Gauge)
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.18), lineWidth: 6)
                        .frame(width: 86, height: 86)
                    
                    Circle()
                        .trim(from: 0.0, to: CGFloat(min(session.speed / 45.0, 1.0)))
                        .stroke(
                            AngularGradient(
                                colors: [.orange, .red, .orange],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 86, height: 86)
                        .animation(.easeInOut(duration: 0.5), value: session.speed)
                    
                    VStack(spacing: 0) {
                        Text(String(format: "%.1f", session.speed))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                        Text("km/h")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top, 4)
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 3) {
                            Image(systemName: "bicycle")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                            Text(String(format: "%.1f km", session.distanceRemaining))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        Text("left")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                            .padding(.leading, 14)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 3) {
                            Image(systemName: "stopwatch.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                            Text(session.elapsedTime)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        Text("elapsed")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                            .padding(.leading, 14)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
            }
            .padding(.top, -10)
            
            // Tab 2: Navigation Directions
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: navigationArrowName)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.orange)
                }
                
                Text(session.nextTurn.isEmpty ? "Follow the route" : session.nextTurn)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.white)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 4)
            }
            .padding(.top, -10)
            .onChange(of: session.nextTurn) { _, newValue in
                triggerHapticForDirection(newValue)
            }
            
            // Tab 3: Controls
            VStack(spacing: 12) {
                Text(isLocalPaused ? "Ride Paused" : "Active Ride")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(isLocalPaused ? .yellow : .white)
                    .padding(.top, -10)
                
                HStack(spacing: 14) {
                    Button {
                        if isLocalPaused {
                            session.resumeRide()
                            isLocalPaused = false
                        } else {
                            session.pauseRide()
                            isLocalPaused = true
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: isLocalPaused ? "play.fill" : "pause.fill")
                                .font(.title3)
                            Text(isLocalPaused ? "Resume" : "Pause")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(isLocalPaused ? .green : .orange)
                    
                    Button {
                        session.endRide()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "stop.fill")
                                .font(.title3)
                            Text("End")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .padding(.horizontal, 4)
            }
        }
        .tabViewStyle(PageTabViewStyle())
    }

    private var navigationArrowName: String {
        let turn = session.nextTurn.lowercased()
        if turn.contains("left") {
            return "arrow.turn.up.left"
        } else if turn.contains("right") {
            return "arrow.turn.up.right"
        } else if turn.contains("destination") || turn.contains("arrive") {
            return "mappin.and.ellipse"
        } else {
            return "arrow.up"
        }
    }

    private func triggerHapticForDirection(_ turnText: String) {
        let turn = turnText.lowercased()
        if turn.contains("left") {
            HapticManager.shared.turnLeft()
        } else if turn.contains("right") {
            HapticManager.shared.turnRight()
        } else if !turnText.isEmpty {
            HapticManager.shared.approachingTurn()
        }
    }
}

struct IdleWatchView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.orange.opacity(0.2), lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Image(systemName: "bicycle")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.orange)
                    .scaleEffect(isAnimating ? 1.15 : 0.95)
                    .animation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
            }
            .padding(.top, 8)
            .onAppear {
                isAnimating = true
            }
            
            VStack(spacing: 4) {
                Text("Ready to Ride")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Start your ride session\nfrom the iPhone app")
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
