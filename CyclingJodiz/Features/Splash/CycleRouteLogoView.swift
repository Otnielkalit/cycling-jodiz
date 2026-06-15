import SwiftUI

struct CycleRouteLogoView: View {
    @State private var shimmerPercent: CGFloat = -0.5

    var body: some View {
        ZStack {
            Group {
                InfinityLoopShape()
                    .stroke(
                        Color(red: 242/255, green: 100/255, blue: 25/255).opacity(0.08),
                        style: StrokeStyle(lineWidth: 30, lineCap: .round, lineJoin: .round)
                    )
                ZRouteShape()
                    .stroke(
                        Color(red: 242/255, green: 100/255, blue: 25/255).opacity(0.08),
                        style: StrokeStyle(lineWidth: 30, lineCap: .round, lineJoin: .round)
                    )
            }
            .frame(width: 280, height: 140)
            .blur(radius: 5)

            Group {
                InfinityLoopShape()
                    .stroke(
                        Color(red: 242/255, green: 100/255, blue: 25/255),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round)
                    )
            }
            .frame(width: 280, height: 140)

            Group {
                InfinityLoopShape()
                    .stroke(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.52), .clear],
                            startPoint: UnitPoint(x: shimmerPercent - 0.2, y: 0.0),
                            endPoint: UnitPoint(x: shimmerPercent + 0.2, y: 1.0)
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round)
                    )
            }
            .frame(width: 280, height: 140)

            Group {
                ZRouteShape()
                    .stroke(
                        Color(red: 242/255, green: 100/255, blue: 25/255),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 2)
            }
            .frame(width: 280, height: 140)
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 3.8)
                        .repeatForever(autoreverses: false)
                ) {
                    shimmerPercent = 1.5
                }
            }
        }
    }
}
