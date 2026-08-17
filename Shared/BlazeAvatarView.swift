import SwiftUI

/// Blaze the phoenix, drawn parametrically so he can grow through five
/// tiers and emote through six states without any image assets.
/// Used by the app (animated) and the widget (static).
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

    var body: some View {
        let u = size * tier.visualScale
        let bob = animatedBob
        let wing = wingAngle

        ZStack {
            aura(u: u)

            // Tail feather fan (grows with tier)
            if tier >= .ember {
                tailFan(u: u)
                    .offset(y: 0.26 * u + bob * 0.4)
            }

            // Wings
            wingView(u: u, mirrored: false)
                .rotationEffect(.degrees(38 + wing), anchor: .top)
                .offset(x: -0.25 * u, y: -0.02 * u + bob)
            wingView(u: u, mirrored: true)
                .rotationEffect(.degrees(-38 - wing), anchor: .top)
                .offset(x: 0.25 * u, y: -0.02 * u + bob)

            // Body
            Ellipse()
                .fill(LinearGradient(colors: skin.body, startPoint: .top, endPoint: .bottom))
                .frame(width: 0.46 * u, height: 0.42 * u)
                .offset(y: 0.10 * u + bob)

            // Belly
            Ellipse()
                .fill(skin.accent.opacity(0.85))
                .frame(width: 0.26 * u, height: 0.24 * u)
                .offset(y: 0.15 * u + bob)

            // Head
            Circle()
                .fill(LinearGradient(colors: skin.body, startPoint: .top, endPoint: .bottom))
                .frame(width: 0.30 * u, height: 0.30 * u)
                .offset(y: -0.14 * u + bob)

            // Crest flame
            LayeredFlame(colors: flameColors, phase: t * 3.0, dimmed: state == .worried)
                .frame(width: crestWidth * u, height: crestHeight * u)
                .offset(y: (-0.14 - 0.13 - crestHeight * 0.5) * u + bob)

            // Side plumes for the top tiers
            if tier >= .inferno {
                crownPlumes(u: u)
                    .offset(y: -0.30 * u + bob)
            }

            // Eternal tier: soft radiant ring
            if tier == .eternal {
                Circle()
                    .strokeBorder(
                        AngularGradient(colors: flameColors + [flameColors[0]], center: .center),
                        lineWidth: 0.02 * u
                    )
                    .frame(width: 1.02 * u, height: 1.02 * u)
                    .opacity(0.55 + 0.2 * sin(t * 1.4))
            }

            // Beak
            BeakShape()
                .fill(Color(hex: 0xFFB13D))
                .frame(width: 0.09 * u, height: 0.08 * u)
                .offset(x: 0.14 * u, y: -0.12 * u + bob)

            // Face
            faceView(u: u)
                .offset(y: -0.16 * u + bob)

            // Rising: upward ember streaks
            if state == .rising {
                risingEmbers(u: u)
            }
        }
        .rotationEffect(.degrees(state == .worried ? 2.5 : 0))
        .frame(width: size, height: size)
    }

    // MARK: Motion

    private var animatedBob: CGFloat {
        let u = size * tier.visualScale
        switch state {
        case .worried: return CGFloat(sin(t * 1.2)) * 0.006 * u
        case .rising:  return CGFloat(sin(t * 5.0)) * 0.010 * u - 0.02 * u
        default:       return CGFloat(sin(t * 1.8)) * 0.010 * u
        }
    }

    /// Gentle sway most of the time; happy burst-flaps while thriving or rising.
    private var wingAngle: Double {
        switch state {
        case .thriving:
            let burst = sin(t * 0.45)
            if burst > 0.86 { return sin(t * 15) * 22 }
            return sin(t * 1.8) * 5
        case .rising:
            return sin(t * 13) * 26
        case .worried:
            return sin(t * 1.0) * 2 - 6   // wings held close
        default:
            return sin(t * 1.8) * 5
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

    // MARK: Pieces

    private func aura(u: CGFloat) -> some View {
        let base = state == .worried ? 0.28 : 0.45
        let pulse = 0.06 * sin(t * 2.2)
        return Circle()
            .fill(
                RadialGradient(
                    colors: [flameColors.last?.opacity(base + pulse) ?? .clear, .clear],
                    center: .center,
                    startRadius: 0.05 * u,
                    endRadius: 0.62 * u
                )
            )
            .frame(width: 1.3 * u, height: 1.3 * u)
    }

    private func wingView(u: CGFloat, mirrored: Bool) -> some View {
        FeatherShape()
            .fill(
                LinearGradient(
                    colors: [skin.body.first ?? .orange, skin.body.last ?? .red],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 0.15 * u, height: 0.34 * u)
            .scaleEffect(x: mirrored ? -1 : 1, y: 1)
    }

    private func tailFan(u: CGFloat) -> some View {
        let count = min(2 + tier.rawValue, 6)
        return ZStack {
            ForEach(0..<count, id: \.self) { i in
                let spread = Double(i) - Double(count - 1) / 2.0
                FeatherShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                flameColors[i % flameColors.count].opacity(0.9),
                                skin.body.last ?? .red
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 0.10 * u, height: 0.30 * u)
                    .rotationEffect(.degrees(180 + spread * 16), anchor: .top)
            }
        }
    }

    private func crownPlumes(u: CGFloat) -> some View {
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

    @ViewBuilder
    private func faceView(u: CGFloat) -> some View {
        let eyeSize = 0.055 * u
        let eyeSpacing = 0.09 * u
        HStack(spacing: eyeSpacing) {
            eye(u: u, size: eyeSize)
            eye(u: u, size: eyeSize)
        }
        .offset(x: 0.02 * u)
    }

    @ViewBuilder
    private func eye(u: CGFloat, size eyeSize: CGFloat) -> some View {
        switch state {
        case .worried:
            VStack(spacing: 0.012 * u) {
                Capsule()
                    .fill(Color.black.opacity(0.75))
                    .frame(width: eyeSize * 1.1, height: eyeSize * 0.22)
                    .rotationEffect(.degrees(-12))
                ZStack {
                    Circle().fill(.white).frame(width: eyeSize, height: eyeSize)
                    Circle().fill(.black)
                        .frame(width: eyeSize * 0.55, height: eyeSize * 0.55)
                        .offset(x: eyeSize * 0.12, y: -eyeSize * 0.15)
                }
            }
        case .thriving, .rising:
            ZStack {
                Circle().fill(.white).frame(width: eyeSize, height: eyeSize)
                Circle().fill(.black).frame(width: eyeSize * 0.58, height: eyeSize * 0.58)
                Circle().fill(.white)
                    .frame(width: eyeSize * 0.2, height: eyeSize * 0.2)
                    .offset(x: eyeSize * 0.14, y: -eyeSize * 0.14)
            }
        default:
            ZStack {
                Circle().fill(.white).frame(width: eyeSize, height: eyeSize)
                Circle().fill(.black).frame(width: eyeSize * 0.55, height: eyeSize * 0.55)
            }
        }
    }

    private func risingEmbers(u: CGFloat) -> some View {
        ZStack {
            ForEach(0..<10, id: \.self) { i in
                let seed = Double(i) * 1.7
                let cycle = (t * 0.8 + seed).truncatingRemainder(dividingBy: 1.6) / 1.6
                Circle()
                    .fill(flameColors[i % flameColors.count])
                    .frame(width: 0.030 * u, height: 0.030 * u)
                    .offset(
                        x: CGFloat(sin(seed * 4.1)) * 0.34 * u,
                        y: 0.45 * u - CGFloat(cycle) * 1.0 * u
                    )
                    .opacity(1.0 - cycle)
            }
        }
    }
}

// MARK: - Frozen cocoon

private struct FrozenCocoonView: View {
    let size: CGFloat
    let t: TimeInterval

    var body: some View {
        let u = size
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [BlazeTheme.freeze.opacity(0.28), .clear],
                        center: .center, startRadius: 0.05 * u, endRadius: 0.5 * u
                    )
                )
                .frame(width: u, height: u)

            // Ash-ice cocoon
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

            // Sleeping face
            HStack(spacing: 0.08 * u) {
                sleepingEye(u: u)
                sleepingEye(u: u)
            }
            .offset(y: -0.05 * u)

            // Drifting snowflakes
            ForEach(0..<3, id: \.self) { i in
                let seed = Double(i) * 2.4
                Image(systemName: "snowflake")
                    .font(.system(size: 0.07 * u))
                    .foregroundStyle(BlazeTheme.freeze.opacity(0.8))
                    .offset(
                        x: CGFloat(sin(t * 0.7 + seed)) * 0.28 * u,
                        y: -0.30 * u - CGFloat(i) * 0.06 * u + CGFloat(sin(t * 0.9 + seed)) * 0.02 * u
                    )
            }

            Text("z z z")
                .font(.rounded(0.075 * u, .semibold))
                .foregroundStyle(BlazeTheme.freeze.opacity(0.75 + 0.25 * sin(t * 1.5)))
                .offset(x: 0.24 * u, y: -0.26 * u)
        }
        .frame(width: size, height: size)
    }

    private func sleepingEye(u: CGFloat) -> some View {
        Capsule()
            .fill(Color(hex: 0x24303B))
            .frame(width: 0.07 * u, height: 0.016 * u)
    }
}

