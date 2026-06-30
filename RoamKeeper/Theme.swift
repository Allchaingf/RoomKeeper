//
//  Theme.swift
//  RoamKeeper
//
//  Design system: palette, barn-wood textured background, reusable
//  components (buttons, cards, fields, chips, charts). iOS 14 compatible.
//

import SwiftUI

// MARK: - Color helpers

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

/// Central palette. Amber + barn-wood warmth with sensible dark-mode shifts.
enum Palette {
    static let amber = Color(hex: 0xE8A33D)
    static let amberDeep = Color(hex: 0xCB7A1E)
    static let clay = Color(hex: 0xC76B4A)
    static let sage = Color(hex: 0x7C9A6B)
    static let sky = Color(hex: 0x5C8FB0)
    static let berry = Color(hex: 0x9C5B82)
    static let danger = Color(hex: 0xC75A4A)

    // Wood tones for the textured background.
    static let woodLight = Color(hex: 0xE7D6BE)
    static let woodMid = Color(hex: 0xCBB088)
    static let woodDeep = Color(hex: 0x8A6A45)
    static let woodNight = Color(hex: 0x241C16)
    static let woodNight2 = Color(hex: 0x352A20)

    static func cardFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x2A2118) : Color(hex: 0xFBF4E7)
    }
    static func cardStroke(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x4A3D2E) : Color(hex: 0xD9C49E)
    }
    static func primaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xF3E9D6) : Color(hex: 0x352A1C)
    }
    static func secondaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xC6B392) : Color(hex: 0x8A7257)
    }
}

// MARK: - Barn-wood textured background

/// A subtle vertical-plank barn-wood backdrop drawn with gradients + Path
/// grain lines. Used behind every screen so the app feels grounded.
struct BarnWoodBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { geo in
            let plankWidth = max(54, geo.size.width / 6)
            ZStack {
                LinearGradient(
                    colors: scheme == .dark
                        ? [Palette.woodNight, Palette.woodNight2, Palette.woodNight]
                        : [Palette.woodLight, Palette.woodMid, Palette.woodLight],
                    startPoint: .top, endPoint: .bottom
                )

                // Plank seams (vertical).
                Path { path in
                    var x = plankWidth
                    while x < geo.size.width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geo.size.height))
                        x += plankWidth
                    }
                }
                .stroke(Color.black.opacity(scheme == .dark ? 0.35 : 0.10), lineWidth: 1.2)

                // Soft wood grain arcs.
                Path { path in
                    var y: CGFloat = 40
                    var i = 0
                    while y < geo.size.height {
                        let amp: CGFloat = (i % 2 == 0) ? 10 : 18
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addCurve(
                            to: CGPoint(x: geo.size.width, y: y + amp),
                            control1: CGPoint(x: geo.size.width * 0.33, y: y - amp),
                            control2: CGPoint(x: geo.size.width * 0.66, y: y + amp * 2)
                        )
                        y += 64
                        i += 1
                    }
                }
                .stroke(Color(hex: 0x6B4F32).opacity(scheme == .dark ? 0.18 : 0.08), lineWidth: 1)

                // Warm amber glow at the top for that "lantern in the barn" feel.
                RadialGradient(
                    colors: [Palette.amber.opacity(scheme == .dark ? 0.16 : 0.22), .clear],
                    center: .top, startRadius: 0, endRadius: geo.size.height * 0.7
                )
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Custom bird glyph (version-proof — drawn, not an SF Symbol)

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// A simple hen silhouette so "bird groups" always render an actual bird on
/// every iOS version (SF Symbols has no bird before iOS 16).
struct BirdMark: View {
    var size: CGFloat = 24
    var color: Color = .white

