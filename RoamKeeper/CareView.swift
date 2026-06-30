//
//  CareView.swift
//  RoamKeeper
//
//  Care Logs section: hub + Screen 19 (Daily Care Checklist), 20 (Feed
//  Planner), 21 (Water Log), 22 (Health Observation), 23 (Cleaning
//  Schedule), and Screen 15 (Quick Add).
//

import SwiftUI

// MARK: - Care hub (Care Logs landing)

struct CareHubView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScreenScaffold(icon: "list.bullet.rectangle", title: "Care Logs",
                       subtitle: "Daily routine, feed, water & health") {
            let p = store.todayChecklistProgress()
            CoopCard(accent: Palette.sage) {
                HStack(spacing: 16) {
                    RingProgress(progress: store.consistency(), color: Palette.sage,
                                 centerLabel: "\(Int((store.consistency() * 100).rounded()))%")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("7-day consistency")
                            .font(.system(size: 15, weight: .bold)).foregroundColor(Palette.primaryText(scheme))
                        Text("Today: \(p.done)/\(p.total) checks done")
                            .font(.system(size: 13)).foregroundColor(Palette.secondaryText(scheme))
                        NavigationLink(destination: DailyChecklistView()) {
                            Text("Open checklist →")
                                .font(.system(size: 13, weight: .bold)).foregroundColor(Palette.amberDeep)
                        }
                    }
                    Spacer()
                }
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                careTile("list.bullet.rectangle", "Daily Checks", Palette.amber) { DailyChecklistView() }
                careTile("leaf.fill", "Feed Planner", Palette.sage) { FeedPlannerView() }
                careTile("drop.fill", "Water & Heat", Palette.sky) { WaterLogView() }
                careTile("heart.text.square.fill", "Health Log", Palette.berry) { HealthObservationView() }
                careTile("sparkles", "Cleaning", Palette.clay) { CleaningScheduleView() }
                careTile("plus.circle.fill", "Quick Add", Palette.amberDeep) { QuickAddView() }
            }

            SectionHeader(icon: "clock.arrow.circlepath", title: "Recent entries")
            NavigationLink(destination: CareLogsListView()) {
                Text("View full journal →").font(.system(size: 13, weight: .bold)).foregroundColor(Palette.amberDeep)
            }
            if store.data.entries.isEmpty {
                EmptyHint(symbol: "tray", title: "No entries", message: "Log your first care event with Quick Add.")
            } else {
                ForEach(Array(store.data.entries.prefix(5))) { e in entryRow(e) }
            }
        }
    }

    @ViewBuilder
    private func careTile<D: View>(_ icon: String, _ title: String, _ color: Color,
                                   @ViewBuilder destination: @escaping () -> D) -> some View {
        NavigationLink(destination: destination()) {
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(color.opacity(0.18)).frame(width: 46, height: 46)
                    Image(systemName: icon).font(.system(size: 20, weight: .bold)).foregroundColor(color)
                }
                Text(title).font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Palette.primaryText(scheme))
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .background(RoundedRectangle(cornerRadius: 16).fill(Palette.cardFill(scheme)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.cardStroke(scheme), lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func entryRow(_ e: CareEntry) -> some View {
        CoopCard {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Palette.amber.opacity(0.18)).frame(width: 36, height: 36)
                    Image(systemName: e.kind.symbol).foregroundColor(Palette.amberDeep)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(e.kind.rawValue).font(.system(size: 14, weight: .bold))
                        .foregroundColor(Palette.primaryText(scheme))
                    Text("\(store.groupName(e.groupId)) · \(e.detail.isEmpty ? store.zoneName(e.zoneId) : e.detail)")
                        .font(.system(size: 12)).foregroundColor(Palette.secondaryText(scheme)).lineLimit(1)
                }
                Spacer()
                Text(AppStore.timeString(e.date)).font(.system(size: 12))
                    .foregroundColor(Palette.secondaryText(scheme))
            }
        }
    }
}

