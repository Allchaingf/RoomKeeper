//
//  GroupsView.swift
//  RoamKeeper
//
//  Screen 16 — Bird Groups (Group Builder), Screen 17 — Coop Zones,
//  Screen 18 — Space & Perch Capacity.
//

import SwiftUI

// MARK: - Screen 16: Group Builder

struct GroupBuilderView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) private var scheme
    @State private var editing: BirdGroup?
    @State private var creating = false
    @State private var toastMessage: String?

    var body: some View {
        ScreenScaffold(icon: "hare.fill", title: "Bird Groups",
                       subtitle: "\(store.totalBirds) birds in \(store.data.groups.count) groups",
                       useBird: true) {

            HStack(spacing: 12) {
                NavigationLink(destination: ZonesView()) {
                    Label("Coop Zones", systemImage: "map.fill")
                }
                .buttonStyle(SecondaryButtonStyle())
                NavigationLink(destination: CapacityCalculatorView()) {
                    Label("Capacity", systemImage: "ruler.fill")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            Button { creating = true } label: {
                Label("Create Group", systemImage: "plus.circle.fill")
            }
            .buttonStyle(PrimaryButtonStyle())

            if store.data.groups.isEmpty {
                EmptyHint(symbol: "hare.fill", title: "No groups yet",
                          message: "Create your first flock to start tracking counts and zones.")
            } else {
                ForEach(store.data.groups) { group in
                    groupCard(group)
                }
            }
        }
        .sheet(isPresented: $creating) {
            GroupEditorView(group: nil) { toastMessage = "Group added" }
                .environmentObject(store)
        }
        .sheet(item: $editing) { g in
            GroupEditorView(group: g) { toastMessage = "Group saved" }
                .environmentObject(store)
        }
        .toast($toastMessage)
    }

    private func groupCard(_ group: BirdGroup) -> some View {
        CoopCard(accent: group.tag.color) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(group.tag.color.opacity(0.2)).frame(width: 40, height: 40)
                        BirdMark(size: 22, color: group.tag.color)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.name).font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(Palette.primaryText(scheme))
                        Text("\(group.type.rawValue) · \(store.zoneName(group.zoneId))")
                            .font(.system(size: 12)).foregroundColor(Palette.secondaryText(scheme))
                    }
                    Spacer()
                    Menu {
                        Button { editing = group } label: { Label("Edit", systemImage: "pencil") }
                        Menu("Move to zone") {
                            ForEach(store.data.zones) { z in
                                Button(z.name) { updateZone(group, z.id) }
                            }
                        }
                        Button { delete(group) } label: { Label("Delete", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis").font(.system(size: 18, weight: .bold))
                            .foregroundColor(Palette.secondaryText(scheme)).padding(6)
                    }
                }
                // Inline "Edit Count" stepper
                HStack {
                    Text("Count").font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Palette.secondaryText(scheme))
                    Spacer()
                    HStack(spacing: 14) {
                        Button { changeCount(group, -1) } label: { Image(systemName: "minus.circle.fill") }
                        Text("\(group.count)")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .frame(minWidth: 40)
                            .foregroundColor(Palette.primaryText(scheme))
                        Button { changeCount(group, 1) } label: { Image(systemName: "plus.circle.fill") }
                    }
                    .font(.system(size: 24)).foregroundColor(group.tag.color)
                }
            }
        }
    }

    private func changeCount(_ group: BirdGroup, _ delta: Int) {
        guard let idx = store.data.groups.firstIndex(where: { $0.id == group.id }) else { return }
        store.data.groups[idx].count = Swift.max(0, store.data.groups[idx].count + delta)
    }
    private func updateZone(_ group: BirdGroup, _ zoneId: UUID) {
        guard let idx = store.data.groups.firstIndex(where: { $0.id == group.id }) else { return }
        store.data.groups[idx].zoneId = zoneId
    }
    private func delete(_ group: BirdGroup) {
        store.data.groups.removeAll { $0.id == group.id }
    }
}

// MARK: - Group editor