    var body: some View {
        ZStack {
            // Tail
            Triangle()
                .fill(color)
                .frame(width: size * 0.34, height: size * 0.40)
                .rotationEffect(.degrees(-128))
                .offset(x: -size * 0.30, y: -size * 0.04)
            // Body
            Ellipse()
                .fill(color)
                .frame(width: size * 0.72, height: size * 0.56)
                .offset(x: -size * 0.02, y: size * 0.10)
            // Head
            Circle()
                .fill(color)
                .frame(width: size * 0.36, height: size * 0.36)
                .offset(x: size * 0.24, y: -size * 0.12)
            // Comb
            Circle()
                .fill(color)
                .frame(width: size * 0.12, height: size * 0.12)
                .offset(x: size * 0.20, y: -size * 0.30)
            // Beak
            Triangle()
                .fill(color)
                .frame(width: size * 0.16, height: size * 0.13)
                .rotationEffect(.degrees(92))
                .offset(x: size * 0.46, y: -size * 0.10)
            // Eye
            Circle()
                .fill(Color.black.opacity(0.55))
                .frame(width: size * 0.07, height: size * 0.07)
                .offset(x: size * 0.29, y: -size * 0.15)
            // Leg
            Capsule()
                .fill(color)
                .frame(width: size * 0.05, height: size * 0.18)
                .offset(x: size * 0.02, y: size * 0.40)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Cards

struct CoopCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    var accent: Color = Palette.amber
    var content: () -> Content

    init(accent: Color = Palette.amber, @ViewBuilder content: @escaping () -> Content) {
        self.accent = accent
        self.content = content
    }

    var body: some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Palette.cardFill(scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Palette.cardStroke(scheme), lineWidth: 1)
            )
            .overlay(
                // A thin amber "roof line" on the leading edge.
                RoundedRectangle(cornerRadius: 4)
                    .fill(accent)
                    .frame(width: 4)
                    .padding(.vertical, 12),
                alignment: .leading
            )
            .shadow(color: Color.black.opacity(scheme == .dark ? 0.4 : 0.10),
                    radius: 8, x: 0, y: 4)
    }
}

// MARK: - Section header

struct SectionHeader: View {
    @Environment(\.colorScheme) private var scheme
    var icon: String
    var title: String
    var subtitle: String? = nil
    var useBird: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Palette.amber.opacity(0.18))
                    .frame(width: 40, height: 40)
                if useBird {
                    BirdMark(size: 24, color: Palette.amberDeep)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Palette.amberDeep)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(Palette.primaryText(scheme))
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(Palette.secondaryText(scheme))
                }
            }
            Spacer()
        }
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Palette.amber
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(colors: [color, color.opacity(0.82)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: color.opacity(0.4), radius: configuration.isPressed ? 2 : 8,
                    x: 0, y: configuration.isPressed ? 1 : 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme
    var color: Color = Palette.amberDeep
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(color.opacity(scheme == .dark ? 0.16 : 0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(color.opacity(0.4), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Small pill chip used for tags / filters.
struct Chip: View {
    @Environment(\.colorScheme) private var scheme
    var text: String
    var symbol: String? = nil
    var color: Color = Palette.amber
    var selected: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if let symbol = symbol {
                Image(systemName: symbol).font(.system(size: 11, weight: .bold))
            }
            Text(text).font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(selected ? .white : color)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule().fill(selected ? color : color.opacity(scheme == .dark ? 0.18 : 0.14))
        )
        .overlay(
            Capsule().stroke(color.opacity(selected ? 0 : 0.4), lineWidth: 1)
        )
    }
}

// MARK: - Stat tile

struct StatTile: View {
    @Environment(\.colorScheme) private var scheme
    var value: String
    var label: String
    var symbol: String
    var color: Color
    var useBird: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if useBird {
                    BirdMark(size: 17, color: color)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(color)
                }
                Spacer()
            }
            Text(value)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundColor(Palette.primaryText(scheme))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Palette.secondaryText(scheme))
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Palette.cardFill(scheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(color.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Themed text field & editor

struct ThemedField: View {
    @Environment(\.colorScheme) private var scheme
    var title: String
    var placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Palette.secondaryText(scheme))
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .font(.system(size: 16))
                .foregroundColor(Palette.primaryText(scheme))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(scheme == .dark ? Color.black.opacity(0.25) : Color.white.opacity(0.7))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Palette.cardStroke(scheme), lineWidth: 1)
                )
        }
    }
}

// MARK: - Empty state

struct EmptyHint: View {
    @Environment(\.colorScheme) private var scheme
    var symbol: String
    var title: String
    var message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .regular))
                .foregroundColor(Palette.amber.opacity(0.7))
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(Palette.primaryText(scheme))
            Text(message)
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundColor(Palette.secondaryText(scheme))
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}

