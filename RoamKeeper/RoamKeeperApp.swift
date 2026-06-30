//
//  RoamKeeperApp.swift
//  RoamKeeper
//
//  App entry point. Owns the app-wide store + settings and applies the
//  selected theme. Flow: Splash → Onboarding (first launch only) → Main App.
//

import SwiftUI

@main
struct RoamKeeperApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var settings = AppSettings()

    init() {
        Self.configureBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(settings)
                .preferredColorScheme(settings.themeMode.colorScheme)
                .accentColor(settings.accentColor)
        }
    }

    /// Make navigation bars transparent so the barn-wood background shows
    /// through, and hide the system tab bar (we use a custom one).
    private static func configureBarAppearance() {
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundColor = .clear
        nav.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = UIColor(Palette.amberDeep)
    }
}