struct GroupEditorView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.colorScheme) private var scheme

    let group: BirdGroup?
    var onSave: () -> Void

    @State private var name = ""
    @State private var type: BirdType = .chickens
    @State private var count = 12
    @State private var zoneId: UUID?
    @State private var tag: ColorTag = .amber
    @State private var notes = ""

    var body: some View {
        NavigationView {
            ZStack {
                BarnWoodBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(icon: "hare.fill", title: group == nil ? "New Group" : "Edit Group", useBird: true)

                        ThemedField(title: "Name", placeholder: "e.g. Brown Layers", text: $name)
                        EnumChips(title: "Bird type", options: BirdType.allCases, selection: $type,
                                  label: { $0.rawValue }, symbol: { $0.symbol })
                        StepperRow(title: "Count", value: $count, range: 0...500)
                            .fieldChrome()

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
                            FieldLabel(text: "Color marker")
                            HStack(spacing: 10) {
                                ForEach(ColorTag.allCases) { c in
                                    Circle().fill(c.color)
                                        .frame(width: 30, height: 30)
                                        .overlay(Circle().stroke(Color.white, lineWidth: tag == c ? 3 : 0))
                                        .overlay(Circle().stroke(Palette.cardStroke(scheme), lineWidth: 1))
                                        .scaleEffect(tag == c ? 1.15 : 1)
                                        .onTapGesture {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { tag = c }
                                        }
                                }
                            }
                        }

                        ThemedField(title: "Notes", placeholder: "Optional", text: $notes)

                        Button(action: save) {
                            Label("Save Group", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1)

                        if group != nil {
                            Button {
                                store.data.groups.removeAll { $0.id == group!.id }
                                presentationMode.wrappedValue.dismiss()
                            } label: {
                                Label("Delete Group", systemImage: "trash")
                                    .foregroundColor(Palette.danger)
                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                            }
                        }
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
            .onAppear(perform: load)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func load() {
        guard let g = group else { zoneId = store.data.zones.first?.id; return }
        name = g.name; type = g.type; count = g.count; zoneId = g.zoneId; tag = g.tag; notes = g.notes
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if let g = group, let idx = store.data.groups.firstIndex(where: { $0.id == g.id }) {
            store.data.groups[idx].name = trimmed
            store.data.groups[idx].type = type
            store.data.groups[idx].count = count
            store.data.groups[idx].zoneId = zoneId
            store.data.groups[idx].tag = tag
            store.data.groups[idx].notes = notes
        } else {
            store.data.groups.insert(BirdGroup(name: trimmed, type: type, count: count,
                                               zoneId: zoneId, tag: tag, notes: notes), at: 0)
        }
        onSave()
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Screen 17: Coop Zones

struct ZonesView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) private var scheme
    @State private var editing: Zone?
    @State private var creating = false
    @State private var toastMessage: String?

    var body: some View {
        ScreenScaffold(icon: "map.fill", title: "Farm Zones",
                       subtitle: "Coops, yards, runs, quarantine & transit") {
            Button { creating = true } label: {
                Label("Add Zone", systemImage: "plus.circle.fill")
            }
            .buttonStyle(PrimaryButtonStyle())

            if store.data.zones.isEmpty {
                EmptyHint(symbol: "map", title: "No zones", message: "Add coops and yards to map your farm.")
            } else {
                ForEach(Array(store.data.zones.sorted { $0.order < $1.order }.enumerated()), id: \.element.id) { idx, zone in
                    zoneCard(zone, index: idx, total: store.data.zones.count)
                }
            }
        }
        .sheet(isPresented: $creating) {
            ZoneEditorView(zone: nil) { toastMessage = "Zone added" }.environmentObject(store)
        }
        .sheet(item: $editing) { z in
            ZoneEditorView(zone: z) { toastMessage = "Zone saved" }.environmentObject(store)
        }
        .toast($toastMessage)
    }

    private func zoneCard(_ zone: Zone, index: Int, total: Int) -> some View {
        CoopCard {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Palette.amber.opacity(0.18)).frame(width: 42, height: 42)
                    Image(systemName: zone.kind.symbol).foregroundColor(Palette.amberDeep)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(zone.name).font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Palette.primaryText(scheme))
                    Text("\(zone.kind.rawValue) · \(store.data.groups.filter { $0.zoneId == zone.id }.count) groups")
                        .font(.system(size: 12)).foregroundColor(Palette.secondaryText(scheme))
                }
                Spacer()
                VStack(spacing: 6) {
                    Button { reorder(zone, up: true) } label: {
                        Image(systemName: "chevron.up.circle.fill")
                    }.disabled(index == 0).opacity(index == 0 ? 0.3 : 1)
                    Button { reorder(zone, up: false) } label: {
                        Image(systemName: "chevron.down.circle.fill")
                    }.disabled(index == total - 1).opacity(index == total - 1 ? 0.3 : 1)
                }
                .font(.system(size: 22)).foregroundColor(Palette.amberDeep)
                Menu {
                    Button { editing = zone } label: { Label("Edit", systemImage: "pencil") }
                    Button { store.data.zones.removeAll { $0.id == zone.id } } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 18, weight: .bold))
                        .foregroundColor(Palette.secondaryText(scheme)).padding(4)
                }
            }
        }
    }

    private func reorder(_ zone: Zone, up: Bool) {
        var sorted = store.data.zones.sorted { $0.order < $1.order }
        guard let i = sorted.firstIndex(where: { $0.id == zone.id }) else { return }
        let j = up ? i - 1 : i + 1
        guard j >= 0 && j < sorted.count else { return }
        sorted.swapAt(i, j)
        for (k, var z) in sorted.enumerated() { z.order = k
            if let idx = store.data.zones.firstIndex(where: { $0.id == z.id }) {
                store.data.zones[idx].order = k
            }
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { }
    }
}

