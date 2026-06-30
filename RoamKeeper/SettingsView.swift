//
//  SettingsView.swift
//  RoamKeeper
//
//  Screen 24 — App Preferences. App settings only: theme, accent, units,
//  visual mode, care priorities, local notifications, color labels, and
//  sample-data reset. No profile, no account, no auth.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) private var scheme

    @State private var showResetAlert = false
    @State private var toastMessage: String?

    var body: some View {
        ScreenScaffold(icon: "gearshape.fill", title: "App Preferences",
                       subtitle: "Local settings · no account, ever") {

            // MARK: Appearance
            settingsCard("Appearance", "paintpalette.fill") {
                VStack(alignment: .leading, spacing: 14) {
                    FieldLabel(text: "Theme")
                    HStack(spacing: 10) {
                        ForEach(ThemeMode.allCases) { mode in
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { settings.themeMode = mode }
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: mode.symbol).font(.system(size: 20, weight: .bold))
                                    Text(mode.rawValue).font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(settings.themeMode == mode ? .white : Palette.primaryText(scheme))
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 12)
                                    .fill(settings.themeMode == mode ? Palette.amber : Palette.cardFill(scheme)))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.cardStroke(scheme), lineWidth: 1))
                            }
                        }
                    }

                    FieldLabel(text: "Accent color")
                    HStack(spacing: 12) {
                        ForEach(ColorTag.allCases) { c in
                            Circle().fill(c.color).frame(width: 32, height: 32)
                                .overlay(Circle().stroke(Color.white, lineWidth: settings.accent == c ? 3 : 0))
                                .overlay(Circle().stroke(Palette.cardStroke(scheme), lineWidth: 1))
                                .scaleEffect(settings.accent == c ? 1.15 : 1)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { settings.accent = c }
                                }
                        }
                    }
                }
            }

            // MARK: Units
            settingsCard("Measurement Units", "ruler.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        ForEach(UnitSystem.allCases) { u in
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { settings.units = u }
                            } label: {
                                Text(u.rawValue)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(settings.units == u ? .white : Palette.primaryText(scheme))
                                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                                    .background(RoundedRectangle(cornerRadius: 12)
                                        .fill(settings.units == u ? Palette.amber : Palette.cardFill(scheme)))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.cardStroke(scheme), lineWidth: 1))
                            }
                        }
                    }
                    Text("Weight \(settings.units.bigWeightUnit) · area \(settings.units.areaUnit) · temp \(settings.units.tempUnit)")
                        .font(.system(size: 12)).foregroundColor(Palette.secondaryText(scheme))
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            settings.units = settings.units == .metric ? .imperial : .metric
                        }
                        toastMessage = "Units: \(settings.units.rawValue)"
                    } label: { Label("Change Units", systemImage: "arrow.left.arrow.right.circle.fill") }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }

            // MARK: Home screen layout
            settingsCard("Home Screen Layout", "square.grid.2x2.fill") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(VisualMode.allCases) { mode in
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { settings.visualMode = mode }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: mode.symbol).foregroundColor(settings.visualMode == mode ? .white : Palette.amberDeep)
                                    .frame(width: 24)
                                Text(mode.rawValue).font(.system(size: 15, weight: .semibold))
                                Spacer()
                                if settings.visualMode == mode { Image(systemName: "checkmark.circle.fill") }
                            }
                            .foregroundColor(settings.visualMode == mode ? .white : Palette.primaryText(scheme))
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12)
                                .fill(settings.visualMode == mode ? Palette.amber : Palette.cardFill(scheme).opacity(0.5)))
                        }
                    }
                }
            }

            // MARK: Care priorities
            settingsCard("Care Priorities", "star.fill") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Chosen priorities lift their cards higher on the dashboard.")
                        .font(.system(size: 12)).foregroundColor(Palette.secondaryText(scheme))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(CarePriority.allCases) { p in
                                Button {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        if settings.priorities.contains(p) { settings.priorities.remove(p) }
                                        else { settings.priorities.insert(p) }
                                    }
                                } label: {
                                    Chip(text: p.rawValue, symbol: p.symbol, color: Palette.amber,
                                         selected: settings.priorities.contains(p))
                                }
                            }
                        }
                    }
                }
            }

            // MARK: Notifications
            settingsCard("Local Notifications", "bell.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    ToggleRow(icon: "bell.badge.fill", title: "Enable reminders",
                              subtitle: "Schedules your local reminder times",
                              isOn: Binding(
                                get: { settings.notificationsEnabled },
                                set: { v in
                                    settings.notificationsEnabled = v
                                    if v {
                                        store.requestNotificationAuth { granted in
                                            if granted { store.syncNotifications(enabled: true) }
                                            else { settings.notificationsEnabled = false; toastMessage = "Permission denied" }
                                        }
                                    } else {
                                        store.syncNotifications(enabled: false)
                                    }
                                }))
                    Divider().background(Palette.cardStroke(scheme))
                    ToggleRow(icon: "tag.fill", title: "Color labels",
                              subtitle: "Show colored markers on group cards",
                              isOn: $settings.colorLabelsEnabled)
                    NavigationLink(destination: ReminderQueueView()) {
                        Text("Manage reminders →").font(.system(size: 13, weight: .bold)).foregroundColor(Palette.amberDeep)
                    }
                }
            }

            // MARK: Data
            settingsCard("Data", "externaldrive.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    InfoRow(label: "Groups", value: "\(store.data.groups.count)")
                    InfoRow(label: "Entries", value: "\(store.data.entries.count)")
                    InfoRow(label: "Stored", value: "On this device only")
                    Button { showResetAlert = true } label: {
                        Label("Reset Sample Data", systemImage: "arrow.counterclockwise.circle.fill")
                    }
                    .buttonStyle(SecondaryButtonStyle(color: Palette.danger))
                }
            }

            // MARK: About
            CoopCard {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Image(systemName: "house.fill").foregroundColor(Palette.amberDeep)
                        Text("Roam Keeper").font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(Palette.primaryText(scheme))
                        Spacer()
                        Text("v1.0").font(.system(size: 13)).foregroundColor(Palette.secondaryText(scheme))
                    }
                    Text("Offline free-range, zone and return-time control. No sign-up, no account — every record lives on your device.")
                        .font(.system(size: 12)).foregroundColor(Palette.secondaryText(scheme))
                }
            }
        }
        .alert(isPresented: $showResetAlert) {
            Alert(
                title: Text("Reset sample data?"),
                message: Text("This replaces all current records with the built-in sample farm. This cannot be undone."),
                primaryButton: .destructive(Text("Reset")) {
                    store.resetToSample()
                    store.syncNotifications(enabled: settings.notificationsEnabled)
                    toastMessage = "Sample data restored"
                },
                secondaryButton: .cancel()
            )
        }
        .toast($toastMessage)
    }

    @ViewBuilder
    private func settingsCard<Content: View>(_ title: String, _ icon: String,
                                             @ViewBuilder content: @escaping () -> Content) -> some View {
        CoopCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundColor(Palette.amberDeep)
                    Text(title).font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Palette.primaryText(scheme))
                }
                content()
            }
        }
    }
}