// MARK: - Burned out

private struct BurnedOutView: View {
    let size: CGFloat
    let t: TimeInterval
    let flameColors: [Color]

    var body: some View {
        let u = size
        ZStack {
            // Ash mound
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

            // Sad closed eyes on the mound
            HStack(spacing: 0.07 * u) {
                sadEye(u: u).rotationEffect(.degrees(8))
                sadEye(u: u).rotationEffect(.degrees(-8))
            }
            .offset(y: 0.13 * u)

            // Faint surviving embers — hope is not gone
            ForEach(0..<4, id: \.self) { i in
                let seed = Double(i) * 1.9
                let glow = 0.35 + 0.3 * sin(t * 1.1 + seed)
                Circle()
                    .fill((flameColors.last ?? BlazeTheme.ember).opacity(glow))
                    .frame(width: 0.028 * u, height: 0.028 * u)
                    .offset(
                        x: CGFloat(sin(seed * 3.3)) * 0.16 * u,
                        y: 0.22 * u - CGFloat(i % 2) * 0.03 * u
                    )
            }

            // A single wisp of smoke
            Circle()
                .fill(BlazeTheme.ash.opacity(0.25 + 0.1 * sin(t * 0.8)))
                .frame(width: 0.05 * u, height: 0.05 * u)
                .offset(x: 0.02 * u, y: 0.02 * u - CGFloat((t * 0.05).truncatingRemainder(dividingBy: 0.12)) * u)
                .blur(radius: 0.02 * u)
        }
        .frame(width: size, height: size)
    }

    private func sadEye(u: CGFloat) -> some View {
        Capsule()
            .fill(Color(hex: 0x22242C))
            .frame(width: 0.06 * u, height: 0.014 * u)
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
