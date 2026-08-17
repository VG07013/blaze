import SwiftUI
import SwiftData

/// Spend embers on common cosmetics and streak freezes. Rare and
/// milestone items are shown as earn-only so the exclusives stay exclusive.
struct ShopView: View {
    @Environment(BlazeEngine.self) private var engine
    @Query(sort: \CosmeticItem.price) private var items: [CosmeticItem]

    @State private var purchaseResult: String?

    var body: some View {
        NavigationStack {
            ZStack {
                BlazeBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        balanceHeader
                        freezeCard

                        let purchasable = items.filter { $0.isPurchasable && !$0.owned }
                        let ownedPurchased = items.filter { $0.isPurchasable && $0.owned }

                        if purchasable.isEmpty && ownedPurchased.isEmpty {
                            emptyState
                        } else {
                            if !purchasable.isEmpty {
                                section("For sale", purchasable)
                            }
                            if !ownedPurchased.isEmpty {
                                section("Owned", ownedPurchased)
                            }
                        }

                        earnMoreHint
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Ember Shop")
            .toolbarTitleDisplayMode(.inline)
            .alert("Shop", isPresented: .init(
                get: { purchaseResult != nil },
                set: { if !$0 { purchaseResult = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(purchaseResult ?? "")
            }
        }
    }

    private var balanceHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "flame.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(BlazeTheme.ember)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(engine.profile.emberBalance)")
                    .font(.rounded(30, .heavy))
                    .contentTransition(.numericText(value: Double(engine.profile.emberBalance)))
                Text("embers to spend")
                    .font(.blazeCaption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(18)
        .blazeCard()
    }

    private var freezeCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "snowflake")
                .font(.system(size: 30))
                .foregroundStyle(BlazeTheme.freeze)
            VStack(alignment: .leading, spacing: 3) {
                Text("Streak Freeze")
                    .font(.blazeHeadline)
                Text("Covers a missed day automatically. Holding \(engine.profile.freezesHeld)/\(BlazeEngine.maxFreezes).")
                    .font(.blazeCaption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                if engine.profile.freezesHeld >= BlazeEngine.maxFreezes {
                    purchaseResult = "You're already holding the maximum of \(BlazeEngine.maxFreezes) freezes."
                } else if engine.buyFreeze() {
                    HapticsService.shared.questComplete()
                    purchaseResult = "Freeze banked. Blaze sleeps easier already. 🧊"
                } else {
                    purchaseResult = "Not enough embers — freezes cost \(BlazeEngine.freezePrice)."
                }
            } label: {
                Text("\(BlazeEngine.freezePrice)")
                    .font(.rounded(15, .bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(BlazeTheme.freeze.opacity(0.2)))
                    .foregroundStyle(BlazeTheme.freeze)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .blazeCard()
    }

    private func section(_ title: String, _ sectionItems: [CosmeticItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.blazeHeadline)
            ForEach(sectionItems, id: \.itemID) { item in
                shopRow(item)
            }
        }
    }

    private func shopRow(_ item: CosmeticItem) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.name).font(.blazeHeadline)
                    Text(item.category.displayName)
                        .font(.rounded(11, .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(BlazeTheme.ember.opacity(0.15)))
                        .foregroundStyle(BlazeTheme.ember)
                }
                Text(item.detail)
                    .font(.blazeCaption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if item.owned {
                Label("Owned", systemImage: "checkmark")
                    .font(.blazeCaption)
                    .foregroundStyle(BlazeTheme.success)
            } else {
                Button {
                    if engine.purchase(item) {
                        HapticsService.shared.questComplete()
                        purchaseResult = "\(item.name) is yours! Equip it on the Blaze tab."
                    } else {
                        purchaseResult = "Not enough embers — \(item.name) costs \(item.price)."
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.circle.fill")
                        Text("\(item.price)")
                    }
                    .font(.rounded(15, .bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(BlazeTheme.ember.opacity(0.18)))
                    .foregroundStyle(BlazeTheme.ember)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .blazeCard(cornerRadius: 16)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bag")
                .font(.system(size: 40))
                .foregroundStyle(BlazeTheme.ash)
            Text("The shop is warming up")
                .font(.blazeHeadline)
            Text("Complete quests to earn embers, then come back for flames and feathers.")
                .font(.blazeCaption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .blazeCard()
    }

    private var earnMoreHint: some View {
        VStack(spacing: 6) {
            Text("Need more embers?")
                .font(.blazeHeadline)
            Text("Every quest pays out, perfect days pay extra, and Health-verified quests earn a bonus. Milestone cosmetics can't be bought at any price — those you earn with fire.")
                .font(.blazeCaption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .blazeCard()
    }
}
