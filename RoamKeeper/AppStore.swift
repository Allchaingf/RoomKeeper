//
//  AppStore.swift
//  RoamKeeper
//
//  Single source of truth (MVVM model/store layer): owns the persisted
//  AppData document, exposes derived analytics, schedules local
//  notifications, and seeds / resets sample data.
//

import SwiftUI
import Combine
import UserNotifications

// MARK: - App-wide settings (EnvironmentObject)

final class AppSettings: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var themeMode: ThemeMode {
        didSet { defaults.set(themeMode.rawValue, forKey: "themeMode") }
    }
    @Published var units: UnitSystem {
        didSet { defaults.set(units.rawValue, forKey: "units") }
    }
    @Published var accent: ColorTag {
        didSet { defaults.set(accent.rawValue, forKey: "accent") }
    }
    @Published var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }
    @Published var visualMode: VisualMode {
        didSet { defaults.set(visualMode.rawValue, forKey: "visualMode") }
    }
    @Published var priorities: Set<CarePriority> {
        didSet { defaults.set(priorities.map { $0.rawValue }, forKey: "priorities") }
    }
    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }
    @Published var colorLabelsEnabled: Bool {
        didSet { defaults.set(colorLabelsEnabled, forKey: "colorLabelsEnabled") }
    }

    init() {
        themeMode = ThemeMode(rawValue: defaults.string(forKey: "themeMode") ?? "") ?? .system
        units = UnitSystem(rawValue: defaults.string(forKey: "units") ?? "") ?? .metric
        accent = ColorTag(rawValue: defaults.string(forKey: "accent") ?? "") ?? .amber
        notificationsEnabled = defaults.object(forKey: "notificationsEnabled") as? Bool ?? false
        visualMode = VisualMode(rawValue: defaults.string(forKey: "visualMode") ?? "") ?? .coopMap
        let raw = defaults.array(forKey: "priorities") as? [String] ?? ["Health", "Feed"]
        priorities = Set(raw.compactMap { CarePriority(rawValue: $0) })
        hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")
        colorLabelsEnabled = defaults.object(forKey: "colorLabelsEnabled") as? Bool ?? true
    }

    var accentColor: Color { accent.color }
}

// MARK: - Derived value types

struct RiskFlag: Identifiable {
    enum Severity { case high, medium, low
        var color: Color {
            switch self {
            case .high: return Palette.danger
            case .medium: return Palette.amber
            case .low: return Palette.sage
            }
        }
    }
    var id = UUID()
    var title: String
    var detail: String
    var symbol: String
    var severity: Severity
    var key: String          // stable identity for resolve tracking
}

struct DashboardAction: Identifiable {
    var id = UUID()
    var title: String
    var detail: String
    var symbol: String
    var color: Color
    var priorityRank: Int     // higher = lifted up
}

// MARK: - Store

final class AppStore: ObservableObject {
    @Published var data: AppData {
        didSet { save() }
    }
    @Published var resolvedFlags: Set<String> = []

    private let fileName = "roamkeeper_data.json"

    init() {
        if let loaded = AppStore.loadFromDisk(Self.fileURLStatic("roamkeeper_data.json")) {
            data = loaded
        } else {
            data = AppStore.sampleData()
        }
    }

    // MARK: Persistence

    private func fileURL() -> URL { Self.fileURLStatic(fileName) }

