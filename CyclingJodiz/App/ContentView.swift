import SwiftUI

struct ContentView: View {
    @State private var isSplashActive = true
    @State private var splashOpacity = 1.0

    var body: some View {
        ZStack {
            if isSplashActive {
                SplashView()
                    .opacity(splashOpacity)
                    .transition(.opacity)
            } else {
                RootTabView()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeInOut(duration: 0.6)) {
                    splashOpacity = 0.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    isSplashActive = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

