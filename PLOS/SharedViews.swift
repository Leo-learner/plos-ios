import SwiftUI

// MARK: - PhoneFrame Modifier

/// Wraps content in an iPhone-like frame: dark bezel, rounded screen, paper background,
/// dynamic island notch, and home indicator.
struct PhoneFrame: ViewModifier {
    let hasNotch: Bool = true

    func body(content: Content) -> some View {
        content
            .frame(width: 356, height: 762)
            .background(PLOS.Palette.paper)
            .clipShape(RoundedRectangle(cornerRadius: 36))
            .overlay(alignment: .top) {
                if hasNotch {
                    // Dynamic Island
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: 0x0E1A14))
                        .frame(width: 104, height: 30)
                        .padding(.top, 11)
                }
            }
            .overlay(alignment: .bottom) {
                // Home indicator
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: 0x26302A).opacity(0.22))
                    .frame(width: 128, height: 5)
                    .padding(.bottom, 10)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 46)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x22322B), Color(hex: 0x12201A)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: Color(hex: 0x182A20).opacity(0.42), radius: 40, y: 24)
            .shadow(color: Color(hex: 0x182A20).opacity(0.16), radius: 10, y: 26)
    }
}

extension View {
    func phoneFrame() -> some View {
        modifier(PhoneFrame())
    }
}

// MARK: - Status Bar

struct StatusBar: View {
    let time: String
    let useLightIcons: Bool

    init(time: String = "9:24", useLightIcons: Bool = false) {
        self.time = time
        self.useLightIcons = useLightIcons
    }

    var body: some View {
        HStack {
            Text(time)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(useLightIcons ? .white : PLOS.Palette.ink)
            Spacer()
            // Signal / battery indicator
            HStack(spacing: 4) {
                Image(systemName: "cellularbars")
                    .font(.system(size: 13))
                Image(systemName: "wifi")
                    .font(.system(size: 13))
                Image(systemName: "battery.75")
                    .font(.system(size: 13))
            }
            .foregroundColor(useLightIcons ? .white : PLOS.Palette.ink)
        }
        .padding(.horizontal, 26)
        .frame(height: 52)
    }
}

// MARK: - Screen Container

struct ScreenContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(width: 356, height: 762)
            .background(PLOS.Palette.paper)
            .clipShape(RoundedRectangle(cornerRadius: 36))
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: 0x26302A).opacity(0.22))
                    .frame(width: 128, height: 5)
                    .padding(.bottom, 10)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 46)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x22322B), Color(hex: 0x12201A)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: Color(hex: 0x182A20).opacity(0.42), radius: 40, y: 24)
            .shadow(color: Color(hex: 0x182A20).opacity(0.16), radius: 10, y: 26)
    }
}

// MARK: - Primary Button

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: PLOS.FontScale.button, weight: .bold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: PLOS.Size.primaryButtonHeight)
            .background(
                RoundedRectangle(cornerRadius: PLOS.Radius.pill)
                    .fill(PLOS.Palette.g500)
            )
            .shadow(color: PLOS.Palette.g500.opacity(0.6), radius: 10, y: 7)
        }
    }
}

// MARK: - Secondary Button

struct SecondaryButton: View {
    let title: String
    let subtitle: String?
    let action: () -> Void

    init(title: String, subtitle: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 15))
                Text(title)
                    .font(.system(size: 14.5, weight: .semibold))
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: 0x436670))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: PLOS.Radius.pill)
                                .fill(PLOS.Palette.slateBg)
                        )
                }
            }
            .foregroundColor(PLOS.Palette.ink2)
            .frame(maxWidth: .infinity)
            .frame(height: PLOS.Size.secondaryButtonHeight)
            .background(
                RoundedRectangle(cornerRadius: PLOS.Radius.pill)
                    .fill(PLOS.Palette.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: PLOS.Radius.pill)
                            .stroke(PLOS.Palette.hairline, lineWidth: 1.5)
                    )
            )
        }
    }
}

// MARK: - Screen Title

struct ScreenTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(subtitle)
                .font(.system(size: PLOS.FontScale.footnote))
                .foregroundColor(PLOS.Palette.ink3)
            Text(title)
                .font(.system(size: PLOS.FontScale.title, weight: .bold))
                .foregroundColor(PLOS.Palette.ink)
        }
    }
}

