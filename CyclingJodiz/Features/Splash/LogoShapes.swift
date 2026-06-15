import SwiftUI

struct InfinityLoopShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midX = rect.midX
        let midY = rect.midY
        
        path.move(to: CGPoint(x: midX, y: midY))
        
        path.addCurve(
            to: CGPoint(x: midX + width * 0.34, y: midY),
            control1: CGPoint(x: midX + width * 0.15, y: midY - height * 0.45),
            control2: CGPoint(x: midX + width * 0.35, y: midY - height * 0.45)
        )
        path.addCurve(
            to: CGPoint(x: midX, y: midY),
            control1: CGPoint(x: midX + width * 0.35, y: midY + height * 0.45),
            control2: CGPoint(x: midX + width * 0.15, y: midY + height * 0.45)
        )
        
        path.addCurve(
            to: CGPoint(x: midX - width * 0.34, y: midY),
            control1: CGPoint(x: midX - width * 0.15, y: midY - height * 0.45),
            control2: CGPoint(x: midX - width * 0.35, y: midY - height * 0.45)
        )
        path.addCurve(
            to: CGPoint(x: midX, y: midY),
            control1: CGPoint(x: midX - width * 0.35, y: midY + height * 0.45),
            control2: CGPoint(x: midX - width * 0.15, y: midY + height * 0.45)
        )
        
        return path
    }
}

struct ZRouteShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midX = rect.midX
        let midY = rect.midY
        path.move(to: CGPoint(x: midX - width * 0.17, y: midY))
        
        path.addCurve(
            to: CGPoint(x: midX - width * 0.05, y: midY - height * 0.13),
            control1: CGPoint(x: midX - width * 0.13, y: midY - height * 0.20),
            control2: CGPoint(x: midX - width * 0.08, y: midY - height * 0.20)
        )
        
        path.addLine(to: CGPoint(x: midX + width * 0.05, y: midY + height * 0.13))
        
        path.addCurve(
            to: CGPoint(x: midX + width * 0.17, y: midY),
            control1: CGPoint(x: midX + width * 0.08, y: midY + height * 0.20),
            control2: CGPoint(x: midX + width * 0.13, y: midY + height * 0.20)
        )
        
        return path
    }
}