// MARK: - Screen 19: Daily Care Checklist

struct DailyChecklistView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) private var scheme
    @State private var period: CheckPeriod = .morning
    @State private var toastMessage: String?
    @State private var refresh = false   // forces recompute after store mutation

    var body: some View {
        ScreenScaffold(icon: "list.bullet.rectangle", title: "Morning / Evening Checks",
                       subtitle: "Closed items raise your consistency") {
            EnumChips(title: "Period", options: CheckPeriod.allCases, selection: $period,
                      label: { $0.rawValue }, symbol: { $0.symbol })

            let items = Checklist.items(for: period)
            CoopCard(accent: period == .morning ? Palette.amber : Palette.sky) {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                        let on = store.isChecked(date: Date(), period: period, item: item.id)
                        Button {
                            store.setChecked(!on, date: Date(), period: period, item: item.id)
                            refresh.toggle()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundColor(on ? Palette.sage : Palette.secondaryText(scheme))
                                Image(systemName: item.symbol).foregroundColor(Palette.amberDeep).frame(width: 24)
                                Text(item.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Palette.primaryText(scheme))
                                    .strikethrough(on, color: Palette.secondaryText(scheme))
                                Spacer()
                            }
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(PlainButtonStyle())
                        if idx != items.count - 1 { Divider().background(Palette.cardStroke(scheme)) }
                    }
                }
            }

            HStack(spacing: 12) {
                Button {
                    for item in items { store.setChecked(true, date: Date(), period: period, item: item.id) }
                    refresh.toggle()
                    toastMessage = "\(period.rawValue) checks done"
                } label: { Label("Mark Done", systemImage: "checkmark.circle.fill") }
                .buttonStyle(PrimaryButtonStyle(color: Palette.sage))

                Button {
                    for item in items { store.setChecked(false, date: Date(), period: period, item: item.id) }
                    refresh.toggle()
                    toastMessage = "Skipped today"
                } label: { Label("Skip Today", systemImage: "xmark.circle") }
                .buttonStyle(SecondaryButtonStyle())
            }

            // 7-day consistency strip
            CoopCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Last 7 days").font(.system(size: 14, weight: .bold))
                        .foregroundColor(Palette.primaryText(scheme))
                    LineChart(values: store.consistencySeries(), color: Palette.sage, height: 90)
                    Text("Consistency over the week (%).").font(.system(size: 12))
                        .foregroundColor(Palette.secondaryText(scheme))
                }
            }
            .id(refresh)
        }
        .toast($toastMessage)
    }
}

// MARK: - Screen 20: Feed Planner

