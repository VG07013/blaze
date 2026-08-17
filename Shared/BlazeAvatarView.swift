import SwiftUI

/// Blaze the phoenix, drawn parametrically so he can grow through five
/// tiers and emote through six states without any image assets.
/// Used by the app (animated) and the widget (static).
///
/// Layout math is deliberately broken into small, explicitly-typed
/// sub-expressions — big mixed CGFloat/Double expressions send the Swift
/// type checker into the weeds.
struct BlazeAvatarView: View {
    var state: BlazeStateKind
    var tier: GrowthTier
    var flameColorID: String = "flame.classic"
    var skinID: String = "skin.classic"
    var size: CGFloat = 220
    var animated: Bool = true

    var body: some View {
        if animated {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                content(t: timeline.date.timeIntervalSinceReferenceDate)
            }
            .frame(width: size, height: size)
        } else {
            content(t: 0)
                .frame(width: size, height: size)
        }
    }

    @ViewBuilder
    private func content(t: TimeInterval) -> some View {
        switch state {
        case .frozen:
            FrozenCocoonView(size: size, t: t)
        case .burnedOut:
            BurnedOutView(size: size, t: t, flameColors: flameColors)
        default:
            PhoenixBodyView(
                state: state,
                tier: tier,
                flameColors: flameColors,
                skin: BlazeTheme.skinColors(for: skinID),
                size: size,
                t: t
            )
        }
    }

    private var flameColors: [Color] { BlazeTheme.flameColors(for: flameColorID) }
}

// MARK: - The phoenix

private struct PhoenixBodyView: View {
    let state: BlazeStateKind
    let tier: GrowthTier
    let flameColors: [Color]
    let skin: (body: [Color], accent: Color)
    let size: CGFloat
    let t: TimeInterval

    /// Working unit: Blaze's footprint scaled by growth tier.
    private var u: CGFloat { size * CGFloat(tier.visualScale) }

    var body: some View {
        let bob: CGFloat = bobOffset()
        let lean: Double = state == .worried ? 2.5 : 0.0
        ZStack {
            auraLayer
            if tier >= .ember {
                tailLayer(bob: bob)
            }
            wingsLayer(bob: bob)
            torsoLayer(bob: bob)
            crestLayer(bob: bob)
            faceLayer(bob: bob)
            if state == .rising {
                risingEmbersLayer
            }
        }
        .rotationEffect(.degrees(lean))
        .frame(width: size, height: size)
    }

    // MARK: Motion

    private func bobOffset() -> CGFloat {
        switch state {
        case .worried:
            let wave = CGFloat(sin(t * 1.2))
            return wave * 0.006 * u
        case .rising:
            let wave = CGFloat(sin(t * 5.0))
            return wave * 0.010 * u - 0.02 * u
        default:
            let wave = CGFloat(sin(t * 1.8))
            return wave * 0.010 * u
        }
    }

    /// Gentle sway most of the time; happy burst-flaps while thriving or rising.
    private var wingAngle: Double {
        switch state {
        case .thriving:
            let burst: Double = sin(t * 0.45)
            if burst > 0.86 { return sin(t * 15.0) * 22.0 }
            return sin(t * 1.8) * 5.0
        case .rising:
            return sin(t * 13.0) * 26.0
        case .worried:
            return sin(t * 1.0) * 2.0 - 6.0   // wings held close
        default:
            return sin(t * 1.8) * 5.0
        }
    }

    private var crestWidth: CGFloat {
        switch tier {
        case .spark: return 0.16
        case .ember: return 0.20
        case .flame: return 0.24
        case .inferno: return 0.28
        case .eternal: return 0.30
        }
    }

    private var crestHeight: CGFloat {
        switch tier {
        case .spark: return 0.20
        case .ember: return 0.27
        case .flame: return 0.34
        case .inferno: return 0.42
        case .eternal: return 0.48
        }
    }

    // MARK: Layers

    private var auraLayer: some View {
        let base: Double = state == .worried ? 0.28 : 0.45
        let pulse: Double = 0.06 * sin(t * 2.2)
        let glowColor: Color = (flameColors.last ?? .clear).opacity(base + pulse)
        return Circle()
            .fill(
                RadialGradient(
                    colors: [glowColor, .clear],
                    center: .center,
                    startRadius: 0.05 * u,
                    endRadius: 0.62 * u
                )
            )
            .frame(width: 1.3 * u, height: 1.3 * u)
    }