    private static func fileURLStatic(_ name: String) -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent(name)
    }

    private static func loadFromDisk(_ url: URL) -> AppData? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AppData.self, from: data)
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        try? encoded.write(to: fileURL(), options: .atomic)
    }

    func resetToSample() {
        data = AppStore.sampleData()
        resolvedFlags = []
    }

    // MARK: Lookups

    func zone(_ id: UUID?) -> Zone? { data.zones.first { $0.id == id } }
    func group(_ id: UUID?) -> BirdGroup? { data.groups.first { $0.id == id } }

    func zoneName(_ id: UUID?) -> String { zone(id)?.name ?? "Unassigned" }
    func groupName(_ id: UUID?) -> String { group(id)?.name ?? "All birds" }

    var totalBirds: Int { data.groups.reduce(0) { $0 + $1.count } }

    // MARK: Roam sessions (release / return control — core feature)

    func activeRoamSessions(now: Date = Date()) -> [RoamSession] {
        data.roamSessions
            .filter { $0.actualReturn == nil }
            .sorted { $0.expectedReturn < $1.expectedReturn }
    }

    func overdueRoamSessions(now: Date = Date()) -> [RoamSession] {
        activeRoamSessions(now: now).filter { $0.status(now: now) == .overdue }
    }

    func markReturned(_ session: RoamSession, at date: Date = Date()) {
        guard let idx = data.roamSessions.firstIndex(where: { $0.id == session.id }) else { return }
        data.roamSessions[idx].actualReturn = date
        addEntry(CareEntry(date: date, kind: .ret,
                           groupId: session.groupId, zoneId: session.zoneId,
                           detail: "Flock counted back in"))
    }

    // MARK: Checklist

    func key(date: Date, period: CheckPeriod, item: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "\(f.string(from: date))|\(period.rawValue)|\(item)"
    }

    func isChecked(date: Date, period: CheckPeriod, item: String) -> Bool {
        data.checklistState[key(date: date, period: period, item: item)] ?? false
    }

    func setChecked(_ value: Bool, date: Date, period: CheckPeriod, item: String) {
        data.checklistState[key(date: date, period: period, item: item)] = value
    }

    /// Consistency = share of checklist items completed across the last 7 days.
    func consistency(now: Date = Date()) -> Double {
        let cal = Calendar.current
        var done = 0
        var total = 0
        for offset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: now) else { continue }
            for period in CheckPeriod.allCases {
                for item in Checklist.items(for: period) {
                    total += 1
                    if isChecked(date: day, period: period, item: item.id) { done += 1 }
                }
            }
        }
        return total == 0 ? 0 : Double(done) / Double(total)
    }

    func todayChecklistProgress(now: Date = Date()) -> (done: Int, total: Int) {
        var done = 0, total = 0
        for period in CheckPeriod.allCases {
            for item in Checklist.items(for: period) {
                total += 1
                if isChecked(date: now, period: period, item: item.id) { done += 1 }
            }
        }
        return (done, total)
    }

    // MARK: Entries / quick add

    func addEntry(_ entry: CareEntry) {
        data.entries.insert(entry, at: 0)
    }

    func entries(on day: Date) -> [CareEntry] {
        let cal = Calendar.current
        return data.entries.filter { cal.isDate($0.date, inSameDayAs: day) }
    }

    /// Entry counts for the last 7 days (oldest -> newest) for trend charts.
    func weeklyEntryCounts(now: Date = Date()) -> [BarPoint] {
        let cal = Calendar.current
        var points: [BarPoint] = []
        let fmt = DateFormatter(); fmt.dateFormat = "EEEEE"
        for offset in stride(from: 6, through: 0, by: -1) {
            guard let day = cal.date(byAdding: .day, value: -offset, to: now) else { continue }
            let count = data.entries.filter { cal.isDate($0.date, inSameDayAs: day) }.count
            points.append(BarPoint(label: fmt.string(from: day), value: Double(count)))
        }
        return points
    }

    func consistencySeries(now: Date = Date()) -> [Double] {
        let cal = Calendar.current
        var series: [Double] = []
        for offset in stride(from: 6, through: 0, by: -1) {
            guard let day = cal.date(byAdding: .day, value: -offset, to: now) else { continue }
            var done = 0, total = 0
            for period in CheckPeriod.allCases {
                for item in Checklist.items(for: period) {
                    total += 1
                    if isChecked(date: day, period: period, item: item.id) { done += 1 }
                }
            }
            series.append(total == 0 ? 0 : Double(done) / Double(total) * 100)
        }
        return series
    }

    // MARK: Costs

    func costsThisMonth(now: Date = Date()) -> Double {
        let cal = Calendar.current
        return data.costs.filter {
            cal.isDate($0.date, equalTo: now, toGranularity: .month)
        }.reduce(0) { $0 + $1.amount }
    }

    func costByCategory(now: Date = Date()) -> [(CostCategory, Double)] {
        var dict: [CostCategory: Double] = [:]
        let cal = Calendar.current
        for c in data.costs where cal.isDate(c.date, equalTo: now, toGranularity: .month) {
            dict[c.category, default: 0] += c.amount
        }
        return CostCategory.allCases.compactMap { cat in
            dict[cat].map { (cat, $0) }
        }
    }

    func weeklyCostSeries(now: Date = Date()) -> [BarPoint] {
        let cal = Calendar.current
        var points: [BarPoint] = []
        for w in stride(from: 3, through: 0, by: -1) {
            guard let weekStart = cal.date(byAdding: .day, value: -7 * w, to: now) else { continue }
            guard let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart) else { continue }
            let total = data.costs.filter { $0.date >= cal.date(byAdding: .day, value: -7, to: weekStart)! && $0.date < weekEnd }.reduce(0) { $0 + $1.amount }
            points.append(BarPoint(label: "W\(4 - w)", value: total))
        }
        return points
    }

    // MARK: Inventory

    var lowStockItems: [InventoryItem] { data.inventory.filter { $0.isLow } }

    // MARK: Tasks

    func overdueTasks(now: Date = Date()) -> [FarmTask] {
        data.tasks.filter { t in
            guard !t.done, let due = t.dueDate else { return false }
            return due < Calendar.current.startOfDay(for: now)
        }
    }
    var openTasks: [FarmTask] { data.tasks.filter { !$0.done } }

    // MARK: Cleaning

    func overdueCleaning(now: Date = Date()) -> [CleaningTask] {
        data.cleaningTasks.filter { $0.isOverdue(now: now) }
    }

    // MARK: Risk flags

    func riskFlags(now: Date = Date()) -> [RiskFlag] {
        var flags: [RiskFlag] = []

        for s in overdueRoamSessions(now: now) {
            flags.append(RiskFlag(
                title: "Flock still out",
                detail: "\(groupName(s.groupId)) was due back by \(Self.timeString(s.expectedReturn))",
                symbol: "moon.fill",
                severity: .high,
                key: "roam-\(s.id.uuidString)"))
        }
        for t in overdueTasks(now: now) {
            flags.append(RiskFlag(
                title: "Overdue task",
                detail: t.title,
                symbol: t.category.symbol,
                severity: .high,
                key: "task-\(t.id.uuidString)"))
        }
        for item in lowStockItems {
            flags.append(RiskFlag(
                title: "Low stock",
                detail: "\(item.name) at \(trim(item.quantity)) \(item.unit) (min \(trim(item.minLevel)))",
                symbol: item.category.symbol,
                severity: .medium,
                key: "stock-\(item.id.uuidString)"))
        }
        for c in overdueCleaning(now: now) {
            flags.append(RiskFlag(
                title: "Cleaning overdue",
                detail: "\(c.title) — \(zoneName(c.zoneId))",
                symbol: "sparkles",
                severity: .medium,
                key: "clean-\(c.id.uuidString)"))
        }
        for h in data.healthObs.filter({ $0.flagged }) {
            flags.append(RiskFlag(
                title: "Health flag",
                detail: "\(groupName(h.groupId)) — needs a recheck",
                symbol: "heart.text.square.fill",
                severity: .high,
                key: "health-\(h.id.uuidString)"))
        }
        for r in data.capacityResults.filter({ $0.isCrowded }) {
            flags.append(RiskFlag(
                title: "Zone may be crowded",
                detail: "\(r.zoneName) — \(trim(r.areaPerBird)) m²/bird",
                symbol: "exclamationmark.triangle.fill",
                severity: .medium,
                key: "cap-\(r.id.uuidString)"))
        }

        return flags.filter { !resolvedFlags.contains($0.key) }
            .sorted { sevRank($0.severity) > sevRank($1.severity) }
    }

    private func sevRank(_ s: RiskFlag.Severity) -> Int {
        switch s { case .high: return 2; case .medium: return 1; case .low: return 0 }
    }

    func resolveFlag(_ flag: RiskFlag) {
        resolvedFlags.insert(flag.key)
    }

    // MARK: Dashboard actions ordering by priorities

    func dashboardActions(priorities: Set<CarePriority>, now: Date = Date()) -> [DashboardAction] {
        var actions: [DashboardAction] = []

        let progress = todayChecklistProgress(now: now)
        if progress.done < progress.total {
            actions.append(DashboardAction(
                title: "Finish daily checks",
                detail: "\(progress.done)/\(progress.total) checklist items done",
                symbol: "list.bullet.rectangle",
                color: Palette.amber,
                priorityRank: priorities.contains(.cleaning) ? 5 : 3))
        }
        let out = activeRoamSessions(now: now)
        if !out.isEmpty {
            let overdue = out.filter { $0.status(now: now) == .overdue }.count
            actions.append(DashboardAction(
                title: overdue > 0 ? "Bring the flock back" : "Birds are out on range",
                detail: overdue > 0 ? "\(overdue) group(s) overdue to return" : "\(out.count) group(s) roaming — watch return time",
                symbol: overdue > 0 ? "moon.fill" : "sun.max.fill",
                color: overdue > 0 ? Palette.danger : Palette.sky,
                priorityRank: 6))
        }
        if !lowStockItems.isEmpty {
            actions.append(DashboardAction(
                title: "Restock supplies",
                detail: "\(lowStockItems.count) item(s) below minimum",
                symbol: "shippingbox.fill",
                color: Palette.clay,
                priorityRank: priorities.contains(.feed) ? 5 : 2))
        }
        let oc = overdueCleaning(now: now)
        if !oc.isEmpty {
            actions.append(DashboardAction(
                title: "Cleaning is due",
                detail: "\(oc.count) cleaning task(s) overdue",
                symbol: "sparkles",
                color: Palette.sage,
                priorityRank: priorities.contains(.cleaning) ? 5 : 2))
        }
        if !data.healthObs.filter({ $0.flagged }).isEmpty {
            actions.append(DashboardAction(
                title: "Recheck flagged birds",
                detail: "Health observations need a second look",
                symbol: "heart.text.square.fill",
                color: Palette.berry,
                priorityRank: priorities.contains(.health) ? 6 : 3))
        }
        let crates = data.crates.filter { !$0.loaded }
        if !crates.isEmpty && priorities.contains(.transport) {
            actions.append(DashboardAction(
                title: "Finish transport load",
                detail: "\(crates.count) crate(s) not confirmed",
                symbol: "shippingbox.fill",
                color: Palette.amberDeep,
                priorityRank: 5))
        }
        return actions.sorted { $0.priorityRank > $1.priorityRank }
    }

    // MARK: Notifications

    func requestNotificationAuth(_ completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion?(granted) }
        }
    }

    func syncNotifications(enabled: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard enabled else { return }
        for r in data.reminders where r.enabled {
            var comps = DateComponents()
            comps.hour = r.hour
            comps.minute = r.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let content = UNMutableNotificationContent()
            content.title = "Roam Keeper — \(r.kind.rawValue)"
            content.body = r.title
            content.sound = .default
            let req = UNNotificationRequest(identifier: r.id.uuidString, content: content, trigger: trigger)
            center.add(req)
        }
    }

    // MARK: Formatting helpers

    func trim(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }

    static func timeString(_ date: Date) -> String {
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none
        return f.string(from: date)
    }

    static func dateString(_ date: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none
        return f.string(from: date)
    }

    static func dayTimeString(_ date: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .short
        return f.string(from: date)
    }

    func currency(_ amount: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = amount == amount.rounded() ? 0 : 2
        return f.string(from: NSNumber(value: amount)) ?? "$\(trim(amount))"
    }
}

