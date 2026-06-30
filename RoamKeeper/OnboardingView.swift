//
//  OnboardingView.swift
//  RoamKeeper
//
//  Four-screen onboarding. Each screen has a unique illustrated scene and a
//  distinct interactive element (tap-burst, drag dial, motion parallax,
//  long-press stamp). State is written into AppSettings / AppStore. All
//  looping animations are stopped on disappear.
//

import SwiftUI
import CoreMotion

// MARK: - Motion (parallax for screen 3)

final class MotionManager: ObservableObject {
    private let mgr = CMMotionManager()
    @Published var roll: Double = 0
    @Published var pitch: Double = 0

    func start() {
        guard mgr.isDeviceMotionAvailable else { return }
        mgr.deviceMotionUpdateInterval = 1.0 / 30.0
        mgr.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let m = motion else { return }
            self?.roll = m.attitude.roll
            self?.pitch = m.attitude.pitch
        }
    }
    func stop() {
        mgr.stopDeviceMotionUpdates()
        roll = 0; pitch = 0
    }
}

// MARK: - Particle burst (screen 1)

private struct Particle: Identifiable {
    let id = UUID()
    var dx: CGFloat
    var dy: CGFloat
    var color: Color
    var size: CGFloat
}

private struct ParticleBurstView: View {
    @Binding var trigger: Int
    @State private var particles: [Particle] = []
    @State private var fired = false

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                Image(systemName: "leaf.fill")
                    .font(.system(size: p.size))
                    .foregroundColor(p.color)
                    .offset(x: fired ? p.dx : 0, y: fired ? p.dy : 0)
                    .opacity(fired ? 0 : 1)
                    .scaleEffect(fired ? 0.4 : 1)
            }
        }
        .onChange(of: trigger) { _ in burst() }
        .onDisappear { particles = []; fired = false }
    }

    private func burst() {
        let colors = [Palette.amber, Palette.sage, Palette.clay, Palette.sky]
        particles = (0..<14).map { i in
            let angle = Double(i) / 14 * 2 * .pi
            return Particle(
                dx: CGFloat(cos(angle)) * CGFloat.random(in: 80...150),
                dy: CGFloat(sin(angle)) * CGFloat.random(in: 80...150),
                color: colors[i % colors.count],
                size: CGFloat.random(in: 12...22))
        }
        fired = false
        withAnimation(.easeOut(duration: 0.9)) { fired = true }
    }
}

// MARK: - Root onboarding container

struct OnboardingView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) private var scheme

    @State private var page = 0

    // Screen 2 working state
    @State private var groupName = ""
    @State private var groupType: BirdType = .chickens
    @State private var groupCount = 12

    var body: some View {
        ZStack {
            BarnWoodBackground()

            VStack(spacing: 0) {
                // Top bar: progress dots + skip
                HStack {
                    HStack(spacing: 7) {
                        ForEach(0..<4) { i in
                            Capsule()
                                .fill(i == page ? Palette.amber : Palette.amber.opacity(0.3))
                                .frame(width: i == page ? 22 : 8, height: 8)
                                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: page)
                        }
                    }
                    Spacer()
                    if page < 3 {
                        Button("Skip") { finish() }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Palette.secondaryText(scheme))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                TabView(selection: $page) {
                    FarmStyleScreen().tag(0)
                    BirdGroupsScreen(name: $groupName, type: $groupType, count: $groupCount).tag(1)
                    CarePrioritiesScreen().tag(2)
                    ReadyScreen().tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: page)

                // Bottom action button
                Button(action: advance) {
                    Text(buttonTitle)
                }
                .buttonStyle(PrimaryButtonStyle(color: Palette.amber))
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    private var buttonTitle: String {
        switch page {
        case 0: return "Next"
        case 1: return "Add Group"
        case 2: return "Set Priorities"
        default: return "Open Dashboard"
        }
    }

    private func advance() {
        switch page {
        case 1:
            let trimmed = groupName.trimmingCharacters(in: .whitespaces)
            let name = trimmed.isEmpty ? "My Flock" : trimmed
            let g = BirdGroup(name: name, type: groupType, count: groupCount,
                              zoneId: store.data.zones.first?.id, tag: .amber)
            store.data.groups.insert(g, at: 0)
            withAnimation { page = 2 }
        case 3:
            finish()
        default:
            withAnimation { page += 1 }
        }
    }

    private func finish() {
        if settings.notificationsEnabled {
            store.requestNotificationAuth()
        }
        withAnimation(.easeInOut) { settings.hasCompletedOnboarding = true }
    }
}

// MARK: - Screen 1: Farm Style (tap-burst)

private struct FarmStyleScreen: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) private var scheme
    @State private var burst = 0
    @State private var iconPulse = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(Palette.amber.opacity(0.16))
                        .frame(width: 170, height: 170)
                        .scaleEffect(iconPulse ? 1.06 : 0.96)
                    ParticleBurstView(trigger: $burst)
                    Image(systemName: "house.fill")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundColor(Palette.amberDeep)
                        .scaleEffect(iconPulse ? 1.04 : 1)
                }
                .frame(height: 200)
                .contentShape(Circle())
                .onTapGesture { burst += 1 }
                .padding(.top, 8)

                VStack(spacing: 8) {
                    Text("Make every check visible")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(Palette.primaryText(scheme))
                    Text("Tap the barn to scatter feed, then choose how your home screen looks.")
                        .font(.system(size: 15))
                        .multilineTextAlignment(.center)
                        .foregroundColor(Palette.secondaryText(scheme))
                        .padding(.horizontal, 24)
                }

                VStack(spacing: 12) {
                    ForEach(VisualMode.allCases) { mode in
                        modeButton(mode)
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 20)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { iconPulse = true }
        }
        .onDisappear { iconPulse = false }
    }

    private func modeButton(_ mode: VisualMode) -> some View {
        let isSelected = settings.visualMode == mode
        return Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { settings.visualMode = mode }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: mode.symbol)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(isSelected ? .white : Palette.amberDeep)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.rawValue).font(.system(size: 16, weight: .bold, design: .rounded))
                    Text(mode.blurb).font(.system(size: 12)).opacity(0.85)
                }
                Spacer()
                if isSelected { Image(systemName: "checkmark.circle.fill") }
            }
            .foregroundColor(isSelected ? .white : Palette.primaryText(scheme))
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Palette.amber : Palette.cardFill(scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Palette.cardStroke(scheme), lineWidth: 1)
            )
        }
    }
}

