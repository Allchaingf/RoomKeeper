//
//  DashboardView.swift
//  RoamKeeper
//
//  Screen 1 — Today Overview. Surfaces roam/return status, today's actions
//  and quick alerts. Renders in one of three visual modes chosen in
//  onboarding (Coop Map / Route List / Ledger).
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) private var scheme

    @State private var showQuickAdd = false
    @State private var showRelease = false
    @State private var now = Date()

    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        ScreenScaffold(icon: "square.grid.2x2.fill", title: "Today Overview",
                       subtitle: greeting) {

            statsRow

            // Action buttons
            HStack(spacing: 12) {
                Button { showQuickAdd = true } label: {
                    Label("Add Record", systemImage: "plus.circle.fill")
                }
                .buttonStyle(PrimaryButtonStyle(color: Palette.amber))

                NavigationLink(destination: WeeklyAnalyticsView()) {
                    Label("Open Analytics", systemImage: "chart.bar.fill")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            roamSection

            actionsSection

            // Visual-mode specific board
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionHeader(icon: settings.visualMode.symbol, title: settings.visualMode.rawValue)
                    Spacer()
                }
                switch settings.visualMode {
                case .coopMap: coopMapBoard
                case .routeList: routeListBoard
                case .ledger: ledgerBoard
                }
            }

            alertsSection
        }
        .onReceive(ticker) { now = $0 }
        .onAppear { now = Date() }
        .sheet(isPresented: $showQuickAdd) { QuickAddView().environmentObject(store).environmentObject(settings) }
        .sheet(isPresented: $showRelease) { AddRoamSessionView().environmentObject(store) }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: now)
        let part = h < 12 ? "Good morning" : (h < 18 ? "Good afternoon" : "Good evening")
        return "\(part) · \(AppStore.dateString(now))"
    }

    // MARK: Stats

    private var statsRow: some View {
        let out = store.activeRoamSessions(now: now).count
        let cons = Int((store.consistency(now: now) * 100).rounded())
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatTile(value: "\(store.totalBirds)", label: "Birds across \(store.data.groups.count) groups",
                         symbol: "hare.fill", color: Palette.amber, useBird: true)
                StatTile(value: "\(out)", label: out == 1 ? "Group out on range" : "Groups out on range",
                         symbol: "sun.max.fill", color: Palette.sky)
            }
            HStack(spacing: 12) {
                StatTile(value: "\(cons)%", label: "7-day care consistency",
                         symbol: "checkmark.seal.fill", color: Palette.sage)
                StatTile(value: "\(store.lowStockItems.count)", label: "Supplies below minimum",
                         symbol: "shippingbox.fill", color: Palette.clay)
            }
        }
    }

    // MARK: Roam / return

    private var roamSection: some View {
        let sessions = store.activeRoamSessions(now: now)
        return CoopCard(accent: Palette.sky) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Free-range control", systemImage: "sun.max.fill")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Palette.primaryText(scheme))
                    Spacer()
                    Button { showRelease = true } label: {
                        Label("Release", systemImage: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Capsule().fill(Palette.sky))
                    }
                }
                if sessions.isEmpty {
                    Text("No flock is out right now. Tap Release when you open the range.")
                        .font(.system(size: 13))
                        .foregroundColor(Palette.secondaryText(scheme))
                } else {
                    ForEach(sessions) { s in roamRow(s) }
                }
            }
        }
    }

    private func roamRow(_ s: RoamSession) -> some View {
        let status = s.status(now: now)
        let color: Color = status == .overdue ? Palette.danger : Palette.sky
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.18)).frame(width: 38, height: 38)
                Image(systemName: status == .overdue ? "moon.fill" : "sun.max.fill")
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(store.groupName(s.groupId))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Palette.primaryText(scheme))
                Text("Out since \(AppStore.timeString(s.releaseTime)) · due \(AppStore.timeString(s.expectedReturn))")
                    .font(.system(size: 12))
                    .foregroundColor(Palette.secondaryText(scheme))
            }
            Spacer()
            Button {
                withAnimation { store.markReturned(s, at: now) }
            } label: {
                Text(status == .overdue ? "Return!" : "Return")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Capsule().fill(color))
            }
        }
    }

    // MARK: Today's actions

    private var actionsSection: some View {
        let actions = store.dashboardActions(priorities: settings.priorities, now: now)
        return Group {
            if !actions.isEmpty {
                CoopCard(accent: Palette.amber) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("What to do today", systemImage: "list.bullet.rectangle")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(Palette.primaryText(scheme))
                        ForEach(actions) { a in
                            HStack(spacing: 12) {
                                Image(systemName: a.symbol)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(a.color)
                                    .frame(width: 26)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(a.title).font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Palette.primaryText(scheme))
                                    Text(a.detail).font(.system(size: 12))
                                        .foregroundColor(Palette.secondaryText(scheme))
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Visual mode — Coop Map

    private var coopMapBoard: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(store.data.zones.sorted { $0.order < $1.order }) { zone in
                let groups = store.data.groups.filter { $0.zoneId == zone.id }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: zone.kind.symbol).foregroundColor(Palette.amberDeep)
                        Text(zone.name).font(.system(size: 14, weight: .bold))
                            .foregroundColor(Palette.primaryText(scheme))
                            .lineLimit(1)
                    }
                    if groups.isEmpty {
                        Text("Empty").font(.system(size: 12)).foregroundColor(Palette.secondaryText(scheme))
                    } else {
                        ForEach(groups) { g in
                            HStack(spacing: 6) {
                                Circle().fill(g.tag.color).frame(width: 8, height: 8)
                                Text("\(g.name) · \(g.count)")
                                    .font(.system(size: 12))
                                    .foregroundColor(Palette.secondaryText(scheme))
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(Palette.cardFill(scheme)))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.cardStroke(scheme), lineWidth: 1))
            }
        }
    }

    // MARK: Visual mode — Route List

    private var routeListBoard: some View {
        CoopCard {
            VStack(alignment: .leading, spacing: 0) {
                let stops = store.data.routeStops.sorted { $0.order < $1.order }
                if stops.isEmpty {
                    EmptyHint(symbol: "map", title: "No route yet", message: "Build a care route in the Routes tab.")
                } else {
                    ForEach(Array(stops.enumerated()), id: \.element.id) { idx, stop in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(Palette.amber).frame(width: 26, height: 26)
                                Text("\(idx + 1)").font(.system(size: 13, weight: .heavy)).foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(stop.label).font(.system(size: 15, weight: .bold))
                                    .foregroundColor(Palette.primaryText(scheme))
                                Text("~\(stop.minutes) min").font(.system(size: 12))
                                    .foregroundColor(Palette.secondaryText(scheme))
                            }
                            Spacer()
                            Image(systemName: "arrow.down").foregroundColor(Palette.secondaryText(scheme))
                                .opacity(idx == stops.count - 1 ? 0 : 1)
                        }
                        .padding(.vertical, 8)
                        if idx != stops.count - 1 { Divider().background(Palette.cardStroke(scheme)) }
                    }
                }
            }
        }
    }

    // MARK: Visual mode — Ledger

    private var ledgerBoard: some View {
        CoopCard {
            VStack(alignment: .leading, spacing: 0) {
                let entries = Array(store.data.entries.prefix(8))
                if entries.isEmpty {
                    EmptyHint(symbol: "tablecells", title: "No entries yet", message: "Use Quick Add to log your first event.")
                } else {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { idx, e in
                        HStack(spacing: 10) {
                            Image(systemName: e.kind.symbol)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Palette.amberDeep)
                                .frame(width: 22)
                            Text(e.kind.rawValue).font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Palette.primaryText(scheme))
                            Spacer()
                            Text(AppStore.timeString(e.date)).font(.system(size: 12))
                                .foregroundColor(Palette.secondaryText(scheme))
                        }
                        .padding(.vertical, 7)
                        if idx != entries.count - 1 { Divider().background(Palette.cardStroke(scheme)) }
                    }
                }
            }
        }
    }

    // MARK: Alerts

    private var alertsSection: some View {
        let flags = Array(store.riskFlags(now: now).prefix(3))
        return Group {
            if !flags.isEmpty {
                CoopCard(accent: Palette.danger) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Quick alerts", systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(Palette.primaryText(scheme))
                            Spacer()
                            NavigationLink(destination: RiskFlagsView()) {
                                Text("All").font(.system(size: 13, weight: .bold)).foregroundColor(Palette.amberDeep)
                            }
                        }
                        ForEach(flags) { f in
                            HStack(spacing: 10) {
                                Image(systemName: f.symbol).foregroundColor(f.severity.color).frame(width: 22)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(f.title).font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Palette.primaryText(scheme))
                                    Text(f.detail).font(.system(size: 12))
                                        .foregroundColor(Palette.secondaryText(scheme)).lineLimit(1)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Release a flock (start a roam session)

struct AddRoamSessionView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.colorScheme) private var scheme

    @State private var groupId: UUID?
    @State private var zoneId: UUID?
    @State private var releaseTime = Date()
    @State private var expectedReturn = Date().addingTimeInterval(3 * 3600)
    @State private var note = ""

    var body: some View {
        NavigationView {
            ZStack {
                BarnWoodBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(icon: "sun.max.fill", title: "Release Flock",
                                      subtitle: "Track who's out and when they're due back")

                        VStack(alignment: .leading, spacing: 6) {
                            FieldLabel(text: "Group")
                            Menu {
                                ForEach(store.data.groups) { g in
                                    Button(g.name) { groupId = g.id }
                                }
                            } label: {
                                HStack {
                                    Text(store.groupName(groupId))
                                        .foregroundColor(Palette.primaryText(scheme))
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down").foregroundColor(Palette.secondaryText(scheme))
                                }.fieldChrome()
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            FieldLabel(text: "Range zone")
                            Menu {
                                ForEach(store.data.zones) { z in
                                    Button(z.name) { zoneId = z.id }
                                }
                            } label: {
                                HStack {
                                    Text(store.zoneName(zoneId))
                                        .foregroundColor(Palette.primaryText(scheme))
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down").foregroundColor(Palette.secondaryText(scheme))
                                }.fieldChrome()
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            FieldLabel(text: "Release time")
                            DatePicker("", selection: $releaseTime, displayedComponents: [.hourAndMinute])
                                .labelsHidden().datePickerStyle(CompactDatePickerStyle())
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            FieldLabel(text: "Expected return")
                            DatePicker("", selection: $expectedReturn, displayedComponents: [.hourAndMinute])
                                .labelsHidden().datePickerStyle(CompactDatePickerStyle())
                        }

                        ThemedField(title: "Note", placeholder: "Optional", text: $note)

                        Button {
                            let s = RoamSession(groupId: groupId ?? store.data.groups.first?.id,
                                                zoneId: zoneId ?? store.data.zones.first?.id,
                                                releaseTime: releaseTime, expectedReturn: expectedReturn,
                                                actualReturn: nil, note: note)
                            store.data.roamSessions.insert(s, at: 0)
                            store.addEntry(CareEntry(date: releaseTime, kind: .release,
                                                     groupId: s.groupId, zoneId: s.zoneId,
                                                     detail: "Released to range"))
                            presentationMode.wrappedValue.dismiss()
                        } label: {
                            Label("Confirm Release", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle(color: Palette.sky))
                        .padding(.top, 4)
                    }
                    .padding(16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .onAppear {
                if groupId == nil { groupId = store.data.groups.first?.id }
                if zoneId == nil { zoneId = store.data.zones.first(where: { $0.kind == .yard })?.id ?? store.data.zones.first?.id }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
