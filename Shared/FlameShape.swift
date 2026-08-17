import SwiftUI

/// Classic teardrop flame silhouette. Fills its rect; tip at the top.
struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + 0.50 * w, y: rect.minY))
        p.addCurve(
            to: CGPoint(x: rect.minX + 0.84 * w, y: rect.minY + 0.62 * h),
            control1: CGPoint(x: rect.minX + 0.60 * w, y: rect.minY + 0.16 * h),
            control2: CGPoint(x: rect.minX + 0.84 * w, y: rect.minY + 0.36 * h)
        )
        p.addCurve(
            to: CGPoint(x: rect.minX + 0.50 * w, y: rect.minY + h),
            control1: CGPoint(x: rect.minX + 0.84 * w, y: rect.minY + 0.86 * h),
            control2: CGPoint(x: rect.minX + 0.70 * w, y: rect.minY + h)
        )
        p.addCurve(
            to: CGPoint(x: rect.minX + 0.16 * w, y: rect.minY + 0.62 * h),
            control1: CGPoint(x: rect.minX + 0.30 * w, y: rect.minY + h),
            control2: CGPoint(x: rect.minX + 0.16 * w, y: rect.minY + 0.86 * h)
        )
        p.addCurve(
            to: CGPoint(x: rect.minX + 0.50 * w, y: rect.minY),
            control1: CGPoint(x: rect.minX + 0.16 * w, y: rect.minY + 0.36 * h),
            control2: CGPoint(x: rect.minX + 0.40 * w, y: rect.minY + 0.16 * h)
        )
        p.closeSubpath()
        return p
    }
}

/// A layered flame: outer body, inner core, optional flicker driven by `phase`.
struct LayeredFlame: View {
    var colors: [Color]
    var phase: Double = 0          // animation phase in radians
    var dimmed: Bool = false

    var body: some View {
        GeometryReader { geo in
            let w: CGFloat = geo.size.width
            let h: CGFloat = geo.size.height
            let wobble: Double = 0.035 * sin(phase * 2.1) + 0.02 * sin(phase * 3.7 + 1.3)
            let flicker: CGFloat = 1.0 + CGFloat(wobble)
            let coreColors: [Color] = [Color.white.opacity(0.9), colors.last ?? .yellow]
            ZStack {
                FlameShape()
                    .fill(BlazeTheme.flameFill(colors))
                    .frame(width: w, height: h * flicker)
                    .opacity(dimmed ? 0.55 : 1.0)
                FlameShape()
                    .fill(BlazeTheme.flameFill(coreColors))
                    .frame(width: w * 0.48, height: h * 0.52 * flicker)
                    .offset(y: h * 0.30)
                    .opacity(dimmed ? 0.35 : 0.85)
            }
            .frame(width: w, height: h, alignment: .bottom)
        }
    }
}

/// Slim teardrop used for wings, tail feathers, and crest plumes.
struct FeatherShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + 0.5 * w, y: rect.minY))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + 0.5 * w, y: rect.minY + h),
            control: CGPoint(x: rect.minX + 1.15 * w, y: rect.minY + 0.55 * h)
        )
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + 0.5 * w, y: rect.minY),
            control: CGPoint(x: rect.minX - 0.15 * w, y: rect.minY + 0.55 * h)
        )
        p.closeSubpath()
        return p
    }
}

/// Small triangle beak.
struct BeakShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
