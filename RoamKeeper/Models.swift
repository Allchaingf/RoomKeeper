//
//  Models.swift
//  RoamKeeper
//
//  Domain models for the offline free-range / coop keeping utility.
//  All types are Codable so the whole farm board can be persisted to disk.
//

import SwiftUI

// MARK: - Shared enums

enum BirdType: String, Codable, CaseIterable, Identifiable {
    case chickens = "Chickens"
    case ducks = "Ducks"
    case geese = "Geese"
    case turkeys = "Turkeys"
    case quail = "Quail"
    case guinea = "Guinea Fowl"
    case other = "Other"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .chickens: return "hare.fill"
        case .ducks: return "hare.fill"
        case .geese: return "hare.fill"
        case .turkeys: return "hare.fill"
        case .quail: return "hare.fill"
        case .guinea: return "hare.fill"
        case .other: return "hare.fill"
        }
    }
}

enum ColorTag: String, Codable, CaseIterable, Identifiable {
    case amber, clay, sage, sky, berry, slate

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .amber: return Color(hex: 0xE8A33D)
        case .clay:  return Color(hex: 0xC76B4A)
        case .sage:  return Color(hex: 0x7C9A6B)
        case .sky:   return Color(hex: 0x5C8FB0)
        case .berry: return Color(hex: 0x9C5B82)
        case .slate: return Color(hex: 0x6B7385)
        }
    }

    var label: String { rawValue.capitalized }
}

enum ZoneKind: String, Codable, CaseIterable, Identifiable {
    case coop = "Coop"
    case yard = "Yard"
    case run = "Run / Aviary"
    case quarantine = "Quarantine"
    case transport = "Transport Point"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .coop: return "house.fill"
        case .yard: return "leaf.fill"
        case .run: return "square.grid.3x3.fill"
        case .quarantine: return "cross.case.fill"
        case .transport: return "shippingbox.fill"
        }
    }
}

enum EntryKind: String, Codable, CaseIterable, Identifiable {
    case feeding = "Feeding"
    case water = "Water Check"
    case cleaning = "Cleaning"
    case move = "Move / Transfer"
    case release = "Release"
    case ret = "Return"
    case note = "Note"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .feeding: return "leaf.fill"
        case .water: return "drop.fill"
        case .cleaning: return "sparkles"
        case .move: return "arrow.left.arrow.right"
        case .release: return "sun.max.fill"
        case .ret: return "moon.fill"
        case .note: return "note.text"
        }
    }
}

enum Priority: String, Codable, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var id: String { rawValue }

    var rank: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        }
    }

    var color: Color {
        switch self {
        case .low: return Color(hex: 0x7C9A6B)
        case .medium: return Color(hex: 0xE8A33D)
        case .high: return Color(hex: 0xC75A4A)
        }
    }
}

/// Care priorities chosen during onboarding. Cards belonging to a chosen
/// priority are lifted higher on the dashboard.
enum CarePriority: String, Codable, CaseIterable, Identifiable {
    case health = "Health"
    case feed = "Feed"
    case cleaning = "Cleaning"
    case transport = "Transport"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .health: return "heart.text.square.fill"
        case .feed: return "leaf.fill"
        case .cleaning: return "sparkles"
        case .transport: return "shippingbox.fill"
        }
    }
}

enum VisualMode: String, Codable, CaseIterable, Identifiable {
    case coopMap = "Coop Map"
    case routeList = "Route List"
    case ledger = "Ledger View"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .coopMap: return "map.fill"
        case .routeList: return "list.bullet.rectangle"
        case .ledger: return "tablecells.fill"
        }
    }

    var blurb: String {
        switch self {
        case .coopMap: return "Zones laid out as cards you can scan at a glance."
        case .routeList: return "A top-to-bottom walking order for your daily round."
        case .ledger: return "A compact register of every entry and balance."
        }
    }
}

enum ThemeMode: String, Codable, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.fill"
        case .light: return "sun.max.fill"
        case .dark: return "moon.stars.fill"
        }
    }
}

enum UnitSystem: String, Codable, CaseIterable, Identifiable {
    case metric = "Metric"
    case imperial = "Imperial"

    var id: String { rawValue }

