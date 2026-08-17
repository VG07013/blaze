import SwiftUI

/// The hearth. Blaze front and center reacting to your streak, the flame
/// counter, three quest cards, freezes and embers at a glance.
struct HomeView: View {
    @Environment(BlazeEngine.self) private var engine
    @State private var selectedQuest: Quest?

    var body: some View {
        NavigationStack {
            ZStack {
                BlazeBackground()

                ScrollView {
                    VStack(spacing: 22) {
                        header

                        StreakFlameView(
                            streak: engine.profile.streakCount,
                            flameColorID: engine.profile.equippedFlameColorID,
                            state: engine.blazeState
                        )
                        .padding(.top, 2)

                        // Blaze himself
                        VStack(spacing: 10) {
                            BlazeAvatarView(
                                state: engine.blazeState,
                                tier: engine.profile.growthTier,
                                flameColorID: engine.profile.equippedFlameColorID,
                                skinID: engine.profile.equippedSkinID,
                                size: 240
                            )
                            .warmGlow(
                                engine.blazeState == .frozen ? BlazeTheme.freeze : BlazeTheme.flameOrange,
                                radius: engine.blazeState.isDormant ? 8 : 30
                            )

                            Text(engine.currentSpeech)
                                .font(.blazeBody)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                                .contentTransition(.opacity)
                        }

                        questSection

                        if engine.questsDoneToday >= 3 {
                            perfectDayBanner
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Blaze")
            .toolbarTitleDisplayMode(.inline)
            .task {
                await engine.refreshHealthProgress()
            }
            .refreshable {
                await engine.refreshHealthProgress()
            }
            .sheet(item: $selectedQuest) { quest in
                QuestDetailView(quest: quest)
                    .presentationDetents([.large])
            }
        }
    }

    // MARK: Header chips

    private var header: some View {
        HStack {
            // Ember balance
            HStack(spacing: 6) {
                Image(systemName: "flame.circle.fill")
                    .foregroundStyle(BlazeTheme.ember)
                Text("\(engine.profile.emberBalance)")
                    .font(.rounded(16, .bold))
                    .contentTransition(.numericText(value: Double(engine.profile.emberBalance)))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .blazeCard(cornerRadius: 14)

            Spacer()

            // Freeze slots
            HStack(spacing: 5) {
                ForEach(0..<BlazeEngine.maxFreezes, id: \.self) { i in
                    Image(systemName: "snowflake")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(
                            i < engine.profile.freezesHeld
                                ? BlazeTheme.freeze
                                : BlazeTheme.ash.opacity(0.35)
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .blazeCard(cornerRadius: 14)
        }
    }

    // MARK: Quests

    private var questSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Quests")
                    .font(.blazeTitle)
                Spacer()
                questRing
            }

            if engine.todayQuests.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "hourglass")
                        .font(.title)
                        .foregroundStyle(BlazeTheme.ash)
                    Text("Quests are being kindled…")
                        .font(.blazeBody)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(30)
                .blazeCard()
            } else {
                ForEach(engine.todayQuests, id: \.id) { quest in
                    QuestCardView(quest: quest) {
                        selectedQuest = quest
                    }
                }
            }

            Text("Complete any 1 quest to keep the streak · all 3 for bonus embers")
                .font(.blazeCaption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
        }
    }

    private var questRing: some View {
        ZStack {
            Circle()
                .stroke(BlazeTheme.ash.opacity(0.25), lineWidth: 5)
            Circle()
                .trim(from: 0, to: Double(engine.questsDoneToday) / 3.0)
                .stroke(BlazeTheme.flameGradient, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.6), value: engine.questsDoneToday)
            Text("\(engine.questsDoneToday)/3")
                .font(.rounded(12, .bold))
        }
        .frame(width: 44, height: 44)
    }

    private var perfectDayBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(BlazeTheme.flameGold)
            VStack(alignment: .leading, spacing: 2) {
                Text("Perfect day!")
                    .font(.blazeHeadline)
                Text("All three quests done. Tomorrow's quests arrive at midnight — Blaze will be waiting.")
                    .font(.blazeCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .blazeCard()
    }
}