struct FeedPlannerView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) private var scheme

    @State private var groupId: UUID?
    @State private var gramsPerBird = 120.0
    @State private var days = 7
    @State private var toastMessage: String?

    private var birds: Int { store.group(groupId)?.count ?? 0 }
    private var total: Double { gramsPerBird * Double(birds) * Double(days) }

    private var feedStockKg: Double {
        store.data.inventory.filter { $0.category == .feed }.reduce(0) { $0 + $1.quantity }
    }
    private var dailyGrams: Double {
        store.data.feedPortions.reduce(0) { $0 + ($1.gramsPerBird * Double($1.birds)) }
    }
    private var forecastDays: Int {
        let daily = dailyGrams > 0 ? dailyGrams : gramsPerBird * Double(Swift.max(birds, 1))
        return daily > 0 ? Int(feedStockKg * 1000 / daily) : 0
    }

    var body: some View {
        ScreenScaffold(icon: "leaf.fill", title: "Feed Portions",
                       subtitle: "Plan rations & forecast restock") {
            CoopCard(accent: Palette.sage) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: "Group")
                        Menu {
                            ForEach(store.data.groups) { g in Button("\(g.name) (\(g.count))") { groupId = g.id } }
                        } label: {
                            HStack {
                                Text(store.group(groupId).map { "\($0.name) · \($0.count) birds" } ?? "Select group")
                                    .foregroundColor(Palette.primaryText(scheme))
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down").foregroundColor(Palette.secondaryText(scheme))
                            }.fieldChrome()
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: "Grams per bird / day: \(Int(gramsPerBird)) g")
                        Slider(value: $gramsPerBird, in: 40...250, step: 5)
                            .accentColor(Palette.sage)
                    }
                    StepperRow(title: "Days", value: $days, range: 1...60)
                    Divider().background(Palette.cardStroke(scheme))
                    InfoRow(label: "Birds", value: "\(birds)")
                    InfoRow(label: "Total feed needed", value: Measure.weight(total, settings.units), color: Palette.sage)
                }
            }

            HStack(spacing: 12) {
                Button {
                    let p = FeedPortion(groupId: groupId, gramsPerBird: gramsPerBird, birds: birds, days: days, date: Date())
                    store.data.feedPortions.insert(p, at: 0)
                    store.addEntry(CareEntry(date: Date(), kind: .feeding, groupId: groupId, zoneId: store.group(groupId)?.zoneId,
                                             detail: "Planned \(Measure.weight(total, settings.units)) over \(days)d"))
                    toastMessage = "Portion added"
                } label: { Label("Add Portion", systemImage: "plus.circle.fill") }
                .buttonStyle(PrimaryButtonStyle(color: Palette.sage))
                .disabled(groupId == nil).opacity(groupId == nil ? 0.6 : 1)

                Button {
                    // Deduct planned feed (kg) from feed stock.
                    let needKg = total / 1000
                    if let idx = store.data.inventory.firstIndex(where: { $0.category == .feed }) {
                        store.data.inventory[idx].quantity = Swift.max(0, store.data.inventory[idx].quantity - needKg)
                        toastMessage = "Stock updated"
                    } else {
                        toastMessage = "No feed in stock"
                    }
                } label: { Label("Update Stock", systemImage: "shippingbox.fill") }
                .buttonStyle(SecondaryButtonStyle())
            }

            CoopCard(accent: forecastDays < 5 ? Palette.danger : Palette.amber) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Restock forecast", systemImage: "calendar.badge.clock")
                        .font(.system(size: 15, weight: .bold)).foregroundColor(Palette.primaryText(scheme))
                    InfoRow(label: "Feed in stock", value: "\(store.trim(feedStockKg)) kg")
                    InfoRow(label: "Runs out in", value: "\(forecastDays) days",
                            color: forecastDays < 5 ? Palette.danger : Palette.sage)
                }
            }

            if !store.data.feedPortions.isEmpty {
                SectionHeader(icon: "clock.arrow.circlepath", title: "Saved portions")
                ForEach(store.data.feedPortions) { p in
                    CoopCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.groupName(p.groupId)).font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Palette.primaryText(scheme))
                                Text("\(Int(p.gramsPerBird)) g/bird · \(p.birds) birds · \(p.days)d")
                                    .font(.system(size: 12)).foregroundColor(Palette.secondaryText(scheme))
                            }
                            Spacer()
                            Text(Measure.weight(p.totalGrams, settings.units))
                                .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(Palette.sage)
                            Button { store.data.feedPortions.removeAll { $0.id == p.id } } label: {
                                Image(systemName: "trash").foregroundColor(Palette.danger)
                            }.padding(.leading, 6)
                        }
                    }
                }
            }
        }
        .onAppear { if groupId == nil { groupId = store.data.groups.first?.id } }
        .toast($toastMessage)
    }
}

// MARK: - Screen 21: Water Log

