import SwiftUI
import SwiftData

/// Blaze's dressing room: current form, growth progress, and every
/// cosmetic with its unlock condition.
struct CosmeticsView: View {
    @Environment(BlazeEngine.self) private var engine
    @Query(sort: \CosmeticItem.price) private var items: [CosmeticItem]

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack {
                BlazeBackground()

                ScrollView {
                    VStack(spacing: 22) {
                        // Blaze preview with equipped cosmetics
                        VStack(spacing: 8) {
                            BlazeAvatarView(
                                state: engine.blazeState.isDormant ? engine.blazeState : .thriving,
                                tier: engine.profile.growthTier,
                                flameColorID: engine.profile.equippedFlameColorID,
                                skinID: engine.profile.equippedSkinID,
                                size: 220
                            )
                            .warmGlow(radius: 26)

                            Text(engine.profile.growthTier.title)
                                .font(.blazeTitle)
                            Text(engine.profile.growthTier.subtitle)
                                .font(.blazeCaption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        growthCard

                        ForEach(CosmeticCategory.allCases, id: \.self) { category in
                            categorySection(category)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Blaze")
            .toolbarTitleDisplayMode(.inline)
        }
    }

    // MARK: Growth progress

    private var growthCard: some View {
        let tier = engine.profile.growthTier
        let levelInfo = UserProfile.levelInfo(forXP: engine.profile.xp)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Level \(levelInfo.level)", systemImage: "arrow.up.circle.fill")
                    .font(.blazeHeadline)
                    .foregroundStyle(BlazeTheme.flameGold)
                Spacer()
                Text("\(levelInfo.into)/\(levelInfo.needed) XP")
                    .font(.blazeCaption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(levelInfo.into), total: Double(levelInfo.needed))
                .tint(BlazeTheme.ember)

            if let hint = tier.nextTierHint {
                Text("Next form: \(hint)")
                    .font(.blazeCaption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Final form reached. You are the fire now.")
                    .font(.blazeCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .blazeCard()
    }

    // MARK: Cosmetic grid

    private func categorySection(_ category: CosmeticCategory) -> some View {
        let categoryItems = items.filter { $0.category == category }
        return VStack(alignment: .leading, spacing: 12) {
            Text(category.displayName)
                .font(.blazeHeadline)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(categoryItems, id: \.itemID) { item in
                    CosmeticCell(item: item)
                }
            }
        }
    }
}

struct CosmeticCell: View {
    @Environment(BlazeEngine.self) private var engine
    let item: CosmeticItem

    var body: some View {
        Button {
            if item.owned {
                HapticsService.shared.tap()
                engine.equip(item)
            }
        } label: {
            VStack(spacing: 8) {
                preview
                    .frame(height: 56)

                Text(item.name)
                    .font(.rounded(14, .semibold))
                    .lineLimit(1)

                if engine.isEquipped(item) {
                    Label("Equipped", systemImage: "checkmark")
                        .font(.blazeCaption)
                        .foregroundStyle(BlazeTheme.success)
                } else if item.owned {
                    Text("Tap to equip")
                        .font(.blazeCaption)
                        .foregroundStyle(.secondary)
                } else {
                    Label(item.unlockDescription, systemImage: lockIcon)
                        .font(.blazeCaption)
                        .foregroundStyle(item.rarity == .milestone ? BlazeTheme.ember : .secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .blazeCard(cornerRadius: 16)
            .opacity(item.owned ? 1 : 0.65)
        }
        .buttonStyle(.plain)
    }

    private var lockIcon: String {
        item.isPurchasable ? "flame.circle.fill" : "lock.fill"
    }

    @ViewBuilder
    private var preview: some View {
        switch item.category {
        case .flameColor:
            LayeredFlame(colors: BlazeTheme.flameColors(for: item.itemID))
                .frame(width: 40, height: 54)
        case .blazeSkin:
            let skin = BlazeTheme.skinColors(for: item.itemID)
            Circle()
                .fill(LinearGradient(colors: skin.body, startPoint: .top, endPoint: .bottom))
                .frame(width: 48, height: 48)
                .overlay(Circle().strokeBorder(skin.accent.opacity(0.7), lineWidth: 2))
        case .appTheme:
            RoundedRectangle(cornerRadius: 10)
                .fill(BlazeTheme.background(for: item.itemID, scheme: .dark))
                .frame(width: 60, height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(BlazeTheme.ember.opacity(0.4), lineWidth: 1.5)
                )
        case .appIcon:
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: iconColors, startPoint: .top, endPoint: .bottom))
                .frame(width: 48, height: 48)
                .overlay(
                    FlameShape()
                        .fill(.white.opacity(0.9))
                        .frame(width: 20, height: 28)
                )
        }
    }

    private var iconColors: [Color] {
        switch item.itemID {
        case "icon.ember":   return [Color(hex: 0x8F1D0E), Color(hex: 0xE6541A)]
        case "icon.inferno": return [Color(hex: 0x24308F), Color(hex: 0x4FD9FF)]
        default:             return [BlazeTheme.flameOrange, BlazeTheme.flameGold]
        }
    }
}
