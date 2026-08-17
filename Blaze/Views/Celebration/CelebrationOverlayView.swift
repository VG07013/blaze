import SwiftUI

/// Full-screen emotional moments: milestone triumphs, the freeze save,
/// the burnout downer, and the rise from the ashes. Each has its own
/// distinct pacing and palette.
struct CelebrationOverlayView: View {
    @Environment(BlazeEngine.self) private var engine
    let event: CelebrationEvent

    @State private var appeared = false
    @State private var burst = false

    var body: some View {
        ZStack {
            backdrop.ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()
                avatar
                    .scaleEffect(appeared ? 1 : 0.6)
                    .opacity(appeared ? 1 : 0)
                textBlock
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                Spacer()
                dismissButton
                    .opacity(appeared ? 1 : 0)
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 32)

            if isTriumphant {
                EmberBurstView(trigger: burst, particleCount: 44, duration: 1.8)
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            withAnimation(.spring(duration: animationDuration, bounce: isTriumphant ? 0.4 : 0.1)) {
                appeared = true
            }
            if isTriumphant {
                burst = true
            }
        }
    }

    private var isTriumphant: Bool {
        switch event {
        case .milestone, .revival, .perfectDay: return true
        case .burnout, .freezeUsed: return false
        }
    }

    /// Burnout is deliberately slow — the loss should land.
    private var animationDuration: Double {
        switch event {
        case .burnout: return 1.4
        case .freezeUsed: return 0.9
        default: return 0.6
        }
    }

    private var backdrop: some View {
        Group {
            switch event {
            case .freezeUsed:
                LinearGradient(colors: [Color(hex: 0x0A1A26), Color(hex: 0x123243)],
                               startPoint: .top, endPoint: .bottom)
            case .burnout:
                LinearGradient(colors: [Color(hex: 0x0D0D10), Color(hex: 0x1C1A22)],
                               startPoint: .top, endPoint: .bottom)
            default:
                RadialGradient(colors: [Color(hex: 0x2A1505), Color(hex: 0x0E0A06)],
                               center: .center, startRadius: 40, endRadius: 500)
            }
        }
        .opacity(0.98)
    }

    @ViewBuilder
    private var avatar: some View {
        switch event {
        case .milestone(_, let tier):
            BlazeAvatarView(state: .thriving, tier: tier,
                            flameColorID: engine.profile.equippedFlameColorID,
                            skinID: engine.profile.equippedSkinID,
                            size: 260)
                .warmGlow(radius: 40)
        case .revival:
            BlazeAvatarView(state: .rising, tier: engine.profile.growthTier,
                            flameColorID: engine.profile.equippedFlameColorID,
                            skinID: engine.profile.equippedSkinID,
                            size: 260)
                .warmGlow(radius: 40)
        case .burnout:
            BlazeAvatarView(state: .burnedOut, tier: engine.profile.growthTier,
                            size: 240)
        case .freezeUsed:
            BlazeAvatarView(state: .frozen, tier: engine.profile.growthTier,
                            size: 240)
                .shadow(color: BlazeTheme.freeze.opacity(0.5), radius: 30)
        case .perfectDay:
            BlazeAvatarView(state: .thriving, tier: engine.profile.growthTier,
                            flameColorID: engine.profile.equippedFlameColorID,
                            skinID: engine.profile.equippedSkinID,
                            size: 250)
                .warmGlow(radius: 36)
        }
    }

    @ViewBuilder
    private var textBlock: some View {
        switch event {
        case .milestone(let days, let tier):
            VStack(spacing: 10) {
                Text("\(days)-DAY STREAK")
                    .font(.rounded(34, .heavy))
                    .foregroundStyle(BlazeTheme.flameGradient)
                Text("Blaze evolved into \(tier.title)!")
                    .font(.blazeHeadline)
                    .foregroundStyle(.white)
                Text(tier.subtitle)
                    .font(.blazeBody)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        case .revival:
            VStack(spacing: 10) {
                Text("RISEN FROM THE ASHES")
                    .font(.rounded(28, .heavy))
                    .foregroundStyle(BlazeTheme.flameGradient)
                Text("The fire is back. Day 1 of the comeback.")
                    .font(.blazeBody)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        case .burnout:
            VStack(spacing: 10) {
                Text("The fire went out")
                    .font(.rounded(28, .bold))
                    .foregroundStyle(BlazeTheme.ash)
                Text("The streak is gone… but the ashes are warm. One quest brings Blaze back to life.")
                    .font(.blazeBody)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        case .freezeUsed(let remaining):
            VStack(spacing: 10) {
                Text("Streak freeze used")
                    .font(.rounded(28, .bold))
                    .foregroundStyle(BlazeTheme.freeze)
                Text("Yesterday slipped by, so a freeze kept the streak alive. \(remaining) left. Blaze is safe in his cocoon — wake him with a quest.")
                    .font(.blazeBody)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
        case .perfectDay(let freezeGranted):
            VStack(spacing: 10) {
                Text("PERFECT DAY")
                    .font(.rounded(32, .heavy))
                    .foregroundStyle(BlazeTheme.flameGradient)
                Text("All three quests. +25 embers, +40 XP.")
                    .font(.blazeHeadline)
                    .foregroundStyle(.white)
                if freezeGranted {
                    Label("Bonus: +1 streak freeze!", systemImage: "snowflake")
                        .font(.blazeHeadline)
                        .foregroundStyle(BlazeTheme.freeze)
                }
            }
        }
    }

    private var dismissButton: some View {
        Button {
            engine.dismissCelebration()
        } label: {
            Text(dismissLabel)
                .font(.blazeHeadline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isTriumphant
                              ? AnyShapeStyle(BlazeTheme.flameGradient)
                              : AnyShapeStyle(Color.white.opacity(0.12)))
                )
        }
        .buttonStyle(.plain)
    }

    private var dismissLabel: String {
        switch event {
        case .milestone:  return "Keep burning"
        case .revival:    return "Let's go"
        case .burnout:    return "I'll be back"
        case .freezeUsed: return "Phew"
        case .perfectDay: return "See you tomorrow"
        }
    }
}