// MARK: - Simple bar chart (Path based, iOS 14 safe)

struct BarPoint: Identifiable {
    var id = UUID()
    var label: String
    var value: Double
}

struct MiniBarChart: View {
    @Environment(\.colorScheme) private var scheme
    var points: [BarPoint]
    var color: Color = Palette.amber
    var height: CGFloat = 120

    private var maxValue: Double { max(points.map { $0.value }.max() ?? 1, 1) }

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(points) { p in
                    VStack(spacing: 6) {
                        Spacer(minLength: 0)
                        Text(p.value > 0 ? trimmed(p.value) : "")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Palette.secondaryText(scheme))
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(LinearGradient(colors: [color, color.opacity(0.6)],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(height: max(4, CGFloat(p.value / maxValue) * height))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: height + 18)
            HStack(spacing: 8) {
                ForEach(points) { p in
                    Text(p.label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Palette.secondaryText(scheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func trimmed(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }
}

// MARK: - Line / trend chart

struct LineChart: View {
    @Environment(\.colorScheme) private var scheme
    var values: [Double]
    var color: Color = Palette.sky
    var height: CGFloat = 120

    var body: some View {
        GeometryReader { geo in
            let maxV = max(values.max() ?? 1, 1)
            let minV = min(values.min() ?? 0, 0)
            let range = max(maxV - minV, 1)
            let stepX = values.count > 1 ? geo.size.width / CGFloat(values.count - 1) : geo.size.width

            ZStack {
                // Fill under the line.
                Path { path in
                    guard !values.isEmpty else { return }
                    path.move(to: CGPoint(x: 0, y: geo.size.height))
                    for (i, v) in values.enumerated() {
                        let x = CGFloat(i) * stepX
                        let y = geo.size.height - CGFloat((v - minV) / range) * geo.size.height
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    path.addLine(to: CGPoint(x: CGFloat(values.count - 1) * stepX, y: geo.size.height))
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [color.opacity(0.35), color.opacity(0.02)],
                                     startPoint: .top, endPoint: .bottom))

                // The line itself.
                Path { path in
                    for (i, v) in values.enumerated() {
                        let x = CGFloat(i) * stepX
                        let y = geo.size.height - CGFloat((v - minV) / range) * geo.size.height
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                // Dots.
                ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                    let x = CGFloat(i) * stepX
                    let y = geo.size.height - CGFloat((v - minV) / range) * geo.size.height
                    Circle()
                        .fill(color)
                        .frame(width: 7, height: 7)
                        .position(x: x, y: y)
                }
            }
        }
        .frame(height: height)
    }
}

// MARK: - Ring progress

struct RingProgress: View {
    @Environment(\.colorScheme) private var scheme
    var progress: Double   // 0...1
    var color: Color = Palette.amber
    var size: CGFloat = 84
    var lineWidth: CGFloat = 10
    var centerLabel: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                .stroke(
                    AngularGradient(colors: [color.opacity(0.7), color], center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text(centerLabel)
                .font(.system(size: size * 0.26, weight: .heavy, design: .rounded))
                .foregroundColor(Palette.primaryText(scheme))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Convenience modifiers

extension View {
    /// Standard screen scaffold: barn-wood background under content.
    func barnScreen() -> some View {
        self.background(BarnWoodBackground())
    }
}

// MARK: - Screen scaffold

/// Every functional screen uses this: barn-wood background, a custom amber
/// section header, scrollable content, and bottom inset for the floating tab bar.
struct ScreenScaffold<Content: View>: View {
    var icon: String
    var title: String
    var subtitle: String? = nil
    var bottomInset: CGFloat = 104
    var useBird: Bool = false
    var content: () -> Content

    init(icon: String, title: String, subtitle: String? = nil,
         bottomInset: CGFloat = 104, useBird: Bool = false,
         @ViewBuilder content: @escaping () -> Content) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.bottomInset = bottomInset
        self.useBird = useBird
        self.content = content
    }

    var body: some View {
        ZStack {
            BarnWoodBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(icon: icon, title: title, subtitle: subtitle, useBird: useBird)
                        .padding(.top, 8)
                    content()
                }
                .padding(16)
                .padding(.bottom, bottomInset)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Field chrome

struct FieldChrome: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(scheme == .dark ? Color.black.opacity(0.25) : Color.white.opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Palette.cardStroke(scheme), lineWidth: 1)
            )
    }
}

extension View {
    func fieldChrome() -> some View { modifier(FieldChrome()) }
}

struct FieldLabel: View {
    @Environment(\.colorScheme) private var scheme
    var text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(Palette.secondaryText(scheme))
    }
}

// MARK: - Menu picker field

struct MenuField<T: Hashable>: View {
    @Environment(\.colorScheme) private var scheme
    var title: String
    var options: [T]
    @Binding var selection: T
    var label: (T) -> String
    var symbol: (T) -> String? = { _ in nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel(text: title)
            Menu {
                ForEach(options, id: \.self) { opt in
                    Button { selection = opt } label: {
                        if let s = symbol(opt) { Label(label(opt), systemImage: s) }
                        else { Text(label(opt)) }
                    }
                }
            } label: {
                HStack {
                    if let s = symbol(selection) {
                        Image(systemName: s).foregroundColor(Palette.amberDeep)
                    }
                    Text(label(selection))
                        .foregroundColor(Palette.primaryText(scheme))
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Palette.secondaryText(scheme))
                }
                .fieldChrome()
            }
        }
    }
}

// MARK: - Enum chip selector

struct EnumChips<T: Hashable & Identifiable>: View {
    var title: String
    var options: [T]
    @Binding var selection: T
    var label: (T) -> String
    var symbol: (T) -> String? = { _ in nil }
    var color: Color = Palette.amber

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel(text: title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options) { opt in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { selection = opt }
                        } label: {
                            Chip(text: label(opt), symbol: symbol(opt),
                                 color: color, selected: selection == opt)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

// MARK: - Star rating

struct StarRating: View {
    @Binding var value: Int
    var color: Color = Palette.amber
    var max: Int = 5

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...max, id: \.self) { i in
                Image(systemName: i <= value ? "star.fill" : "star")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(i <= value ? color : color.opacity(0.3))
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { value = i }
                    }
            }
        }
    }
}

// MARK: - Toggle & stepper rows

struct ToggleRow: View {
    @Environment(\.colorScheme) private var scheme
    var icon: String
    var title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    var tint: Color = Palette.amber

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Palette.primaryText(scheme))
                if let subtitle = subtitle {
                    Text(subtitle).font(.system(size: 12))
                        .foregroundColor(Palette.secondaryText(scheme))
                }
            }
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden()
        }
    }
}

