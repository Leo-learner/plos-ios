import SwiftUI

// PLOS Design Tokens — generated from PLOS Phase D design canvas.
// Naming mirrors the CSS custom properties in the design file (--g-500 → Palette.g500).

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

enum PLOS {

    // MARK: - Colors
    enum Palette {
        // Backgrounds
        static let canvas   = Color(hex: 0xE8ECE3) // page/desk background
        static let paper    = Color(hex: 0xF6F8F2) // screen background
        static let surface  = Color(hex: 0xFFFFFF) // cards
        static let surface2 = Color(hex: 0xEFF3EA) // inset fields, number chips

        // Ink (text)
        static let ink      = Color(hex: 0x26302A) // primary text
        static let ink2     = Color(hex: 0x586159) // secondary text
        static let ink3     = Color(hex: 0x8C958B) // tertiary/captions
        static let hairline = Color(hex: 0xE5EADF) // borders/dividers

        // Brand green scale
        static let g50  = Color(hex: 0xEFF5F0)
        static let g100 = Color(hex: 0xDDEAE0)
        static let g200 = Color(hex: 0xBFD8C6)
        static let g300 = Color(hex: 0x98C0A5)
        static let g400 = Color(hex: 0x6FA381)
        static let g500 = Color(hex: 0x4E8262) // PRIMARY
        static let g600 = Color(hex: 0x3D6B4F)
        static let g700 = Color(hex: 0x30553F)
        static let g800 = Color(hex: 0x274633)

        // Semantic accents (NO red anywhere in the system)
        static let amber     = Color(hex: 0xB4842F) // high energy · gentle warning
        static let amberBg   = Color(hex: 0xF7EFD8)
        static let amberText = Color(hex: 0x8A6420)
        static let peri      = Color(hex: 0x7A80C4) // low-energy day
        static let periBg    = Color(hex: 0xECEDF8)
        static let periText  = Color(hex: 0x4F5399)
        static let clay      = Color(hex: 0xA2825C) // scheduled rest day
        static let clayBg    = Color(hex: 0xF1E9DB)
        static let clayText  = Color(hex: 0x7A6034)
        static let slate     = Color(hex: 0x5F8B98) // flex rest day · info
        static let slateBg   = Color(hex: 0xE7F0F1)
        static let slateText = Color(hex: 0x436670)
        static let warn      = Color(hex: 0xA9802F) // health banner
        static let warnBg    = Color(hex: 0xF8EFD6)
        static let info      = Color(hex: 0x5F8B98)
        static let infoBg    = Color(hex: 0xE7F0F1)
    }

    // MARK: - Typography
    // CJK text: PingFang SC (system). Numerals: rounded design + monospaced digits.
    enum Font {
        static func cn(_ size: CGFloat, _ weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .system(size: size, weight: weight)
        }
        /// Numeric style — use .monospacedDigit() on Text as well.
        static func num(_ size: CGFloat, _ weight: SwiftUI.Font.Weight = .bold) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .rounded)
        }

        // Scale (pt)
        static let caption2: CGFloat   = 11
        static let caption: CGFloat    = 12.5
        static let footnote: CGFloat   = 13.5
        static let body: CGFloat       = 15
        static let reasoning: CGFloat  = 15.5  // reasoning card body — never smaller
        static let subject: CGFloat    = 16    // task row subject
        static let button: CGFloat     = 16
        static let title: CGFloat      = 23    // screen titles
        static let statMedium: CGFloat = 26
        static let statLarge: CGFloat  = 28    // budget minutes
        static let statHero: CGFloat   = 34    // baseline days
    }

    enum LineHeight {
        static let tight: CGFloat     = 1.25
        static let body: CGFloat      = 1.65
        static let reasoning: CGFloat = 1.78
    }

    // MARK: - Spacing
    enum Spacing {
        static let xs: CGFloat  = 5
        static let sm: CGFloat  = 10   // between cards
        static let md: CGFloat  = 14   // card padding (compact)
        static let lg: CGFloat  = 17   // card padding (roomy)
        static let xl: CGFloat  = 22   // between groups
        static let page: CGFloat = 22  // horizontal screen inset (20–26)
    }

    // MARK: - Radius
    enum Radius {
        static let sm: CGFloat   = 10
        static let md: CGFloat   = 14
        static let lg: CGFloat   = 20
        static let card: CGFloat = 26
        static let pill: CGFloat = 999
    }

    // MARK: - Sizes
    enum Size {
        static let primaryButtonHeight: CGFloat = 54
        static let secondaryButtonHeight: CGFloat = 50
        static let slideToConfirmHeight: CGFloat = 58
        static let taskIndexBox: CGFloat = 27
        static let completionRing: CGFloat = 24
        static let minTapTarget: CGFloat = 44
    }

    // MARK: - Shadows
    enum Shadow {
        // card: y6 blur20 6% + y1 blur2 5%, tint 38,58,44
        static let cardColor = Color(hex: 0x263A2C, alpha: 0.06)
        static let cardRadius: CGFloat = 10
        static let cardY: CGFloat = 3
        static let popColor = Color(hex: 0x263A2C, alpha: 0.13)
        static let popRadius: CGFloat = 17
        static let popY: CGFloat = 7
    }

    // MARK: - Gradients
    enum Gradients {
        /// Reasoning card background
        static let reasoning = LinearGradient(
            colors: [Palette.g50, Color(hex: 0xE5F0E8)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        /// Health check-in full-screen background (screen 13)
        static let healthCheckIn = LinearGradient(
            colors: [Palette.g500, Palette.g700],
            startPoint: .top, endPoint: .bottom
        )
    }
}