    private func tailLayer(bob: CGFloat) -> some View {
        let count: Int = min(2 + tier.rawValue, 6)
        let yOffset: CGFloat = 0.26 * u + bob * 0.4
        return ZStack {
            ForEach(0..<count, id: \.self) { i in
                tailFeather(index: i, count: count)
            }
        }
        .offset(y: yOffset)
    }

    private func tailFeather(index i: Int, count: Int) -> some View {
        let spread: Double = Double(i) - Double(count - 1) / 2.0
        let angle: Double = 180.0 + spread * 16.0
        let topColor: Color = flameColors[i % flameColors.count].opacity(0.9)
        let bottomColor: Color = skin.body.last ?? .red
        return FeatherShape()
            .fill(
                LinearGradient(colors: [topColor, bottomColor],
                               startPoint: .top, endPoint: .bottom)
            )
            .frame(width: 0.10 * u, height: 0.30 * u)
            .rotationEffect(.degrees(angle), anchor: .top)
    }

    private func wingsLayer(bob: CGFloat) -> some View {
        let wing: Double = wingAngle
        let xOffset: CGFloat = 0.25 * u
        let yOffset: CGFloat = -0.02 * u + bob
        return ZStack {
            wingView(mirrored: false)
                .rotationEffect(.degrees(38.0 + wing), anchor: .top)
                .offset(x: -xOffset, y: yOffset)
            wingView(mirrored: true)
                .rotationEffect(.degrees(-38.0 - wing), anchor: .top)
                .offset(x: xOffset, y: yOffset)
        }
    }

    private func wingView(mirrored: Bool) -> some View {
        FeatherShape()
            .fill(LinearGradient(colors: skin.body, startPoint: .top, endPoint: .bottom))
            .frame(width: 0.15 * u, height: 0.34 * u)
            .scaleEffect(x: mirrored ? -1 : 1, y: 1)
    }

    private func torsoLayer(bob: CGFloat) -> some View {
        let bodyGradient = LinearGradient(colors: skin.body, startPoint: .top, endPoint: .bottom)
        let bodyY: CGFloat = 0.10 * u + bob
        let bellyY: CGFloat = 0.15 * u + bob
        let headY: CGFloat = -0.14 * u + bob
        return ZStack {
            Ellipse()
                .fill(bodyGradient)
                .frame(width: 0.46 * u, height: 0.42 * u)
                .offset(y: bodyY)
            Ellipse()
                .fill(skin.accent.opacity(0.85))
                .frame(width: 0.26 * u, height: 0.24 * u)
                .offset(y: bellyY)
            Circle()
                .fill(bodyGradient)
                .frame(width: 0.30 * u, height: 0.30 * u)
                .offset(y: headY)
        }
    }

    private func crestLayer(bob: CGFloat) -> some View {
        let flameW: CGFloat = crestWidth * u
        let flameH: CGFloat = crestHeight * u
        let flameY: CGFloat = (-0.27 - crestHeight * 0.5) * u + bob
        let plumesY: CGFloat = -0.30 * u + bob
        return ZStack {
            LayeredFlame(colors: flameColors, phase: t * 3.0, dimmed: state == .worried)
                .frame(width: flameW, height: flameH)
                .offset(y: flameY)
            if tier >= .inferno {
                crownPlumes
                    .offset(y: plumesY)
            }
            if tier == .eternal {
                eternalRing
            }
        }
    }

    private var crownPlumes: some View {
        HStack(spacing: 0.10 * u) {
            ForEach(0..<2, id: \.self) { i in
                FeatherShape()
                    .fill(BlazeTheme.flameFill(flameColors))
                    .frame(width: 0.06 * u, height: 0.16 * u)
                    .rotationEffect(.degrees(i == 0 ? -24 : 24), anchor: .bottom)
                    .opacity(0.9)
            }
        }
    }

