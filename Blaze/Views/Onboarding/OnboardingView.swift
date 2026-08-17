import SwiftUI

/// Warm five-step intro: Blaze hatches, the loop is explained, Health and
/// notification permissions are asked with honest framing, and a quick
/// fitness question seeds quest difficulty.
struct OnboardingView: View {
    @Environment(BlazeEngine.self) private var engine
    @Environment(\.colorScheme) private var scheme

    @State private var step = 0
    @State private var hatched = false
    @State private var reminderTime = Calendar.current.date(
        bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
    @State private var fitnessLevel = 1

    var body: some View {
        ZStack {
            BlazeTheme.background(for: "theme.hearth", scheme: scheme).ignoresSafeArea()
            BlazeTheme.backgroundWash(scheme: scheme).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                Group {
                    switch step {
                    case 0: hatchStep
                    case 1: loopStep
                    case 2: healthStep
                    case 3: notificationStep
                    default: fitnessStep
                    }
                }
                .frame(maxWidth: .infinity)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))

                Spacer()

                progressDots
                    .padding(.bottom, 28)
            }
            .padding(.horizontal, 28)
        }
        .animation(.spring(duration: 0.5), value: step)
    }

    // MARK: Steps

    private var hatchStep: some View {
        VStack(spacing: 20) {
            ZStack {
                if hatched {
                    BlazeAvatarView(state: .thriving, tier: .spark, size: 230)
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                } else {
                    // The egg
                    Ellipse()
                        .fill(LinearGradient(colors: [Color(hex: 0xF6E3C5), Color(hex: 0xD9B98E)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 130, height: 165)
                        .overlay(
                            Ellipse().strokeBorder(BlazeTheme.ember.opacity(0.5), lineWidth: 2)
                        )
                        .warmGlow(radius: 30)
                }
            }
            .frame(height: 250)

            Text(hatched ? "I'm Blaze!" : "Something's stirring…")
                .font(.blazeTitle)
            Text(hatched
                 ? "A phoenix, technically. I run on your workouts — every day you move, I burn brighter."
                 : "Tap the egg to meet your new training partner.")
                .font(.blazeBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if hatched {
                primaryButton("Nice to meet you") { step = 1 }
            } else {
                primaryButton("Tap the egg 🥚") {
                    withAnimation(.spring(duration: 0.6, bounce: 0.4)) { hatched = true }
                    HapticsService.shared.celebrate()
                }
            }
        }
    }

    private var loopStep: some View {
        VStack(spacing: 18) {
            BlazeAvatarView(state: .waiting, tier: .spark, size: 150)
            Text("How this works").font(.blazeTitle)

            VStack(alignment: .leading, spacing: 14) {
                loopRow(icon: "scroll.fill", text: "Every day you get 3 quests — movement, strength, stretching, or a wildcard.")
                loopRow(icon: "flame.fill", text: "Finish any 1 quest and your streak climbs. Finish all 3 for bonus embers.")
                loopRow(icon: "snowflake", text: "Streak freezes cover a missed day automatically. Earn them; hold up to 3.")
                loopRow(icon: "bird.fill", text: "I grow with your streak. Miss too long and I burn out — but I can always rise again.")
            }
            .padding(20)
            .blazeCard()

            primaryButton("Got it") { step = 2 }
        }
    }

    private var healthStep: some View {
        VStack(spacing: 18) {
            Image(systemName: "heart.fill")
                .font(.system(size: 56))
                .foregroundStyle(BlazeTheme.flameGradient)
                .warmGlow(radius: 18)
            Text("Let quests complete themselves").font(.blazeTitle)
            Text("With Health access I can see your steps, exercise minutes, stairs, calories, and mindful minutes — so movement quests check off on their own. I only read, never write, and nothing leaves your phone.")
                .font(.blazeBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            primaryButton("Connect Health") {
                Task {
                    await engine.requestHealthAccess()
                    step = 3
                }
            }
            skipButton { step = 3 }
        }
    }

    private var notificationStep: some View {
        VStack(spacing: 18) {
            BlazeAvatarView(state: .worried, tier: .spark, size: 150)
            Text("So I can remind you").font(.blazeTitle)
            Text("I'll nudge you when quests are fresh and warn you when the streak's in danger. Short, in my voice, never spammy — and you control the timing.")
                .font(.blazeBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            DatePicker("Daily reminder", selection: $reminderTime, displayedComponents: .hourAndMinute)
                .font(.blazeHeadline)
                .padding(16)
                .blazeCard()

            primaryButton("Enable reminders") {
                Task {
                    _ = await engine.requestNotificationAccess()
                    step = 4
                }
            }
            skipButton { step = 4 }
        }
    }

    private var fitnessStep: some View {
        VStack(spacing: 18) {
            BlazeAvatarView(state: .thriving, tier: .spark, size: 150)
            Text("How fired up are you?").font(.blazeTitle)
            Text("This just sets your starting quest difficulty. It adapts as you go.")
                .font(.blazeBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                fitnessOption(0, "Easing in", "Short walks, gentle targets")
                fitnessOption(1, "Steady", "Regular movement, fair targets")
                fitnessOption(2, "Fierce", "Bring the heat")
            }

            primaryButton("Light the fire 🔥") {
                engine.completeOnboarding(
                    fitnessLevel: fitnessLevel,
                    reminderMinutes: reminderTime.minutesIntoDay
                )
            }
        }
    }

    // MARK: Bits

    private func loopRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(BlazeTheme.ember)
                .frame(width: 26)
            Text(text).font(.blazeBody)
        }
    }

    private func fitnessOption(_ level: Int, _ title: String, _ subtitle: String) -> some View {
        Button {
            fitnessLevel = level
            HapticsService.shared.tap()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.blazeHeadline)
                    Text(subtitle).font(.blazeCaption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: fitnessLevel == level ? "flame.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(fitnessLevel == level ? BlazeTheme.flameOrange : BlazeTheme.ash)
            }
            .padding(16)
            .blazeCard(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.blazeHeadline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(BlazeTheme.flameGradient)
                )
                .warmGlow(radius: 14)
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
    }

    private func skipButton(action: @escaping () -> Void) -> some View {
        Button("Maybe later", action: action)
            .font(.blazeCaption)
            .foregroundStyle(.secondary)
    }

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(i == step ? BlazeTheme.flameOrange : BlazeTheme.ash.opacity(0.4))
                    .frame(width: 8, height: 8)
            }
        }
    }
}