// MARK: - Screen 2: Bird Groups (drag dial)

private struct BirdGroupsScreen: View {
    @Binding var name: String
    @Binding var type: BirdType
    @Binding var count: Int
    @Environment(\.colorScheme) private var scheme
    @State private var dialAngle: Double = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Create your first group")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Palette.primaryText(scheme))
                    .padding(.top, 8)
                Text("Drag the dial to set how many birds — then name them.")
                    .font(.system(size: 15))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Palette.secondaryText(scheme))
                    .padding(.horizontal, 24)

                // Drag dial
                DragCountDial(count: $count)
                    .frame(width: 200, height: 200)

                VStack(spacing: 16) {
                    ThemedField(title: "Group name", placeholder: "e.g. Brown Layers", text: $name)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("BIRD TYPE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Palette.secondaryText(scheme))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(BirdType.allCases) { t in
                                    Button {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { type = t }
                                    } label: {
                                        Chip(text: t.rawValue, symbol: t.symbol,
                                             color: Palette.amber, selected: type == t)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 20)
        }
    }
}

private struct DragCountDial: View {
    @Binding var count: Int
    @Environment(\.colorScheme) private var scheme
    @State private var dragProgress: CGFloat = 0.12   // 0...1 maps to 1...60

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                Circle().stroke(Palette.amber.opacity(0.16), lineWidth: 16)
                Circle()
                    .trim(from: 0, to: dragProgress)
                    .stroke(
                        AngularGradient(colors: [Palette.amber.opacity(0.6), Palette.amber], center: .center),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(count)")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .foregroundColor(Palette.primaryText(scheme))
                    Text("birds")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Palette.secondaryText(scheme))
                }
                // The draggable knob
                Circle()
                    .fill(Palette.amberDeep)
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
                    .offset(knobOffset(radius: size / 2 - 8))
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let center = CGPoint(x: size / 2, y: size / 2)
                        let dx = value.location.x - center.x
                        let dy = value.location.y - center.y
                        var angle = atan2(dy, dx) + .pi / 2
                        if angle < 0 { angle += 2 * .pi }
                        let p = CGFloat(angle / (2 * .pi))
                        dragProgress = p
                        count = max(1, min(60, Int(p * 60) + 1))
                    }
            )
        }
        .onAppear { dragProgress = CGFloat(max(1, count) - 1) / 60 }
    }

    private func knobOffset(radius: CGFloat) -> CGSize {
        let angle = Double(dragProgress) * 2 * .pi - .pi / 2
        return CGSize(width: cos(angle) * Double(radius), height: sin(angle) * Double(radius))
    }
}

// MARK: - Screen 3: Care Priorities (motion parallax)