    private var eternalRing: some View {
        let ringOpacity: Double = 0.55 + 0.2 * sin(t * 1.4)
        let ringColors: [Color] = flameColors + [flameColors[0]]
        return Circle()
            .strokeBorder(
                AngularGradient(colors: ringColors, center: .center),
                lineWidth: 0.02 * u
            )
            .frame(width: 1.02 * u, height: 1.02 * u)
            .opacity(ringOpacity)
    }

    private func faceLayer(bob: CGFloat) -> some View {
        let beakY: CGFloat = -0.12 * u + bob
        let eyesY: CGFloat = -0.16 * u + bob
        return ZStack {
            BeakShape()
                .fill(Color(hex: 0xFFB13D))
                .frame(width: 0.09 * u, height: 0.08 * u)
                .offset(x: 0.14 * u, y: beakY)
            HStack(spacing: 0.09 * u) {
                eyeView
                eyeView
            }
            .offset(x: 0.02 * u, y: eyesY)
        }
    }

    @ViewBuilder
    private var eyeView: some View {
        let eyeSize: CGFloat = 0.055 * u
        switch state {
        case .worried:
            VStack(spacing: 0.012 * u) {
                Capsule()
                    .fill(Color.black.opacity(0.75))
                    .frame(width: eyeSize * 1.1, height: eyeSize * 0.22)
                    .rotationEffect(.degrees(-12))
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: eyeSize, height: eyeSize)
                    Circle()
                        .fill(Color.black)
                        .frame(width: eyeSize * 0.55, height: eyeSize * 0.55)
                        .offset(x: eyeSize * 0.12, y: eyeSize * -0.15)
                }
            }
        case .thriving, .rising:
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: eyeSize, height: eyeSize)
                Circle()
                    .fill(Color.black)
                    .frame(width: eyeSize * 0.58, height: eyeSize * 0.58)
                Circle()
                    .fill(Color.white)
                    .frame(width: eyeSize * 0.2, height: eyeSize * 0.2)
                    .offset(x: eyeSize * 0.14, y: eyeSize * -0.14)
            }
        default:
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: eyeSize, height: eyeSize)
                Circle()
                    .fill(Color.black)
                    .frame(width: eyeSize * 0.55, height: eyeSize * 0.55)
            }
        }
    }

    private var risingEmbersLayer: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { i in
                risingEmber(index: i)
            }
        }
    }

    private func risingEmber(index i: Int) -> some View {
        let seed: Double = Double(i) * 1.7
        let cycle: Double = (t * 0.8 + seed).truncatingRemainder(dividingBy: 1.6) / 1.6
        let xOffset: CGFloat = CGFloat(sin(seed * 4.1)) * 0.34 * u
        let yOffset: CGFloat = 0.45 * u - CGFloat(cycle) * u
        return Circle()
            .fill(flameColors[i % flameColors.count])
            .frame(width: 0.030 * u, height: 0.030 * u)
            .offset(x: xOffset, y: yOffset)
            .opacity(1.0 - cycle)
    }
}

// MARK: - Frozen cocoon

private struct FrozenCocoonView: View {
    let size: CGFloat
    let t: TimeInterval

    var body: some View {
        let u: CGFloat = size
        ZStack {
            glow(u: u)
            cocoon(u: u)
            sleepingFace(u: u)
            snowflakes(u: u)
            zzz(u: u)
        }
        .frame(width: size, height: size)
    }