struct WaterLogView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) private var scheme

    @State private var zoneId: UUID?
    @State private var waterOk = true
    @State private var ventilationOk = true
    @State private var watererClean = true
    @State private var tempText = ""
    @State private var note = ""
    @State private var toastMessage: String?

    var body: some View {
        ScreenScaffold(icon: "drop.fill", title: "Water & Heat Notes",
                       subtitle: "Early signals before they become problems") {
            CoopCard(accent: Palette.sky) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: "Zone")
                        Menu {
                            ForEach(store.data.zones) { z in Button(z.name) { zoneId = z.id } }
                        } label: {
                            HStack {
                                Text(store.zoneName(zoneId)).foregroundColor(Palette.primaryText(scheme))
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down").foregroundColor(Palette.secondaryText(scheme))
                            }.fieldChrome()
                        }
                    }
                    ToggleRow(icon: "drop.fill", title: "Water supply OK", isOn: $waterOk, tint: Palette.sky)
                    ToggleRow(icon: "wind", title: "Ventilation OK", isOn: $ventilationOk, tint: Palette.sage)
                    ToggleRow(icon: "sparkles", title: "Waterer clean", isOn: $watererClean, tint: Palette.amber)
                    ThemedField(title: "Temperature (\(settings.units.tempUnit))", placeholder: "0", text: $tempText, keyboard: .numbersAndPunctuation)
                    ThemedField(title: "Note", placeholder: "Optional", text: $note)
                }
            }

            HStack(spacing: 12) {
                Button {
                    let tempC = Measure.tempToMetric(Double(tempText) ?? 0, settings.units)
                    let log = WaterLog(date: Date(), zoneId: zoneId, waterOk: waterOk, tempC: tempC,
                                       ventilationOk: ventilationOk, watererClean: watererClean, note: note)
                    store.data.waterLogs.insert(log, at: 0)
                    store.addEntry(CareEntry(date: Date(), kind: .water, groupId: nil, zoneId: zoneId, detail: "Water check"))
                    toastMessage = "Check logged"
                } label: { Label("Log Check", systemImage: "checkmark.circle.fill") }
                .buttonStyle(PrimaryButtonStyle(color: Palette.sky))

                Button {
                    let task = FarmTask(title: "Check water — \(store.zoneName(zoneId))", priority: .high,
                                        category: .control, dueDate: Date(), zoneId: zoneId)
                    store.data.tasks.insert(task, at: 0)
                    toastMessage = "Alert task added"
                } label: { Label("Add Alert", systemImage: "exclamationmark.triangle.fill") }
                .buttonStyle(SecondaryButtonStyle())
            }

            if !store.data.waterLogs.isEmpty {
                SectionHeader(icon: "clock.arrow.circlepath", title: "Recent checks")
                ForEach(store.data.waterLogs.prefix(8)) { log in
                    CoopCard(accent: (log.waterOk && log.ventilationOk) ? Palette.sky : Palette.danger) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.zoneName(log.zoneId)).font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Palette.primaryText(scheme))
                                Text("\(store.trim(Measure.temp(log.tempC, settings.units)))\(settings.units.tempUnit) · \(log.waterOk ? "water ok" : "water LOW") · \(AppStore.dateString(log.date))")
                                    .font(.system(size: 12)).foregroundColor(Palette.secondaryText(scheme))
                            }
                            Spacer()
                            Button { store.data.waterLogs.removeAll { $0.id == log.id } } label: {
                                Image(systemName: "trash").foregroundColor(Palette.danger)
                            }
                        }
                    }
                }
            }
        }
        .onAppear { if zoneId == nil { zoneId = store.data.zones.first?.id } }
        .toast($toastMessage)
    }
}

// MARK: - Screen 22: Health Observation