    var weightUnit: String { self == .metric ? "g" : "oz" }
    var bigWeightUnit: String { self == .metric ? "kg" : "lb" }
    var areaUnit: String { self == .metric ? "m²" : "ft²" }
    var lengthUnit: String { self == .metric ? "m" : "ft" }
    var tempUnit: String { self == .metric ? "°C" : "°F" }
}

enum InventoryCategory: String, Codable, CaseIterable, Identifiable {
    case feed = "Feed"
    case bedding = "Bedding"
    case supplement = "Supplement"
    case hardware = "Hardware"
    case waterer = "Waterer"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .feed: return "leaf.fill"
        case .bedding: return "square.stack.3d.up.fill"
        case .supplement: return "pills.fill"
        case .hardware: return "wrench.and.screwdriver.fill"
        case .waterer: return "drop.fill"
        }
    }
}

enum CostCategory: String, Codable, CaseIterable, Identifiable {
    case feed = "Feed"
    case bedding = "Bedding"
    case equipment = "Equipment"
    case health = "Health"
    case transport = "Transport"
    case other = "Other"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .feed: return "leaf.fill"
        case .bedding: return "square.stack.3d.up.fill"
        case .equipment: return "hammer.fill"
        case .health: return "cross.case.fill"
        case .transport: return "shippingbox.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

enum TaskCategory: String, Codable, CaseIterable, Identifiable {
    case repair = "Repair"
    case purchase = "Purchase"
    case cleaning = "Cleaning"
    case control = "Control"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .repair: return "hammer.fill"
        case .purchase: return "cart.fill"
        case .cleaning: return "sparkles"
        case .control: return "checkmark.shield.fill"
        }
    }
}

enum ReminderKind: String, Codable, CaseIterable, Identifiable {
    case morning = "Morning"
    case evening = "Evening"
    case transport = "Transport"
    case cleaning = "Cleaning"
    case custom = "Custom"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .evening: return "sunset.fill"
        case .transport: return "shippingbox.fill"
        case .cleaning: return "sparkles"
        case .custom: return "bell.fill"
        }
    }
}

enum RoamStatus: String, Codable {
    case out = "Out"
    case returned = "Returned"
    case overdue = "Overdue"
}

// MARK: - Core entities

struct BirdGroup: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var type: BirdType
    var count: Int
    var zoneId: UUID?
    var tag: ColorTag
    var notes: String = ""
}

struct Zone: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var kind: ZoneKind
    var order: Int
    var areaValue: Double = 0      // stored in metric (m²)
    var perchLength: Double = 0    // stored in metric (m)
    var note: String = ""
}

struct CareEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var kind: EntryKind
    var groupId: UUID?
    var zoneId: UUID?
    var detail: String = ""
}

/// The heart of Roam Keeper: a free-range session with release / expected
/// return / actual return times so nothing is left out after dusk.
struct RoamSession: Identifiable, Codable, Hashable {
    var id = UUID()
    var groupId: UUID?
    var zoneId: UUID?
    var releaseTime: Date
    var expectedReturn: Date
    var actualReturn: Date?
    var note: String = ""

    func status(now: Date) -> RoamStatus {
        if actualReturn != nil { return .returned }
        return now > expectedReturn ? .overdue : .out
    }
}

struct FarmTask: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var priority: Priority
    var category: TaskCategory
    var dueDate: Date?
    var zoneId: UUID?
    var done: Bool = false
}

struct Reminder: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var kind: ReminderKind
    var hour: Int
    var minute: Int
    var enabled: Bool = true
    var routeTarget: String = "" // human hint about which screen it leads to
}

struct FarmNote: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var body: String
    var tag: String = ""
    var zoneId: UUID?
    var groupId: UUID?
    var date: Date
    var photoFile: String?   // file name in Documents
    var markerX: Double?     // normalized 0..1 marker on photo
    var markerY: Double?
}

struct InventoryItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var category: InventoryCategory
    var quantity: Double
    var unit: String
    var minLevel: Double

    var isLow: Bool { quantity <= minLevel }
}

struct CostItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var amount: Double
    var category: CostCategory
    var date: Date
    var groupId: UUID?
}

struct FeedPortion: Identifiable, Codable, Hashable {
    var id = UUID()
    var groupId: UUID?
    var gramsPerBird: Double
    var birds: Int
    var days: Int
    var date: Date