// MARK: - Measurement conversion (display layer)

enum Measure {
    static func area(_ metric: Double, _ units: UnitSystem) -> Double {
        units == .metric ? metric : metric * 10.7639
    }
    static func areaToMetric(_ value: Double, _ units: UnitSystem) -> Double {
        units == .metric ? value : value / 10.7639
    }
    static func length(_ metric: Double, _ units: UnitSystem) -> Double {
        units == .metric ? metric : metric * 3.28084
    }
    static func lengthToMetric(_ value: Double, _ units: UnitSystem) -> Double {
        units == .metric ? value : value / 3.28084
    }
    static func temp(_ c: Double, _ units: UnitSystem) -> Double {
        units == .metric ? c : c * 9/5 + 32
    }
    static func tempToMetric(_ value: Double, _ units: UnitSystem) -> Double {
        units == .metric ? value : (value - 32) * 5/9
    }
    static func weight(_ grams: Double, _ units: UnitSystem) -> String {
        if units == .metric {
            return grams >= 1000 ? String(format: "%.2f kg", grams / 1000) : "\(Int(grams)) g"
        } else {
            let oz = grams * 0.035274
            return oz >= 16 ? String(format: "%.2f lb", oz / 16) : String(format: "%.1f oz", oz)
        }
    }
}