struct HealthObservationView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) private var scheme

    @State private var groupId: UUID?
    @State private var activity = 4
    @State private var appetite = 4
    @State private var appearance = 4
    @State private var note = ""
    @State private var toastMessage: String?

    var body: some View {
        ScreenScaffold(icon: "heart.text.square.fill", title: "Observation Log",
                       subtitle: "Notes only — no diagnoses") {
            CoopCard(accent: Palette.berry) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: "Group")
                        Menu {
                            ForEach(store.data.groups) { g in Button(g.name) { groupId = g.id } }
                        } label: {
                            HStack {
                                Text(store.groupName(groupId)).foregroundColor(Palette.primaryText(scheme))
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down").foregroundColor(Palette.secondaryText(scheme))
                            }.fieldChrome()
                        }
                    }
                    ratingRow("Activity", $activity)
                    ratingRow("Appetite", $appetite)
                    ratingRow("Appearance", $appearance)
                    ThemedField(title: "Note", placeholder: "What did you notice?", text: $note)
                }
            }

            HStack(spacing: 12) {
                Button { save(flag: false); toastMessage = "Observation saved" } label: {
                    Label("Add Symptom", systemImage: "plus.circle.fill")
                }
                .buttonStyle(PrimaryButtonStyle(color: Palette.berry))

                Button { save(flag: true); toastMessage = "Group flagged" } label: {
                    Label("Flag Group", systemImage: "flag.fill")
                }
                .buttonStyle(SecondaryButtonStyle(color: Palette.danger))
            }

            if !store.data.healthObs.isEmpty {
                SectionHeader(icon: "clock.arrow.circlepath", title: "Recent observations")
                ForEach(store.data.healthObs.prefix(8)) { o in
                    CoopCard(accent: o.flagged ? Palette.danger : Palette.berry) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(store.groupName(o.groupId)).font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Palette.primaryText(scheme))
                                    if o.flagged {
                                        Image(systemName: "flag.fill").font(.system(size: 11)).foregroundColor(Palette.danger)
                                    }
                                }
                                Text("Act \(o.activity) · App \(o.appetite) · Look \(o.appearance) · \(AppStore.dateString(o.date))")
                                    .font(.system(size: 12)).foregroundColor(Palette.secondaryText(scheme))
                            }
                            Spacer()
                            Button { store.data.healthObs.removeAll { $0.id == o.id } } label: {
                                Image(systemName: "trash").foregroundColor(Palette.danger)
                            }
                        }
                    }
                }
            }
        }
        .onAppear { if groupId == nil { groupId = store.data.groups.first?.id } }
        .toast($toastMessage)
    }

    private func ratingRow(_ title: String, _ value: Binding<Int>) -> some View {
        HStack {
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(Palette.secondaryText(scheme))
            Spacer()
            StarRating(value: value, color: Palette.berry)
        }
    }

    private func save(flag: Bool) {
        let o = HealthObservation(date: Date(), groupId: groupId, activity: activity,
                                  appetite: appetite, appearance: appearance, flagged: flag, note: note)
        store.data.healthObs.insert(o, at: 0)
        store.addEntry(CareEntry(date: Date(), kind: .note, groupId: groupId, zoneId: store.group(groupId)?.zoneId,
                                 detail: flag ? "Flagged for recheck" : "Health observation"))
        note = ""
    }
}

// MARK: - Screen 23: Cleaning Schedule