    var totalGrams: Double { gramsPerBird * Double(birds) * Double(days) }
}

struct WaterLog: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var zoneId: UUID?
    var waterOk: Bool
    var tempC: Double          // stored metric
    var ventilationOk: Bool
    var watererClean: Bool
    var note: String = ""
}

struct HealthObservation: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var groupId: UUID?
    var activity: Int     // 1...5
    var appetite: Int     // 1...5
    var appearance: Int   // 1...5
    var flagged: Bool
    var note: String = ""
}

struct CleaningTask: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var zoneId: UUID?
    var scheduledDate: Date
    var cycleDays: Int
    var lastCleaned: Date?
    var done: Bool = false

    func isOverdue(now: Date) -> Bool {
        !done && scheduledDate < Calendar.current.startOfDay(for: now)
    }
}

struct RouteStop: Identifiable, Codable, Hashable {
    var id = UUID()
    var zoneId: UUID?
    var label: String
    var minutes: Int
    var order: Int
}

struct TransportCrate: Identifiable, Codable, Hashable {
    var id = UUID()
    var label: String
    var birdCount: Int
    var hasWater: Bool
    var loaded: Bool = false
}

struct CapacityResult: Identifiable, Codable, Hashable {
    var id = UUID()
    var zoneName: String
    var area: Double       // metric m²
    var perch: Double      // metric m
    var birds: Int
    var date: Date

    // Rule-of-thumb: 0.37 m² floor & 0.20 m perch per standard bird.
    var areaPerBird: Double { birds > 0 ? area / Double(birds) : 0 }
    var perchPerBird: Double { birds > 0 ? perch / Double(birds) : 0 }
    var isCrowded: Bool { areaPerBird < 0.37 || perchPerBird < 0.20 }
}

// MARK: - Checklist definition

struct CheckItem: Identifiable, Hashable {
    var id: String
    var title: String
    var symbol: String
}

enum CheckPeriod: String, CaseIterable, Identifiable {
    case morning = "Morning"
    case evening = "Evening"
    var id: String { rawValue }
    var symbol: String { self == .morning ? "sunrise.fill" : "sunset.fill" }
}

enum Checklist {
    static func items(for period: CheckPeriod) -> [CheckItem] {
        switch period {
        case .morning:
            return [
                CheckItem(id: "m_feed", title: "Morning feed served", symbol: "leaf.fill"),
                CheckItem(id: "m_water", title: "Fresh water topped up", symbol: "drop.fill"),
                CheckItem(id: "m_doors", title: "Coop doors opened", symbol: "lock.open.fill"),
                CheckItem(id: "m_release", title: "Flock released to range", symbol: "sun.max.fill"),
                CheckItem(id: "m_scan", title: "Quick health scan", symbol: "eye.fill")
            ]
        case .evening:
            return [
                CheckItem(id: "e_feed", title: "Evening feed served", symbol: "leaf.fill"),
                CheckItem(id: "e_water", title: "Waterers refreshed", symbol: "drop.fill"),
                CheckItem(id: "e_count", title: "All birds counted back", symbol: "list.bullet.rectangle"),
                CheckItem(id: "e_doors", title: "Coop doors closed", symbol: "lock.fill"),
                CheckItem(id: "e_bedding", title: "Bedding checked", symbol: "square.stack.3d.up.fill")
            ]
        }
    }
}

// MARK: - Aggregate persisted document

struct AppData: Codable {
    var groups: [BirdGroup] = []
    var zones: [Zone] = []
    var entries: [CareEntry] = []
    var roamSessions: [RoamSession] = []
    var tasks: [FarmTask] = []
    var reminders: [Reminder] = []
    var notes: [FarmNote] = []
    var inventory: [InventoryItem] = []
    var costs: [CostItem] = []
    var feedPortions: [FeedPortion] = []
    var waterLogs: [WaterLog] = []
    var healthObs: [HealthObservation] = []
    var cleaningTasks: [CleaningTask] = []
    var routeStops: [RouteStop] = []
    var crates: [TransportCrate] = []
    var capacityResults: [CapacityResult] = []
    var checklistState: [String: Bool] = [:]
}