// MARK: - Photo storage

enum PhotoStore {
    private static func dir() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    static func save(_ image: UIImage) -> String? {
        let name = "photo_\(UUID().uuidString).jpg"
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        try? data.write(to: dir().appendingPathComponent(name), options: .atomic)
        return name
    }
    static func load(_ name: String?) -> UIImage? {
        guard let name = name else { return nil }
        return UIImage(contentsOfFile: dir().appendingPathComponent(name).path)
    }
    static func delete(_ name: String?) {
        guard let name = name else { return }
        try? FileManager.default.removeItem(at: dir().appendingPathComponent(name))
    }
}

// MARK: - Sample data

extension AppStore {
    static func sampleData() -> AppData {
        var d = AppData()
        let now = Date()
        let cal = Calendar.current

        // Zones
        let coop = Zone(name: "North Coop", kind: .coop, order: 0, areaValue: 9, perchLength: 4, note: "Main layer house")
        let yard = Zone(name: "Home Yard", kind: .yard, order: 1, areaValue: 60, perchLength: 0, note: "Daytime free range")
        let run = Zone(name: "Garden Run", kind: .run, order: 2, areaValue: 18, perchLength: 2)
        let quarantine = Zone(name: "Quarantine Pen", kind: .quarantine, order: 3, areaValue: 4, perchLength: 1)
        d.zones = [coop, yard, run, quarantine]

        // Groups
        let layers = BirdGroup(name: "Brown Layers", type: .chickens, count: 14, zoneId: coop.id, tag: .amber, notes: "Daily eggs")
        let ducks = BirdGroup(name: "Pekin Ducks", type: .ducks, count: 6, zoneId: run.id, tag: .sky)
        let pullets = BirdGroup(name: "Spring Pullets", type: .chickens, count: 9, zoneId: yard.id, tag: .sage)
        d.groups = [layers, ducks, pullets]

        // Roam session: layers are out and due back at dusk.
        let release = cal.date(byAdding: .hour, value: -3, to: now) ?? now
        let dueBack = cal.date(byAdding: .hour, value: 1, to: now) ?? now
        d.roamSessions = [
            RoamSession(groupId: layers.id, zoneId: yard.id,
                        releaseTime: release, expectedReturn: dueBack, actualReturn: nil,
                        note: "Free ranging in the home yard"),
            RoamSession(groupId: pullets.id, zoneId: yard.id,
                        releaseTime: cal.date(byAdding: .day, value: -1, to: now)!,
                        expectedReturn: cal.date(byAdding: .day, value: -1, to: now)!,
                        actualReturn: cal.date(byAdding: .day, value: -1, to: now)!,
                        note: "Returned on time")
        ]

        // Entries
        d.entries = [
            CareEntry(date: cal.date(byAdding: .hour, value: -3, to: now)!, kind: .release, groupId: layers.id, zoneId: yard.id, detail: "Opened the range gate"),
            CareEntry(date: cal.date(byAdding: .hour, value: -4, to: now)!, kind: .feeding, groupId: layers.id, zoneId: coop.id, detail: "Layer pellets, 1.4 kg"),
            CareEntry(date: cal.date(byAdding: .hour, value: -5, to: now)!, kind: .water, groupId: ducks.id, zoneId: run.id, detail: "Refilled pool & drinkers"),
            CareEntry(date: cal.date(byAdding: .day, value: -1, to: now)!, kind: .cleaning, groupId: nil, zoneId: coop.id, detail: "Raked bedding")
        ]

        // Inventory (one low item)
        d.inventory = [
            InventoryItem(name: "Layer Pellets", category: .feed, quantity: 8, unit: "kg", minLevel: 10),
            InventoryItem(name: "Pine Shavings", category: .bedding, quantity: 4, unit: "bales", minLevel: 2),
            InventoryItem(name: "Oyster Shell", category: .supplement, quantity: 3, unit: "kg", minLevel: 1),
            InventoryItem(name: "Hinges", category: .hardware, quantity: 6, unit: "pcs", minLevel: 2),
            InventoryItem(name: "Nipple Drinkers", category: .waterer, quantity: 12, unit: "pcs", minLevel: 4)
        ]

        // Costs
        d.costs = [
            CostItem(title: "Feed delivery", amount: 64, category: .feed, date: cal.date(byAdding: .day, value: -2, to: now)!, groupId: layers.id),
            CostItem(title: "Bedding", amount: 22, category: .bedding, date: cal.date(byAdding: .day, value: -6, to: now)!),
            CostItem(title: "New waterer", amount: 18, category: .equipment, date: cal.date(byAdding: .day, value: -10, to: now)!),
            CostItem(title: "Vitamins", amount: 12, category: .health, date: cal.date(byAdding: .day, value: -1, to: now)!, groupId: ducks.id)
        ]

        // Tasks
        d.tasks = [
            FarmTask(title: "Fix run gate latch", priority: .high, category: .repair, dueDate: cal.date(byAdding: .day, value: -1, to: now), zoneId: run.id),
            FarmTask(title: "Order layer feed", priority: .high, category: .purchase, dueDate: cal.date(byAdding: .day, value: 1, to: now)),
            FarmTask(title: "Deep clean coop", priority: .medium, category: .cleaning, dueDate: cal.date(byAdding: .day, value: 3, to: now), zoneId: coop.id),
            FarmTask(title: "Count returning flock", priority: .medium, category: .control, dueDate: now, zoneId: yard.id)
        ]

        // Reminders
        d.reminders = [
            Reminder(title: "Open coop & feed", kind: .morning, hour: 7, minute: 0, enabled: true, routeTarget: "Daily Care Checklist"),
            Reminder(title: "Count birds back & lock up", kind: .evening, hour: 19, minute: 30, enabled: true, routeTarget: "Daily Care Checklist"),
            Reminder(title: "Weekly deep clean", kind: .cleaning, hour: 10, minute: 0, enabled: false, routeTarget: "Cleaning Schedule")
        ]

        // Notes
        d.notes = [
            FarmNote(title: "Loose board in coop", body: "South wall board is loose near the nest boxes — watch for drafts.", tag: "repair", zoneId: coop.id, groupId: layers.id, date: cal.date(byAdding: .day, value: -1, to: now)!)
        ]

        // Cleaning
        d.cleaningTasks = [
            CleaningTask(title: "Replace coop bedding", zoneId: coop.id, scheduledDate: cal.date(byAdding: .day, value: -1, to: now)!, cycleDays: 7, lastCleaned: cal.date(byAdding: .day, value: -8, to: now)),
            CleaningTask(title: "Scrub waterers", zoneId: run.id, scheduledDate: cal.date(byAdding: .day, value: 2, to: now)!, cycleDays: 3, lastCleaned: cal.date(byAdding: .day, value: -1, to: now))
        ]

        // Water logs
        d.waterLogs = [
            WaterLog(date: cal.date(byAdding: .hour, value: -5, to: now)!, zoneId: run.id, waterOk: true, tempC: 21, ventilationOk: true, watererClean: true, note: "All good")
        ]

        // Health
        d.healthObs = [
            HealthObservation(date: cal.date(byAdding: .day, value: -1, to: now)!, groupId: ducks.id, activity: 4, appetite: 5, appearance: 4, flagged: false, note: "Bright and active")
        ]

        // Route
        d.routeStops = [
            RouteStop(zoneId: coop.id, label: "North Coop", minutes: 8, order: 0),
            RouteStop(zoneId: run.id, label: "Garden Run", minutes: 6, order: 1),
            RouteStop(zoneId: yard.id, label: "Home Yard", minutes: 10, order: 2)
        ]

        // Crates
        d.crates = [
            TransportCrate(label: "Crate A", birdCount: 4, hasWater: true, loaded: false)
        ]

        // Feed portions
        d.feedPortions = [
            FeedPortion(groupId: layers.id, gramsPerBird: 120, birds: 14, days: 7, date: now)
        ]

        // Capacity
        d.capacityResults = [
            CapacityResult(zoneName: "North Coop", area: 9, perch: 4, birds: 14, date: now)
        ]

        // Pre-tick a couple of this-morning's checklist items so consistency is non-zero.
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let today = f.string(from: now)
        d.checklistState["\(today)|Morning|m_feed"] = true
        d.checklistState["\(today)|Morning|m_water"] = true
        d.checklistState["\(today)|Morning|m_doors"] = true
        d.checklistState["\(today)|Morning|m_release"] = true
        if let y = cal.date(byAdding: .day, value: -1, to: now) {
            let yest = f.string(from: y)
            for period in CheckPeriod.allCases {
                for item in Checklist.items(for: period) {
                    d.checklistState["\(yest)|\(period.rawValue)|\(item.id)"] = true
                }
            }
        }

        return d
    }
}
