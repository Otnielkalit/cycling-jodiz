import Combine
import SwiftUI
import WatchConnectivity

struct ContentView: View {
    @ObservedObject private var session = PhoneSessionManager.shared

    var body: some View {
        if session.showSummary {
            SummaryWatchView()
        } else if session.isRideActive {
            ActiveRideWatchView()
        } else {
            IdleWatchView()
        }
    }
}

struct IdleWatchView: View {
    @ObservedObject private var session = PhoneSessionManager.shared
    @State private var orbitRotation = 0.0
    @State private var pulseScale = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 4) {
                HStack {
                    Text("9:41")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(session.isReachable ? .green : .orange)
                }
                .padding(.horizontal, 8)

                Spacer()

                Text("MORNING SPRINT")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(Color(red: 255/255, green: 110/255, blue: 40/255))
                    .tracking(1.5)

                Text("Ready?")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.bottom, 6)

                ZStack {
                    Circle()
                        .stroke(
                            Color(red: 255/255, green: 110/255, blue: 40/255).opacity(0.4),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 5])
                        )
                        .frame(width: 82, height: 82)
                        .rotationEffect(.degrees(orbitRotation))

                    Button {
                        if session.isReachable {
                            session.resumeRide()
                        } else {
                            session.isRideActive = true
                        }
                    } label: {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(red: 255/255, green: 110/255, blue: 40/255),
                                        Color(red: 242/255, green: 100/255, blue: 25/255)
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 36
                                )
                            )
                            .frame(width: 68, height: 68)
                            .overlay(
                                Text("START")
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                            )
                            .scaleEffect(pulseScale)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
        }
        .onAppear {
            withAnimation(
                Animation.linear(duration: 6.0)
                    .repeatForever(autoreverses: false)
            ) {
                orbitRotation = 360
            }

            withAnimation(
                Animation.easeInOut(duration: 1.2)
                    .repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.04
            }
        }
    }
}

struct ActiveRideWatchView: View {
    @ObservedObject private var session = PhoneSessionManager.shared
    @State private var isLocalPaused = false
    @State private var simulatedBpm = 148

    private let bpmTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        TabView {
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: -2) {
                    HStack {
                        Text("VELOCITY")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(Color(red: 255/255, green: 90/255, blue: 31/255))
                            .tracking(1.0)

                        Spacer()

                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.gray.opacity(0.6))
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(String(format: "%.1f", session.speed))
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .italic()
                            .foregroundColor(.white)

                        Text("KM/H")
                            .font(.system(size: 10, weight: .heavy))
                            .italic()
                            .foregroundColor(Color(red: 255/255, green: 90/255, blue: 31/255))
                    }
                }
                .padding(.horizontal, 4)

                HStack(spacing: 6) {
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.4))
                            .frame(width: 3)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("DISTANCE")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.gray)

                            HStack(alignment: .firstTextBaseline, spacing: 1) {
                                Text(String(format: "%.1f", session.distanceRemaining))
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text("KM")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.leading, 5)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(6)

                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color(red: 255/255, green: 110/255, blue: 40/255))
                            .frame(width: 3)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("HEART")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.gray)

                            HStack(alignment: .firstTextBaseline, spacing: 1) {
                                Text("\(simulatedBpm)")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(red: 255/255, green: 110/255, blue: 40/255))
                                Text("BPM")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.leading, 5)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(6)
                }

                HStack(alignment: .center) {
                    Text(session.elapsedTime)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)

                    Spacer()

                    Button {
                        if isLocalPaused {
                            session.resumeRide()
                            isLocalPaused = false
                        } else {
                            session.pauseRide()
                            isLocalPaused = true
                        }
                    } label: {
                        Image(systemName: isLocalPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(red: 255/255, green: 90/255, blue: 31/255))
                            .frame(width: 28, height: 20)
                            .background(Color(red: 255/255, green: 90/255, blue: 31/255).opacity(0.12))
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color(red: 255/255, green: 90/255, blue: 31/255).opacity(0.4), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
                .padding(.top, 4)
            }
            .padding(.horizontal, 4)
            .padding(.top, -6)
            .onReceive(bpmTimer) { _ in
                if session.speed > 0 {
                    simulatedBpm = Int.random(in: 140...151)
                } else {
                    simulatedBpm = Int.random(in: 92...99)
                }
            }

            VStack(spacing: 4) {
                HStack {
                    Text("ETA 10:15")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                    Spacer()
                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color(red: 255/255, green: 90/255, blue: 31/255))
                            .frame(width: 4, height: 4)
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 4, height: 4)
                    }
                }
                .padding(.horizontal, 6)

                Spacer()
                VStack(spacing: 2) {
                    Image(systemName: navigationArrowName)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color(red: 255/255, green: 90/255, blue: 31/255))
                        .shadow(color: Color(red: 255/255, green: 90/255, blue: 31/255).opacity(0.4), radius: 6)
                        .padding(.bottom, 2)

                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(session.nextTurn.isEmpty ? "300" : session.nextTurn)
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("m")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                    }

                    Text("ALPINE WAY")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.gray.opacity(0.8))
                        .tracking(1.0)
                }

                Spacer()
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.14))
                            .frame(height: 4)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 255/255, green: 110/255, blue: 40/255),
                                        Color(red: 255/255, green: 60/255, blue: 10/255)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * 0.7, height: 4)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
            }
            .padding(.horizontal, 4)
            .padding(.top, -6)

            VStack(spacing: 12) {
                Text("End Session?")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.white)

                Button {
                    session.endRide()
                } label: {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("END RIDE")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.red, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
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
            return "arrow.turn.up.right"
        }
    }
}

struct SummaryWatchView: View {
    @ObservedObject private var session = PhoneSessionManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("SESSION END")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(Color(red: 255/255, green: 90/255, blue: 31/255))
                        .tracking(1.5)

                    Text("Summary")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .italic()
                        .foregroundColor(.white)
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color(red: 255/255, green: 90/255, blue: 31/255).opacity(0.15))
                        .frame(width: 26, height: 26)
                    Image(systemName: "medal.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 255/255, green: 110/255, blue: 40/255))
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)

            VStack(spacing: 4) {
                HStack {
                    Text("DIST")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray.opacity(0.8))
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(String(format: "%.1f", session.summaryDistance))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("KM")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 8)
                .background(Color.white.opacity(0.06))
                .cornerRadius(6)

                HStack {
                    Text("AVG")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray.opacity(0.8))
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(String(format: "%.1f", session.summaryAvgSpeed))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("KM/H")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 8)
                .background(Color.white.opacity(0.06))
                .cornerRadius(6)

                HStack {
                    Text("CAL")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray.opacity(0.8))
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text("\(Int((session.summaryDistance * 32) + 50))")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 255/255, green: 110/255, blue: 40/255))
                        Text("KCAL")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 8)
                .background(Color.white.opacity(0.06))
                .cornerRadius(6)
            }

            Spacer()

            Button {
                session.showSummary = false
            } label: {
                Text("DONE")
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 2)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

#Preview {
    ContentView()
}
