import SwiftUI

/// Design tokens extracted from Claude Design Handoff Bundle.
/// ALL colors, fonts, spacing, and radii used in the app must reference these constants.
/// No hex values, no magic numbers in view code — this is a hard acceptance gate.

// MARK: - Color(hex:) extension

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

// MARK: - PLOS Design Tokens

enum PLOS {

    // MARK: Colors

    enum Palette {
        /// Page / desk background
        static let canvas   = Color(hex: 0xE8ECE3)
        /// Screen background
        static let paper    = Color(hex: 0xF6F8F2)
        /// Cards
        static let surface  = Color(hex: 0xFFFFFF)
        /// Inset fields, number chips
        static let surface2 = Color(hex: 0xEFF3EA)

        /// Primary text
        static let ink      = Color(hex: 0x26302A)
        /// Secondary text
        static let ink2     = Color(hex: 0x586159)
        /// Tertiary / captions
        static let ink3     = Color(hex: 0x8C958B)
        /// Borders / dividers
        static let hairline = Color(hex: 0xE5EADF)

        // Brand green scale
        static let g50  = Color(hex: 0xEFF5F0)
        static let g100 = Color(hex: 0xDDEAE0)
        static let g200 = Color(hex: 0xBFD8C6)
        static let g300 = Color(hex: 0x98C0A5)
        static let g400 = Color(hex: 0x6FA381)
        static let g500 = Color(hex: 0x4E8262)  // PRIMARY
        static let g600 = Color(hex: 0x3D6B4F)
        static let g700 = Color(hex: 0x30553F)
        static let g800 = Color(hex: 0x274633)

        // Semantic accents — NO red, ever
        /// High energy · gentle warning
        static let amber     = Color(hex: 0xB4842F)
        static let amberBg   = Color(hex: 0xF7EFD8)
        /// Low-energy day
        static let peri      = Color(hex: 0x7A80C4)
        static let periBg    = Color(hex: 0xECEDF8)
        /// Scheduled rest day
        static let clay      = Color(hex: 0xA2825C)
        static let clayBg    = Color(hex: 0xF1E9DB)
        /// Flex rest day · info
        static let slate     = Color(hex: 0x5F8B98)
        static let slateBg   = Color(hex: 0xE7F0F1)
        /// Health banner
        static let warn      = Color(hex: 0xA9802F)
        static let warnBg    = Color(hex: 0xF8EFD6)
    }

    // MARK: Typography

    enum FontScale {
        static let caption2: CGFloat = 11
        static let caption: CGFloat  = 12.5
        static let footnote: CGFloat = 13.5
        static let body: CGFloat     = 15
        static let reasoning: CGFloat = 15.5
        static let subject: CGFloat  = 16
        static let button: CGFloat   = 16
        static let title: CGFloat    = 23
        static let statMedium: CGFloat = 26
        static let statLarge: CGFloat  = 28
        static let statHero: CGFloat   = 34
    }

    enum FontWeight {
        static func cn(_ size: CGFloat, _ weight: SwiftUI.Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight)
        }
        static func num(_ size: CGFloat, _ weight: SwiftUI.Font.Weight = .bold) -> Font {
            .system(size: size, weight: weight, design: .rounded)
        }
    }

    enum LineHeight {
        static let tight: CGFloat    = 1.25
        static let body: CGFloat     = 1.65
        static let reasoning: CGFloat = 1.78
    }

    // MARK: Spacing

    enum Spacing {
        static let xs: CGFloat   = 5
        static let sm: CGFloat   = 10
        static let md: CGFloat   = 14
        static let lg: CGFloat   = 17
        static let xl: CGFloat   = 22
        static let page: CGFloat = 22
    }

    // MARK: Radius

    enum Radius {
        static let sm: CGFloat   = 10
        static let md: CGFloat   = 14
        static let lg: CGFloat   = 20
        static let card: CGFloat = 26
        static let pill: CGFloat = 999
    }

    // MARK: Sizes

    enum Size {
        static let primaryButtonHeight: CGFloat   = 54
        static let secondaryButtonHeight: CGFloat = 50
        static let taskIndexBox: CGFloat          = 27
        static let completionRing: CGFloat        = 24
        static let minTapTarget: CGFloat          = 44
    }

    // MARK: Gradients

    enum Gradients {
        static let reasoning = LinearGradient(
            colors: [Palette.g50, Color(hex: 0xE5F0E8)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}
