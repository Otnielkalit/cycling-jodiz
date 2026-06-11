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

    var body: some View {
        VStack(spacing: 4) {
            // Kecepatan — paling dominan
            Text("\(session.speed, specifier: "%.1f")")
                .font(.system(size: 36,
                              weight: .bold))
                .foregroundColor(.orange)
            Text("km/h")
                .font(.caption2)
                .foregroundColor(.gray)

            Divider()

            // Sisa jarak & waktu
            HStack {
                VStack {
                    Text("\(session.distanceRemaining, specifier: "%.1f")")
                        .font(.title3.bold())
                    Text("km left")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                Divider()
                VStack {
                    Text(session.elapsedTime)
                        .font(.title3.bold())
                    Text("elapsed")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }

            // Next turn
            if !session.nextTurn.isEmpty {
                Text(session.nextTurn)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
        .padding()
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