// MARK: - Task Row

struct TaskRow: View {
    let item: MockPlannedItem

    var body: some View {
        HStack(spacing: 13) {
            // Index box
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(PLOS.Palette.surface2)
                    .frame(width: 27, height: 27)
                Text("\(item.order)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(PLOS.Palette.ink3)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(item.subject)
                        .font(.system(size: PLOS.FontScale.subject, weight: .bold))
                        .foregroundColor(PLOS.Palette.ink)
                    Text("\(item.minutes) min")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(PLOS.Palette.g700)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(PLOS.Palette.g50)
                        )
                }
                HStack(spacing: 7) {
                    Text(item.label)
                        .font(.system(size: 13))
                        .foregroundColor(PLOS.Palette.ink2)
                    if let tag = item.tag {
                        TagChip(text: tag)
                    }
                }
            }

            Spacer()

            // Completion ring
            Circle()
                .stroke(PLOS.Palette.hairline, lineWidth: 2)
                .frame(width: 24, height: 24)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: PLOS.Radius.lg)
                .fill(PLOS.Palette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: PLOS.Radius.lg)
                        .stroke(PLOS.Palette.hairline, lineWidth: 1)
                )
        )
        .shadow(color: Color(hex: 0x263A2C).opacity(0.06), radius: 6, y: 3)
        .shadow(color: Color(hex: 0x263A2C).opacity(0.05), radius: 1, y: 1)
    }
}

// MARK: - Tag Chip

struct TagChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundColor(tagColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(tagBg)
            )
    }

    private var tagColor: Color {
        if text.contains("落后") { return Color(hex: 0x8A6420) }
        if text.contains("每日") { return Color(hex: 0x436670) }
        if text.contains("考前") { return Color(hex: 0x8A6420) }
        return PLOS.Palette.ink2
    }

    private var tagBg: Color {
        if text.contains("落后") { return PLOS.Palette.amberBg }
        if text.contains("每日") { return PLOS.Palette.slateBg }
        if text.contains("考前") { return PLOS.Palette.amberBg }
        return PLOS.Palette.surface2
    }
}

// MARK: - Progress Bar (compact, for month overview)

struct MiniProgressBar: View {
    let label: String
    let progress: Double        // 0...1
    let threshold: Double?      // threshold position (nil = no marker)
    let isPassed: Bool

    var body: some View {
        HStack(spacing: 11) {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(PLOS.Palette.ink2)
                .frame(width: 34, alignment: .leading)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 999)
                    .fill(PLOS.Palette.surface2)
                    .frame(height: 8)
                RoundedRectangle(cornerRadius: 999)
                    .fill(isPassed ? PLOS.Palette.g500 : PLOS.Palette.g400)
                    .frame(width: max(0, CGFloat(progress) * max(1, 0)), height: 8)
                if let t = threshold {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(PLOS.Palette.g700)
                        .frame(width: 2)
                        .offset(x: CGFloat(t) * 200 - 1) // approximate
                        .padding(.vertical, -2)
                }
            }

            if isPassed {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                    Text("达标")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(PLOS.Palette.g600)
            } else {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(PLOS.Palette.ink2)
                    .frame(width: 34, alignment: .trailing)
            }
        }
    }
}

// MARK: - Previews

#Preview("Task Row") {
    VStack(spacing: 10) {
        TaskRow(item: MockPlannedItem(
            goalId: "linalg", subject: "线代", minutes: 55,
            label: "刷题 15 题（接昨天）", tag: "落后节奏", isDone: false, order: 1
        ))
        TaskRow(item: MockPlannedItem(
            goalId: "eng", subject: "英语", minutes: 15,
            label: "英语阅读", tag: "每日", isDone: false, order: 2
        ))
    }
    .padding()
    .background(PLOS.Palette.paper)
}

#Preview("Primary Button") {
    PrimaryButton(title: "生成今日计划") {}
        .padding()
        .background(PLOS.Palette.paper)
}

#Preview("Phone Frame") {
    VStack {
        Text("Screen content")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .phoneFrame()
}