struct CleaningScheduleView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) private var scheme
    @State private var creating = false
    @State private var toastMessage: String?

    var body: some View {
        ScreenScaffold(icon: "sparkles", title: "Clean Plan",
                       subtitle: "Overdue cleanings surface on the dashboard") {
            Button { creating = true } label: {
                Label("Schedule Task", systemImage: "plus.circle.fill")
            }
            .buttonStyle(PrimaryButtonStyle(color: Palette.clay))

            if store.data.cleaningTasks.isEmpty {
                EmptyHint(symbol: "sparkles", title: "Nothing scheduled", message: "Plan bedding changes and sanitation cycles.")
            } else {
                ForEach(store.data.cleaningTasks.sorted { $0.scheduledDate < $1.scheduledDate }) { task in
                    cleaningCard(task)
                }
            }
        }
        .sheet(isPresented: $creating) {
            CleaningEditorView { toastMessage = "Cleaning scheduled" }.environmentObject(store)
        }
        .toast($toastMessage)
    }

    private func cleaningCard(_ task: CleaningTask) -> some View {
        let overdue = task.isOverdue(now: Date())
        return CoopCard(accent: task.done ? Palette.sage : (overdue ? Palette.danger : Palette.clay)) {
            HStack(spacing: 12) {
                Image(systemName: task.done ? "checkmark.seal.fill" : (overdue ? "exclamationmark.triangle.fill" : "calendar"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(task.done ? Palette.sage : (overdue ? Palette.danger : Palette.clay))
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title).font(.system(size: 15, weight: .bold))
                        .foregroundColor(Palette.primaryText(scheme))
                    Text("\(store.zoneName(task.zoneId)) · every \(task.cycleDays)d · \(AppStore.dateString(task.scheduledDate))")
                        .font(.system(size: 12)).foregroundColor(Palette.secondaryText(scheme))
                }
                Spacer()
                Button {
                    markClean(task)
                    toastMessage = "Marked clean"
                } label: {
                    Text("Mark Clean").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(Capsule().fill(Palette.sage))
                }
                Menu {
                    Button { store.data.cleaningTasks.removeAll { $0.id == task.id } } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis").foregroundColor(Palette.secondaryText(scheme)).padding(4)
                }
            }
        }
    }

    private func markClean(_ task: CleaningTask) {
        guard let idx = store.data.cleaningTasks.firstIndex(where: { $0.id == task.id }) else { return }
        let next = Calendar.current.date(byAdding: .day, value: task.cycleDays, to: Date()) ?? Date()
        store.data.cleaningTasks[idx].lastCleaned = Date()
        store.data.cleaningTasks[idx].scheduledDate = next
        store.data.cleaningTasks[idx].done = false
        store.addEntry(CareEntry(date: Date(), kind: .cleaning, groupId: nil, zoneId: task.zoneId, detail: task.title))
    }
}

