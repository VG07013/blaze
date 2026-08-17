import Foundation
import SwiftData

/// The full cosmetics catalog. Seeded into SwiftData on first launch;
/// commons are ember-purchasable, rare/milestone items unlock only
/// through play and are never for sale.
enum CosmeticsCatalog {

    static func makeAll() -> [CosmeticItem] {
        [
            // MARK: Flame colors
            CosmeticItem(itemID: "flame.classic", name: "Heartfire",
                         detail: "The original orange-gold burn.",
                         category: .flameColor, rarity: .common, isStarter: true),
            CosmeticItem(itemID: "flame.azure", name: "Azure Flame",
                         detail: "Cool blue fire with an electric core.",
                         category: .flameColor, rarity: .common, price: 250),
            CosmeticItem(itemID: "flame.violet", name: "Violet Flame",
                         detail: "Royal purple with a lilac shimmer.",
                         category: .flameColor, rarity: .common, price: 250),
            CosmeticItem(itemID: "flame.verdant", name: "Verdant Flame",
                         detail: "Emerald fire, alive and strange.",
                         category: .flameColor, rarity: .common, price: 250),
            CosmeticItem(itemID: "flame.rainbow", name: "Prism Flame",
                         detail: "Every color at once. Earned, never bought.",
                         category: .flameColor, rarity: .milestone, unlockStreak: 100),
            CosmeticItem(itemID: "flame.aurora", name: "Aurora Flame",
                         detail: "The northern lights, kept alive for a year.",
                         category: .flameColor, rarity: .milestone, unlockStreak: 365),

            // MARK: Plumage skins
            CosmeticItem(itemID: "skin.classic", name: "Classic Plumage",
                         detail: "Blaze as he hatched: warm orange feathers.",
                         category: .blazeSkin, rarity: .common, isStarter: true),
            CosmeticItem(itemID: "skin.golden", name: "Gilded Crest",
                         detail: "Feathers dipped in molten gold.",
                         category: .blazeSkin, rarity: .common, price: 400),
            CosmeticItem(itemID: "skin.midnight", name: "Midnight Feathers",
                         detail: "A dusk-blue coat that loves the dark.",
                         category: .blazeSkin, rarity: .common, price: 300),
            CosmeticItem(itemID: "skin.obsidian", name: "Obsidian Phoenix",
                         detail: "Volcanic glass plumage from a month of fire.",
                         category: .blazeSkin, rarity: .milestone, unlockStreak: 30),
            CosmeticItem(itemID: "skin.solar", name: "Solar Sovereign",
                         detail: "One hundred days earns the light of a small sun.",
                         category: .blazeSkin, rarity: .milestone, unlockStreak: 100),
            CosmeticItem(itemID: "skin.eternal", name: "Eternal Firebird",
                         detail: "The 365-day form. Almost nobody ever sees it.",
                         category: .blazeSkin, rarity: .milestone, unlockStreak: 365),

            // MARK: App themes
            CosmeticItem(itemID: "theme.hearth", name: "Hearth",
                         detail: "Charcoal warmed by firelight.",
                         category: .appTheme, rarity: .common, isStarter: true),
            CosmeticItem(itemID: "theme.twilight", name: "Twilight",
                         detail: "A plum-dark sky for the night owls.",
                         category: .appTheme, rarity: .common, price: 200),
            CosmeticItem(itemID: "theme.dawn", name: "First Light",
                         detail: "Earned by a hundred quests at any pace.",
                         category: .appTheme, rarity: .rare, unlockQuests: 100),

            // MARK: App icons
            CosmeticItem(itemID: "icon.primary", name: "Blaze Icon",
                         detail: "The flame on your home screen.",
                         category: .appIcon, rarity: .common, isStarter: true),
            CosmeticItem(itemID: "icon.ember", name: "Ember Icon",
                         detail: "Deep-red flame for a week of fire.",
                         category: .appIcon, rarity: .milestone, unlockStreak: 7),
            CosmeticItem(itemID: "icon.inferno", name: "Inferno Icon",
                         detail: "Blue-white heat for a 30-day streak.",
                         category: .appIcon, rarity: .milestone, unlockStreak: 30),
        ]
    }

    /// Alternate-icon asset name for an app-icon cosmetic (nil = primary icon).
    static func iconAssetName(for itemID: String) -> String? {
        switch itemID {
        case "icon.ember":   return "AppIconEmber"
        case "icon.inferno": return "AppIconInferno"
        default:             return nil
        }
    }
}
