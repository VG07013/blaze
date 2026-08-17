import SwiftUI

// MARK: - Hex color support

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: 1.0
        )
    }
}

// MARK: - Blaze design system

enum BlazeTheme {

    // Core palette
    static let flameOrange = Color(hex: 0xFF6B1A)
    static let flameGold   = Color(hex: 0xFFC531)
    static let ember       = Color(hex: 0xFFA53C)
    static let ash         = Color(hex: 0x5A5F6E)
    static let freeze      = Color(hex: 0x5AC8FA)
    static let bgDark      = Color(hex: 0x12100E)
    static let bgLight     = Color(hex: 0xFBF6EF)
    static let success     = Color(hex: 0x3ED598)

    /// Primary flame gradient: deep orange into gold-yellow.
    static let flameGradient = LinearGradient(
        colors: [flameGold, flameOrange],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Gradient used to fill flame shapes (dark tip, bright base).
    static func flameFill(_ colors: [Color]) -> LinearGradient {
        LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    // MARK: Flame color cosmetics

    /// Top-to-bottom colors for a flame, keyed by cosmetic ID.
    static func flameColors(for id: String) -> [Color] {
        switch id {
        case "flame.azure":   return [Color(hex: 0x2E7CF6), Color(hex: 0x7FE3FF)]
        case "flame.violet":  return [Color(hex: 0x8A3FFC), Color(hex: 0xD79BFF)]
        case "flame.verdant": return [Color(hex: 0x18A957), Color(hex: 0x9BF6B0)]
        case "flame.rainbow": return [Color(hex: 0xFF4D4D), Color(hex: 0xFF9F1A),
                                      Color(hex: 0xFFE14D), Color(hex: 0x4DE07C),
                                      Color(hex: 0x4DA6FF), Color(hex: 0xB44DFF)]
        case "flame.aurora":  return [Color(hex: 0x38F0C8), Color(hex: 0x7FB2FF), Color(hex: 0xC77FFF)]
        default:              return [flameOrange, flameGold] // "flame.classic"
        }
    }

    // MARK: Skin cosmetics

    /// Body gradient + accent color for a plumage skin, keyed by cosmetic ID.
    static func skinColors(for id: String) -> (body: [Color], accent: Color) {
        switch id {
        case "skin.golden":   return ([Color(hex: 0xFFD75E), Color(hex: 0xE69A17)], Color(hex: 0xFFF0BF))
        case "skin.midnight": return ([Color(hex: 0x59648F), Color(hex: 0x232A44)], Color(hex: 0x9FB0E8))
        case "skin.obsidian": return ([Color(hex: 0x44444F), Color(hex: 0x17171E)], Color(hex: 0xFF7A1A))
        case "skin.solar":    return ([Color(hex: 0xFFE29A), Color(hex: 0xFF7A1A)], Color(hex: 0xFFFBEA))
        case "skin.eternal":  return ([Color(hex: 0xFFF3D6), Color(hex: 0xFFB347)], Color(hex: 0xFFFFFF))
        default:              return ([Color(hex: 0xFF8A3D), Color(hex: 0xE6541A)], Color(hex: 0xFFC07A)) // classic
        }
    }

    // MARK: App theme cosmetics

    /// Background color for a theme cosmetic in a given color scheme.
    static func background(for themeID: String, scheme: ColorScheme) -> Color {
        switch (themeID, scheme) {
        case ("theme.twilight", .dark):  return Color(hex: 0x171022)
        case ("theme.twilight", _):      return Color(hex: 0xF4EFFB)
        case ("theme.dawn", .dark):      return Color(hex: 0x1C130C)
        case ("theme.dawn", _):          return Color(hex: 0xFFF2E2)
        case (_, .dark):                 return bgDark
        default:                         return bgLight
        }
    }

    /// A soft warm radial wash layered over the background so it never reads flat.
    static func backgroundWash(scheme: ColorScheme) -> some View {
        RadialGradient(
            colors: scheme == .dark
                ? [flameOrange.opacity(0.10), .clear]
                : [flameGold.opacity(0.18), .clear],
            center: .top,
            startRadius: 0,
            endRadius: 480
        )
        .allowsHitTesting(false)
    }
}

// MARK: - Rounded typography

extension Font {
    /// The huge streak number — the single biggest thing on the home screen.
    static let blazeStreak = Font.system(size: 72, weight: .heavy, design: .rounded)
    static let blazeTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    static let blazeHeadline = Font.system(size: 19, weight: .semibold, design: .rounded)
    static let blazeBody = Font.system(size: 16, weight: .regular, design: .rounded)
    static let blazeCaption = Font.system(size: 13, weight: .medium, design: .rounded)
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Card chrome

struct BlazeCardStyle: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(scheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        scheme == .dark
                            ? BlazeTheme.ember.opacity(0.14)
                            : BlazeTheme.ember.opacity(0.25),
                        lineWidth: 1
                    )
            )
            .shadow(color: BlazeTheme.flameOrange.opacity(scheme == .dark ? 0.10 : 0.12), radius: 14, y: 6)
    }
}

extension View {
    func blazeCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(BlazeCardStyle(cornerRadius: cornerRadius))
    }

    /// Warm glow used behind Blaze and the streak flame.
    func warmGlow(_ color: Color = BlazeTheme.flameOrange, radius: CGFloat = 24) -> some View {
        shadow(color: color.opacity(0.55), radius: radius)
    }
}