struct StepperRow: View {
    @Environment(\.colorScheme) private var scheme
    var title: String
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...999
    var suffix: String = ""

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Palette.primaryText(scheme))
            Spacer()
            HStack(spacing: 14) {
                Button { if value > range.lowerBound { value -= 1 } } label: {
                    Image(systemName: "minus.circle.fill")
                }
                Text("\(value)\(suffix)")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .frame(minWidth: 44)
                    .foregroundColor(Palette.primaryText(scheme))
                Button { if value < range.upperBound { value += 1 } } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
            .font(.system(size: 22))
            .foregroundColor(Palette.amberDeep)
        }
    }
}

// MARK: - Info row

struct InfoRow: View {
    @Environment(\.colorScheme) private var scheme
    var label: String
    var value: String
    var color: Color = Palette.amberDeep

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(Palette.secondaryText(scheme))
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
    }
}

// MARK: - Toast / confirmation banner

struct Toast: View {
    var text: String
    var symbol: String = "checkmark.circle.fill"
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
            Text(text).font(.system(size: 14, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Capsule().fill(Palette.sage))
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
    }
}

/// Attaches a transient confirmation toast at the bottom of any view.
struct ToastModifier: ViewModifier {
    @Binding var message: String?
    func body(content: Content) -> some View {
        ZStack {
            content
            if let message = message {
                VStack {
                    Spacer()
                    Toast(text: message)
                        .padding(.bottom, 120)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                        withAnimation { self.message = nil }
                    }
                }
            }
        }
    }
}

extension View {
    func toast(_ message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}