private struct CarePrioritiesScreen: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) private var scheme
    @StateObject private var motion = MotionManager()
    @State private var fallbackDrift = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Parallax illustration
                ZStack {
                    parallaxLayer(symbol: "leaf.fill", color: Palette.sage, base: CGSize(width: -70, height: -30), depth: 26)
                    parallaxLayer(symbol: "drop.fill", color: Palette.sky, base: CGSize(width: 80, height: -10), depth: 18)
                    parallaxLayer(symbol: "sparkles", color: Palette.amber, base: CGSize(width: -40, height: 40), depth: 34)
                    parallaxLayer(symbol: "shippingbox.fill", color: Palette.clay, base: CGSize(width: 60, height: 50), depth: 12)
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 58, weight: .bold))
                        .foregroundColor(Palette.berry)
                        .offset(parallax(depth: 8))
                }
                .frame(height: 180)
                .padding(.top, 8)

                Text("What matters today?")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundColor(Palette.primaryText(scheme))
                Text("Tilt your phone to feel the board, then lift today's priorities up.")
                    .font(.system(size: 15))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Palette.secondaryText(scheme))
                    .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    ForEach(CarePriority.allCases) { p in
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                if settings.priorities.contains(p) { settings.priorities.remove(p) }
                                else { settings.priorities.insert(p) }
                            }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: p.symbol)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(settings.priorities.contains(p) ? .white : Palette.amberDeep)
                                    .frame(width: 30)
                                Text(p.rawValue)
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                Spacer()
                                Image(systemName: settings.priorities.contains(p) ? "checkmark.circle.fill" : "circle")
                            }
                            .foregroundColor(settings.priorities.contains(p) ? .white : Palette.primaryText(scheme))
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(settings.priorities.contains(p) ? Palette.amber : Palette.cardFill(scheme))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Palette.cardStroke(scheme), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 20)
        }
        .onAppear {
            motion.start()
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { fallbackDrift = true }
        }
        .onDisappear {
            motion.stop()
            fallbackDrift = false
        }
    }

    private func parallaxLayer(symbol: String, color: Color, base: CGSize, depth: CGFloat) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 30, weight: .bold))
            .foregroundColor(color.opacity(0.85))
            .offset(x: base.width + parallax(depth: depth).width,
                    y: base.height + parallax(depth: depth).height)
    }

    private func parallax(depth: CGFloat) -> CGSize {
        // Use motion if available, otherwise gently auto-drift.
        let driftX = fallbackDrift ? depth * 0.4 : -depth * 0.4
        let x = motion.roll != 0 ? CGFloat(motion.roll) * depth : driftX
        let y = motion.pitch != 0 ? CGFloat(motion.pitch) * depth : 0
        return CGSize(width: x, height: y)
    }
}

// MARK: - Screen 4: Ready (long-press stamp)

private struct ReadyScreen: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) private var scheme
    @State private var stamped = false
    @State private var confetti: [Particle] = []
    @State private var confettiFired = false
    @State private var ringPulse = false

    private let sections = [
        ("square.grid.2x2.fill", "Dashboard", "Today's roam & return status"),
        ("hare.fill", "Groups", "Your flock counts & zones"),
        ("list.bullet.rectangle", "Care Logs", "Morning & evening checks"),
        ("map.fill", "Routes", "Your walking order")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    ForEach(confetti) { p in
                        Circle()
                            .fill(p.color)
                            .frame(width: p.size, height: p.size)
                            .offset(x: confettiFired ? p.dx : 0, y: confettiFired ? p.dy : 0)
                            .opacity(confettiFired ? 0 : 1)
                    }
                    Circle()
                        .stroke(Palette.amber.opacity(0.3), lineWidth: 3)
                        .frame(width: 150, height: 150)
                        .scaleEffect(ringPulse ? 1.08 : 0.94)
                    Circle()
                        .fill(stamped ? Palette.sage : Palette.amber.opacity(0.18))
                        .frame(width: 120, height: 120)
                    Image(systemName: stamped ? "checkmark.seal.fill" : "hand.tap.fill")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(stamped ? .white : Palette.amberDeep)
                        .scaleEffect(stamped ? 1.1 : 1)
                }
                .frame(height: 180)
                .padding(.top, 8)
                .gesture(
                    LongPressGesture(minimumDuration: 0.5)
                        .onEnded { _ in stamp() }
                )

                Text("Your farm board is ready")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Palette.primaryText(scheme))
                Text(stamped ? "Stamped! These sections are filled first." : "Press & hold the seal to confirm your setup.")
                    .font(.system(size: 15))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Palette.secondaryText(scheme))
                    .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    ForEach(Array(sections.enumerated()), id: \.offset) { _, s in
                        HStack(spacing: 14) {
                            Image(systemName: s.0)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Palette.amberDeep)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.1).font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(Palette.primaryText(scheme))
                                Text(s.2).font(.system(size: 12))
                                    .foregroundColor(Palette.secondaryText(scheme))
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Palette.sage)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Palette.cardFill(scheme))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Palette.cardStroke(scheme), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 20)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { ringPulse = true }
        }
        .onDisappear {
            ringPulse = false
            confetti = []
            confettiFired = false
        }
    }

    private func stamp() {
        guard !stamped else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { stamped = true }
        let colors = [Palette.amber, Palette.sage, Palette.clay, Palette.sky, Palette.berry]
        confetti = (0..<22).map { i in
            let angle = Double(i) / 22 * 2 * .pi
            return Particle(
                dx: CGFloat(cos(angle)) * CGFloat.random(in: 90...170),
                dy: CGFloat(sin(angle)) * CGFloat.random(in: 90...170),
                color: colors[i % colors.count],
                size: CGFloat.random(in: 6...12))
        }
        confettiFired = false
        withAnimation(.easeOut(duration: 1.0)) { confettiFired = true }
    }
}