struct CleaningEditorView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.colorScheme) private var scheme
    var onSave: () -> Void

    @State private var title = ""
    @State private var zoneId: UUID?
    @State private var date = Date()
    @State private var cycle = 7

    var body: some View {
        NavigationView {
            ZStack {
                BarnWoodBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(icon: "sparkles", title: "Schedule Cleaning")
                        ThemedField(title: "Task", placeholder: "e.g. Replace coop bedding", text: $title)
                        VStack(alignment: .leading, spacing: 6) {
                            FieldLabel(text: "Zone")
                            Menu {
                                Button("Unassigned") { zoneId = nil }
                                ForEach(store.data.zones) { z in Button(z.name) { zoneId = z.id } }
                            } label: {
                                HStack {
                                    Text(store.zoneName(zoneId)).foregroundColor(Palette.primaryText(scheme))
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down").foregroundColor(Palette.secondaryText(scheme))
                                }.fieldChrome()
                            }
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            FieldLabel(text: "Next date")
                            DatePicker("", selection: $date, displayedComponents: [.date])
                                .labelsHidden().datePickerStyle(CompactDatePickerStyle())
                        }
                        StepperRow(title: "Repeat every (days)", value: $cycle, range: 1...60).fieldChrome()
                        Button {
                            let t = CleaningTask(title: title.isEmpty ? "Cleaning" : title, zoneId: zoneId,
                                                 scheduledDate: date, cycleDays: cycle, lastCleaned: nil)
                            store.data.cleaningTasks.insert(t, at: 0)
                            onSave(); presentationMode.wrappedValue.dismiss()
                        } label: { Label("Save", systemImage: "checkmark.circle.fill") }
                        .buttonStyle(PrimaryButtonStyle(color: Palette.clay))
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity(title.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1)
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
            .onAppear { if zoneId == nil { zoneId = store.data.zones.first?.id } }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Screen 15: Quick Add

struct QuickAddView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.colorScheme) private var scheme

    @State private var kind: EntryKind = .feeding
    @State private var groupId: UUID?
    @State private var zoneId: UUID?
    @State private var detail = ""
    @State private var date = Date()
    @State private var toastMessage: String?

    var body: some View {
        ScreenScaffold(icon: "plus.circle.fill", title: "New Farm Entry",
                       subtitle: "Log feeding, water, cleaning, moves & notes") {
            CoopCard {
                VStack(alignment: .leading, spacing: 16) {
                    EnumChips(title: "Type", options: EntryKind.allCases, selection: $kind,
                              label: { $0.rawValue }, symbol: { $0.symbol })
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: "Group")
                        Menu {
                            Button("All birds") { groupId = nil }
                            ForEach(store.data.groups) { g in Button(g.name) { groupId = g.id } }
                        } label: {
                            HStack {
                                Text(store.groupName(groupId)).foregroundColor(Palette.primaryText(scheme))
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down").foregroundColor(Palette.secondaryText(scheme))
                            }.fieldChrome()
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: "Zone")
                        Menu {
                            Button("Unassigned") { zoneId = nil }
                            ForEach(store.data.zones) { z in Button(z.name) { zoneId = z.id } }
                        } label: {
                            HStack {
                                Text(store.zoneName(zoneId)).foregroundColor(Palette.primaryText(scheme))
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down").foregroundColor(Palette.secondaryText(scheme))
                            }.fieldChrome()
                        }
                    }
                    ThemedField(title: "Detail", placeholder: "Optional note", text: $detail)
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: "When")
                        DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden().datePickerStyle(CompactDatePickerStyle())
                    }
                }
            }

            HStack(spacing: 12) {
                Button {
                    commit()
                    presentationMode.wrappedValue.dismiss()
                } label: { Label("Save Entry", systemImage: "checkmark.circle.fill") }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    commit()
                    detail = ""
                    toastMessage = "Saved — add another"
                } label: { Label("Add Another", systemImage: "plus") }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .onAppear { if groupId == nil { groupId = store.data.groups.first?.id } }
        .toast($toastMessage)
    }

    private func commit() {
        let entry = CareEntry(date: date, kind: kind, groupId: groupId, zoneId: zoneId, detail: detail)
        store.addEntry(entry)
        if kind == .ret {
            // Returning an event also closes any matching open roam session.
            if let s = store.activeRoamSessions().first(where: { $0.groupId == groupId }) {
                store.markReturned(s, at: date)
            }
        }
    }
}

// MARK: - Care logs journal

struct CareLogsListView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScreenScaffold(icon: "tablecells.fill", title: "Care Journal",
                       subtitle: "\(store.data.entries.count) total entries") {
            if store.data.entries.isEmpty {
                EmptyHint(symbol: "tray", title: "No entries", message: "Your logged events appear here.")
            } else {
                ForEach(store.data.entries) { e in
                    CoopCard(accent: Palette.amber) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(Palette.amber.opacity(0.18)).frame(width: 38, height: 38)
                                Image(systemName: e.kind.symbol).foregroundColor(Palette.amberDeep)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.kind.rawValue).font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Palette.primaryText(scheme))
                                Text("\(store.groupName(e.groupId)) · \(store.zoneName(e.zoneId))")
                                    .font(.system(size: 12)).foregroundColor(Palette.secondaryText(scheme))
                                if !e.detail.isEmpty {
                                    Text(e.detail).font(.system(size: 12)).foregroundColor(Palette.secondaryText(scheme))
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(AppStore.dateString(e.date)).font(.system(size: 11))
                                    .foregroundColor(Palette.secondaryText(scheme))
                                Button { store.data.entries.removeAll { $0.id == e.id } } label: {
                                    Image(systemName: "trash").foregroundColor(Palette.danger)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
