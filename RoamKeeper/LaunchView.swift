//
//  LaunchView.swift
//  RoamKeeper
//
//  Thematic splash: a barn-wood dawn where a flock roams out across the
//  yard and the sun arcs from release to return — the core idea of the app.
//  Three+ simultaneously animated layers, staged 0–2.6s, clean exit, all
//  loops stopped on disappear.
//

import SwiftUI
import Combine

struct LaunchView: View {
    var onFinish: () -> Void

    // Staged entrance flags
    @State private var bgIn = false
    @State private var sunIn = false
    @State private var birdsIn = false
    @State private var logoIn = false
    @State private var exiting = false

    // Infinite loop drivers
    @State private var roamLoop = false      // birds drift across
    @State private var sunLoop = false       // sun arcs across the sky
    @State private var glowPulse = false     // amber glow breathing

    // Coordinator
    @State private var elapsed: Double = 0
    @State private var finished = false
    @State private var ticker: AnyCancellable?
    @State private var isVisible = true

    private let birds: [(y: CGFloat, size: CGFloat, speed: Double, delay: Double)] = [
        (-40, 26, 1.0, 0.0),
        (10, 34, 1.25, 0.15),
        (60, 22, 0.85, 0.3),
        (-15, 30, 1.1, 0.45),
        (95, 20, 0.95, 0.6)
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ---- Layer 1: background gradient + breathing glow ----
                LinearGradient(
                    colors: [Color(hex: 0x2C2014), Color(hex: 0x5A3E22), Color(hex: 0x8A5A2C)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
                .opacity(bgIn ? 1 : 0)

                RadialGradient(
                    colors: [Palette.amber.opacity(glowPulse ? 0.55 : 0.30), .clear],
                    center: .init(x: 0.5, y: 0.32),
                    startRadius: 10,
                    endRadius: glowPulse ? geo.size.height * 0.75 : geo.size.height * 0.55
                )
                .ignoresSafeArea()
                .opacity(bgIn ? 1 : 0)

                // Plank seams to anchor the barn-wood feel
                woodSeams(in: geo.size)
                    .opacity(bgIn ? 0.5 : 0)

                // ---- Layer 2a: the sun arcing release -> return ----
                let arcW = geo.size.width
                let prog = sunLoop ? 1.0 : 0.0
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: 0xFFE2A8), Palette.amber],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 46, height: 46)
                    .shadow(color: Palette.amber.opacity(0.8), radius: 18)
                    .position(
                        x: arcW * (0.15 + 0.7 * prog),
                        y: geo.size.height * 0.30 - sin(prog * .pi) * geo.size.height * 0.14
                    )
                    .opacity(sunIn ? 1 : 0)
                    .animation(.linear(duration: 3.2).repeatForever(autoreverses: true), value: sunLoop)

                // ---- Layer 2b: roaming flock drifting across the yard ----
                ZStack {
                    ForEach(Array(birds.enumerated()), id: \.offset) { _, b in
                        BirdMark(size: b.size, color: Color(hex: 0x3A2A18).opacity(0.9))
                            .offset(
                                x: roamLoop ? geo.size.width * 0.62 : -geo.size.width * 0.62,
                                y: b.y + (roamLoop ? -8 : 8)
                            )
                            .opacity(birdsIn ? 1 : 0)
                            .animation(
                                .easeInOut(duration: 2.6 / b.speed)
                                    .repeatForever(autoreverses: true)
                                    .delay(b.delay),
                                value: roamLoop
                            )
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height * 0.5)
                .position(x: geo.size.width / 2, y: geo.size.height * 0.52)

                // ---- Layer 3: foreground logo + title ----
                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: 0xFBF1DC))
                            .frame(width: 124, height: 124)
                            .shadow(color: .black.opacity(0.3), radius: 14, y: 6)
                        Circle()
                            .stroke(Palette.amber, lineWidth: 4)
                            .frame(width: 124, height: 124)
                        Image(systemName: "house.fill")
                            .font(.system(size: 46, weight: .bold))
                            .foregroundColor(Palette.amberDeep)
                        BirdMark(size: 26, color: Palette.clay)
                            .offset(x: 34, y: -34)
                    }
                    .scaleEffect(exiting ? 1.6 : (logoIn ? 1 : 0.5))
                    .opacity(exiting ? 0 : (logoIn ? 1 : 0))

                    VStack(spacing: 4) {
                        Text("Roam Keeper")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundColor(Color(hex: 0xFBF1DC))
                        Text("Zones · release · return")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(Palette.amber)
                            .tracking(2)
                    }
                    .opacity(exiting ? 0 : (logoIn ? 1 : 0))
                    .offset(y: logoIn ? 0 : 16)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear { start() }
        .onDisappear { stop() }
    }

    // MARK: Wood seams helper

    private func woodSeams(in size: CGSize) -> some View {
        Path { path in
            var x: CGFloat = size.width / 6
            while x < size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += size.width / 6
            }
        }
        .stroke(Color.black.opacity(0.25), lineWidth: 1)
        .ignoresSafeArea()
    }

    // MARK: Coordinator

    private func start() {
        isVisible = true
        // Kick off looping layers
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            glowPulse = true
        }
        roamLoop = true
        sunLoop = true

        // Staged entrance via a single coordinator ticker (no asyncAfter chains).
        ticker = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { _ in tick() }
    }

    private func tick() {
        guard isVisible, !finished else { return }
        elapsed += 0.05

        if elapsed >= 0.05 && !bgIn {
            withAnimation(.easeOut(duration: 0.55)) { bgIn = true }
        }
        if elapsed >= 0.45 && !sunIn {
            withAnimation(.easeOut(duration: 0.6)) { sunIn = true }
        }
        if elapsed >= 0.6 && !birdsIn {
            withAnimation(.easeOut(duration: 0.7)) { birdsIn = true }
        }
        if elapsed >= 1.4 && !logoIn {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) { logoIn = true }
        }
        if elapsed >= 2.2 && !exiting {
            withAnimation(.easeIn(duration: 0.4)) { exiting = true }
        }
        if elapsed >= 2.6 && !finished {
            finished = true
            stop()
            onFinish()
        }
    }

    private func stop() {
        isVisible = false
        ticker?.cancel()
        ticker = nil
        // Reset every looping flag so no animation leaks into the main app.
        roamLoop = false
        sunLoop = false
        glowPulse = false
    }
}
