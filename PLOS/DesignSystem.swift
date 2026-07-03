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

        // MARK: Extended tokens (mapped from previously-inline hex literals — same values)
        // Shadows / floating orb (SharedViews)
        static let shadow      = Color(hex: 0x263A2C)
        static let orbShadow   = Color(hex: 0x182A20)
        static let orbCore     = Color(hex: 0x0E1A14)
        static let orbHi       = Color(hex: 0x22322B)
        static let orbLo       = Color(hex: 0x12201A)
        // Teal / info text
        static let teal        = Color(hex: 0x436670)
        // Amber ink (reasoning tags, health text)
        static let amberInk    = Color(hex: 0x8A6420)
        // Slate (flex-rest / cool) family
        static let slateInk     = Color(hex: 0x37545C)
        static let slateText    = Color(hex: 0x5C7C84)
        static let slateMuted   = Color(hex: 0x6F8F97)
        static let slateLine    = Color(hex: 0xD3E3E5)
        static let slateOrb1    = Color(hex: 0xDCECEE)
        static let slateOrbEdge = Color(hex: 0xCFE3E5)
        static let slateShadow  = Color(hex: 0x467882)
        static let slateDash    = Color(hex: 0xB9CFD3)
        static let slateBg1     = Color(hex: 0xF4F8F8)
        static let slateBg2     = Color(hex: 0xE8F0F1)
        static let slateChipBg  = Color(hex: 0xE2EFF0)
        // Clay (rhythm-rest / warm) family
        static let clayInk      = Color(hex: 0x5A4A2E)
        static let clayInkAlt   = Color(hex: 0x7A6034)
        static let clayText     = Color(hex: 0x8A7550)
        static let clayMuted    = Color(hex: 0x9A8865)
        static let clayLine     = Color(hex: 0xECE0CC)
        static let clayOrb1     = Color(hex: 0xF0E2C8)
        static let clayOrb2     = Color(hex: 0xE7D6B6)
        static let clayOrbEdge  = Color(hex: 0xE6D5B4)
        static let clayShadow   = Color(hex: 0x967846)
        static let clayBg1      = Color(hex: 0xFAF6EE)
        static let clayBg2      = Color(hex: 0xF2EAD9)
        static let clayChipBg   = Color(hex: 0xF6EEDD)
        static let clayChipEdge = Color(hex: 0xE6DAC6)
        static let sand         = Color(hex: 0xECDFBE)
        // Periwinkle (low-energy) family
        static let periInk      = Color(hex: 0x4F5399)
        static let periChipBg   = Color(hex: 0xDCDEF3)
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
