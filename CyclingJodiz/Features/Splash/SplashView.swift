import SwiftUI

struct SplashView: View {
    @State private var logoScale = 0.8
    @State private var logoOpacity = 0.0
    @State private var textOffset = 20.0
    @State private var textOpacity = 0.0

    var body: some View {
        ZStack {
            Color(red: 252/255, green: 249/255, blue: 248/255)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                CycleRouteLogoView()
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                VStack(spacing: 6) {
                    HStack(spacing: 0) {
                        Text("Cycle")
                            .font(.system(size: 38, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(red: 28/255, green: 27/255, blue: 27/255))
                        Text("Route")
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .foregroundColor(Color(red: 242/255, green: 100/255, blue: 25/255))
                    }
                }
                .offset(y: textOffset)
                .opacity(textOpacity)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 1.0).delay(0.4)) {
                textOffset = 0.0
                textOpacity = 1.0
            }
        }
    }
}