    private func glow(u: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [BlazeTheme.freeze.opacity(0.28), .clear],
                    center: .center,
                    startRadius: 0.05 * u,
                    endRadius: 0.5 * u
                )
            )
            .frame(width: u, height: u)
    }

    private func cocoon(u: CGFloat) -> some View {
        Ellipse()
            .fill(
                LinearGradient(
                    colors: [Color(hex: 0x8FA6B8), Color(hex: 0x51606E)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .frame(width: 0.44 * u, height: 0.54 * u)
            .overlay(
                Ellipse().strokeBorder(BlazeTheme.freeze.opacity(0.7), lineWidth: 0.012 * u)
            )
    }

    private func sleepingFace(u: CGFloat) -> some View {
        HStack(spacing: 0.08 * u) {
            sleepingEye(u: u)
            sleepingEye(u: u)
        }
        .offset(y: -0.05 * u)
    }

    private func sleepingEye(u: CGFloat) -> some View {
        Capsule()
            .fill(Color(hex: 0x24303B))
            .frame(width: 0.07 * u, height: 0.016 * u)
    }

    private func snowflakes(u: CGFloat) -> some View {
        ForEach(0..<3, id: \.self) { i in
            let seed: Double = Double(i) * 2.4
            let xOffset: CGFloat = CGFloat(sin(t * 0.7 + seed)) * 0.28 * u
            let yBase: CGFloat = -0.30 * u - CGFloat(i) * 0.06 * u
            let yWobble: CGFloat = CGFloat(sin(t * 0.9 + seed)) * 0.02 * u
            Image(systemName: "snowflake")
                .font(.system(size: 0.07 * u))
                .foregroundStyle(BlazeTheme.freeze.opacity(0.8))
                .offset(x: xOffset, y: yBase + yWobble)
        }
    }

    private func zzz(u: CGFloat) -> some View {
        let textOpacity: Double = 0.75 + 0.25 * sin(t * 1.5)
        return Text("z z z")
            .font(.rounded(0.075 * u, .semibold))
            .foregroundStyle(BlazeTheme.freeze.opacity(textOpacity))
            .offset(x: 0.24 * u, y: -0.26 * u)
    }
}

// MARK: - Burned out

private struct BurnedOutView: View {
    let size: CGFloat
    let t: TimeInterval
    let flameColors: [Color]

    var body: some View {
        let u: CGFloat = size
        ZStack {
            mound(u: u)
            sadEyes(u: u)
            embers(u: u)
            smoke(u: u)
        }
        .frame(width: size, height: size)
    }

    private func mound(u: CGFloat) -> some View {
        ZStack {
            Ellipse()
                .fill(Color(hex: 0x3A3E4A))
                .frame(width: 0.52 * u, height: 0.20 * u)
                .offset(y: 0.26 * u)
            Ellipse()
                .fill(Color(hex: 0x4A4F5E))
                .frame(width: 0.36 * u, height: 0.16 * u)
                .offset(y: 0.20 * u)
            Ellipse()
                .fill(BlazeTheme.ash)
                .frame(width: 0.22 * u, height: 0.12 * u)
                .offset(y: 0.15 * u)
        }
    }

    private func sadEyes(u: CGFloat) -> some View {
        HStack(spacing: 0.07 * u) {
            sadEye(u: u).rotationEffect(.degrees(8))
            sadEye(u: u).rotationEffect(.degrees(-8))
        }
        .offset(y: 0.13 * u)
    }

    private func sadEye(u: CGFloat) -> some View {
        Capsule()
            .fill(Color(hex: 0x22242C))
            .frame(width: 0.06 * u, height: 0.014 * u)
    }

    /// Faint surviving embers — hope is not gone.
    private func embers(u: CGFloat) -> some View {
        ForEach(0..<4, id: \.self) { i in
            let seed: Double = Double(i) * 1.9
            let glowOpacity: Double = 0.35 + 0.3 * sin(t * 1.1 + seed)
            let xOffset: CGFloat = CGFloat(sin(seed * 3.3)) * 0.16 * u
            let yOffset: CGFloat = 0.22 * u - CGFloat(i % 2) * 0.03 * u
            Circle()
                .fill((flameColors.last ?? BlazeTheme.ember).opacity(glowOpacity))
                .frame(width: 0.028 * u, height: 0.028 * u)
                .offset(x: xOffset, y: yOffset)
        }
    }

    private func smoke(u: CGFloat) -> some View {
        let smokeOpacity: Double = 0.25 + 0.1 * sin(t * 0.8)
        let drift: CGFloat = CGFloat((t * 0.05).truncatingRemainder(dividingBy: 0.12)) * u
        return Circle()
            .fill(BlazeTheme.ash.opacity(smokeOpacity))
            .frame(width: 0.05 * u, height: 0.05 * u)
            .offset(x: 0.02 * u, y: 0.02 * u - drift)
            .blur(radius: 0.02 * u)
    }
}

#Preview("States") {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(BlazeStateKind.allCases, id: \.self) { state in
                VStack {
                    BlazeAvatarView(state: state, tier: .flame, size: 160)
                    Text(state.rawValue).font(.blazeCaption)
                }
            }
        }
    }
    .background(BlazeTheme.bgDark)
}
