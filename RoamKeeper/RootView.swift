//
//  RootView.swift
//  RoamKeeper
//
//  Flow coordinator (Splash → Onboarding → Main) plus the custom tab bar
//  and the "More" hub that reaches every remaining screen.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var showSplash = true

    var body: some View {
        ZStack {
            if showSplash {
                LaunchView {
                    withAnimation(.easeInOut(duration: 0.5)) { showSplash = false }
                }
                .transition(.opacity)
                .zIndex(2)
            } else if !settings.hasCompletedOnboarding {
                OnboardingView()
                    .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
    }
}

// MARK: - Main tab container

enum MainTab: Int, CaseIterable, Identifiable {
    case home, groups, care, routes, more
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .home: return "Board"
        case .groups: return "Groups"
        case .care: return "Care"
        case .routes: return "Routes"
        case .more: return "More"
        }
    }
    var icon: String {
        switch self {
        case .home: return "square.grid.2x2.fill"
        case .groups: return "hare.fill"
        case .care: return "list.bullet.rectangle"
        case .routes: return "map.fill"
        case .more: return "ellipsis.circle.fill"
        }
    }
}

struct MainTabView: View {
    @State private var tab: MainTab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .home:
                    NavigationView { DashboardView() }
                        .navigationViewStyle(StackNavigationViewStyle())
                case .groups:
                    NavigationView { GroupBuilderView() }
                        .navigationViewStyle(StackNavigationViewStyle())
                case .care:
                    NavigationView { CareHubView() }
                        .navigationViewStyle(StackNavigationViewStyle())
                case .routes:
                    NavigationView { RoutePlannerView() }
                        .navigationViewStyle(StackNavigationViewStyle())
                case .more:
                    NavigationView { MoreHubView() }
                        .navigationViewStyle(StackNavigationViewStyle())
                }
            }
            CustomTabBar(selection: $tab)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

// MARK: - Custom tab bar

struct CustomTabBar: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var selection: MainTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases) { t in
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { selection = t }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            if selection == t {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Palette.amber)
                                    .frame(width: 46, height: 34)
                                    .shadow(color: Palette.amber.opacity(0.5), radius: 6, y: 3)
                            }
                            if t == .groups {
                                BirdMark(size: 20, color: selection == t ? .white : Palette.secondaryText(scheme))
                            } else {
                                Image(systemName: t.icon)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(selection == t ? .white : Palette.secondaryText(scheme))
                            }
                        }
                        Text(t.title)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(selection == t ? Palette.amberDeep : Palette.secondaryText(scheme))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(scheme == .dark ? Color(hex: 0x1F1812) : Color(hex: 0xFBF4E7))
                .shadow(color: .black.opacity(scheme == .dark ? 0.5 : 0.15), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Palette.cardStroke(scheme), lineWidth: 1)
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
    }
}

// MARK: - More hub

enum HubDestination: String, CaseIterable, Identifiable {
    case inventory, costs, tasks, reminders, notes, photo, alerts, dailyReview
    case analytics, compare, reports, transport, capacity, zones, quickAdd, settings

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .inventory: return "shippingbox.fill"
        case .costs: return "dollarsign.circle.fill"
        case .tasks: return "list.bullet.rectangle"
        case .reminders: return "bell.fill"
        case .notes: return "note.text"
        case .photo: return "photo.fill"
        case .alerts: return "exclamationmark.triangle.fill"
        case .dailyReview: return "moon.stars.fill"
        case .analytics: return "chart.bar.fill"
        case .compare: return "chart.bar.xaxis"
        case .reports: return "doc.text.fill"
        case .transport: return "shippingbox.fill"
        case .capacity: return "ruler.fill"
        case .zones: return "map.fill"
        case .quickAdd: return "plus.circle.fill"
        case .settings: return "gearshape.fill"
        }
    }
    var title: String {
        switch self {
        case .inventory: return "Inventory"
        case .costs: return "Costs"
        case .tasks: return "Tasks"
        case .reminders: return "Reminders"
        case .notes: return "Notes"
        case .photo: return "Photo Notes"
        case .alerts: return "Alerts"
        case .dailyReview: return "Daily Review"
        case .analytics: return "Analytics"
        case .compare: return "Compare"
        case .reports: return "Reports"
        case .transport: return "Transport"
        case .capacity: return "Capacity"
        case .zones: return "Coop Zones"
        case .quickAdd: return "Quick Add"
        case .settings: return "Settings"
        }
    }
    var subtitle: String {
        switch self {
        case .inventory: return "Supplies & low stock"
        case .costs: return "Farm spending"
        case .tasks: return "Priorities & due dates"
        case .reminders: return "Local nudges"
        case .notes: return "Zone-linked cards"
        case .photo: return "Mark a problem area"
        case .alerts: return "Risk flags"
        case .dailyReview: return "Close out the day"
        case .analytics: return "Weekly trends"
        case .compare: return "Groups & zones"
        case .reports: return "Build & export"
        case .transport: return "Transit checklist"
        case .capacity: return "Space & perch"
        case .zones: return "Define your farm"
        case .quickAdd: return "Log an event"
        case .settings: return "App preferences"
        }
    }
    var color: Color {
        switch self {
        case .inventory, .photo, .transport: return Palette.clay
        case .costs, .compare, .zones: return Palette.sage
        case .tasks, .quickAdd: return Palette.amber
        case .reminders, .reports: return Palette.berry
        case .notes, .dailyReview, .capacity: return Palette.sky
        case .alerts: return Palette.danger
        case .analytics: return Palette.amberDeep
        case .settings: return Palette.slateColor
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .inventory: InventoryShelfView()
        case .costs: CostTrackerView()
        case .tasks: TaskBoardView()
        case .reminders: ReminderQueueView()
        case .notes: NotesBoardView()
        case .photo: PhotoMarkupView()
        case .alerts: RiskFlagsView()
        case .dailyReview: DailyReviewView()
        case .analytics: WeeklyAnalyticsView()
        case .compare: TrendCompareView()
        case .reports: ReportBuilderView()
        case .transport: TransportPrepView()
        case .capacity: CapacityCalculatorView()
        case .zones: ZonesView()
        case .quickAdd: QuickAddView()
        case .settings: SettingsView()
        }
    }
}

struct MoreHubView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScreenScaffold(icon: "ellipsis.circle.fill", title: "More Tools",
                       subtitle: "Every Roam Keeper section") {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14),
                                GridItem(.flexible(), spacing: 14)], spacing: 14) {
                ForEach(HubDestination.allCases) { dest in
                    NavigationLink(destination: dest.destination) {
                        hubCard(dest)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private func hubCard(_ dest: HubDestination) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(dest.color.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: dest.icon)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(dest.color)
            }
            Text(dest.title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(Palette.primaryText(scheme))
            Text(dest.subtitle)
                .font(.system(size: 12))
                .foregroundColor(Palette.secondaryText(scheme))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

extension Palette {
    static var slateColor: Color { Color(hex: 0x6B7385) }
}