// MARK: - Zone editor

struct ZoneEditorView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: AppSettings
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.colorScheme) private var scheme

    let zone: Zone?
    var onSave: () -> Void

    @State private var name = ""
    @State private var kind: ZoneKind = .coop
    @State private var areaText = ""
    @State private var perchText = ""
    @State private var note = ""

    var body: some View {
        NavigationView {
            ZStack {
                BarnWoodBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(icon: "map.fill", title: zone == nil ? "New Zone" : "Edit Zone")
                        ThemedField(title: "Name", placeholder: "e.g. North Coop", text: $name)
                        EnumChips(title: "Zone type", options: ZoneKind.allCases, selection: $kind,
                                  label: { $0.rawValue }, symbol: { $0.symbol })
                        ThemedField(title: "Floor area (\(settings.units.areaUnit))", placeholder: "0", text: $areaText, keyboard: .decimalPad)
                        ThemedField(title: "Perch length (\(settings.units.lengthUnit))", placeholder: "0", text: $perchText, keyboard: .decimalPad)
                        ThemedField(title: "Note", placeholder: "Optional", text: $note)
                        Button(action: save) {
                            Label("Save Zone", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1)
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
            .onAppear(perform: load)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func load() {
        guard let z = zone else { return }
        name = z.name; kind = z.kind; note = z.note
        areaText = z.areaValue > 0 ? store.trim(Measure.area(z.areaValue, settings.units)) : ""
        perchText = z.perchLength > 0 ? store.trim(Measure.length(z.perchLength, settings.units)) : ""
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let areaMetric = Measure.areaToMetric(Double(areaText) ?? 0, settings.units)
        let perchMetric = Measure.lengthToMetric(Double(perchText) ?? 0, settings.units)
        if let z = zone, let idx = store.data.zones.firstIndex(where: { $0.id == z.id }) {
            store.data.zones[idx].name = trimmed
            store.data.zones[idx].kind = kind
            store.data.zones[idx].areaValue = areaMetric
            store.data.zones[idx].perchLength = perchMetric
            store.data.zones[idx].note = note
        } else {
            let order = (store.data.zones.map { $0.order }.max() ?? -1) + 1
            store.data.zones.append(Zone(name: trimmed, kind: kind, order: order,
                                         areaValue: areaMetric, perchLength: perchMetric, note: note))
        }
        onSave()
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Screen 18: Capacity Calculator

struct CapacityCalculatorView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) private var scheme

    @State private var zoneName = ""
    @State private var areaText = ""
    @State private var perchText = ""
    @State private var birds = 12
    @State private var calculated = false
    @State private var toastMessage: String?

    private var areaMetric: Double { Measure.areaToMetric(Double(areaText) ?? 0, settings.units) }
    private var perchMetric: Double { Measure.lengthToMetric(Double(perchText) ?? 0, settings.units) }
    private var result: CapacityResult {
        CapacityResult(zoneName: zoneName.isEmpty ? "Zone" : zoneName,
                       area: areaMetric, perch: perchMetric, birds: birds, date: Date())
    }

    var body: some View {
        ScreenScaffold(icon: "ruler.fill", title: "Space & Perch Capacity",
                       subtitle: "Check a zone for crowding") {
            CoopCard {
                VStack(alignment: .leading, spacing: 14) {
                    ThemedField(title: "Zone label", placeholder: "e.g. North Coop", text: $zoneName)
                    ThemedField(title: "Floor area (\(settings.units.areaUnit))", placeholder: "0", text: $areaText, keyboard: .decimalPad)
                    ThemedField(title: "Perch length (\(settings.units.lengthUnit))", placeholder: "0", text: $perchText, keyboard: .decimalPad)
                    StepperRow(title: "Number of birds", value: $birds, range: 1...1000)
                }
            }

            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { calculated = true }
                } label: { Label("Calculate", systemImage: "function") }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    store.data.capacityResults.insert(result, at: 0)
                    toastMessage = "Result saved"
                } label: { Label("Save Result", systemImage: "tray.and.arrow.down.fill") }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(!calculated)
                .opacity(calculated ? 1 : 0.6)
            }

            if calculated {
                let r = result
                CoopCard(accent: r.isCrowded ? Palette.danger : Palette.sage) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: r.isCrowded ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                                .foregroundColor(r.isCrowded ? Palette.danger : Palette.sage)
                            Text(r.isCrowded ? "May be overcrowded" : "Within comfortable range")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(Palette.primaryText(scheme))
                        }
                        InfoRow(label: "Floor per bird",
                                value: "\(store.trim(Measure.area(r.areaPerBird, settings.units))) \(settings.units.areaUnit)",
                                color: r.areaPerBird < 0.37 ? Palette.danger : Palette.sage)
                        InfoRow(label: "Perch per bird",
                                value: "\(store.trim(Measure.length(r.perchPerBird, settings.units))) \(settings.units.lengthUnit)",
                                color: r.perchPerBird < 0.20 ? Palette.danger : Palette.sage)
                        Text("Guideline: ≥ \(store.trim(Measure.area(0.37, settings.units))) \(settings.units.areaUnit) floor and ≥ \(store.trim(Measure.length(0.20, settings.units))) \(settings.units.lengthUnit) perch per standard bird.")
                            .font(.system(size: 12)).foregroundColor(Palette.secondaryText(scheme))
                    }
                }
            }

            if !store.data.capacityResults.isEmpty {
                SectionHeader(icon: "clock.arrow.circlepath", title: "Saved results")
                ForEach(store.data.capacityResults) { r in
                    CoopCard(accent: r.isCrowded ? Palette.danger : Palette.sage) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.zoneName).font(.system(size: 15, weight: .bold))
                                    .foregroundColor(Palette.primaryText(scheme))
                                Text("\(r.birds) birds · \(store.trim(Measure.area(r.areaPerBird, settings.units))) \(settings.units.areaUnit)/bird")
                                    .font(.system(size: 12)).foregroundColor(Palette.secondaryText(scheme))
                            }
                            Spacer()
                            Button { store.data.capacityResults.removeAll { $0.id == r.id } } label: {
                                Image(systemName: "trash").foregroundColor(Palette.danger)
                            }
                        }
                    }
                }
            }
        }
        .toast($toastMessage)
    }
}
