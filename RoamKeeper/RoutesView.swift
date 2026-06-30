//
//  RoutesView.swift
//  RoamKeeper
//
//  Screen 2 — Care Route (Route Planner) and Screen 3 — Transit Checklist
//  (Transport Prep).
//

import SwiftUI

// MARK: - Screen 2: Route Planner

struct RoutePlannerView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) private var scheme

    @State private var rounding = false
    @State private var visited: Set<UUID> = []
    @State private var adding = false
    @State private var toastMessage: String?

    private var stops: [RouteStop] { store.data.routeStops.sorted { $0.order < $1.order } }
    private var totalMinutes: Int { store.data.routeStops.reduce(0) { $0 + $1.minutes } }

    var body: some View {
        ScreenScaffold(icon: "map.fill", title: "Care Route",
                       subtitle: "Order your round & estimate the time") {

            HStack(spacing: 12) {
                StatTile(value: "\(stops.count)", label: "Checkpoints", symbol: "mappin.and.ellipse", color: Palette.amber)
                StatTile(value: "~\(totalMinutes)m", label: "Estimated round", symbol: "clock.fill", color: Palette.sky)
            }

            HStack(spacing: 12) {
                Button {
                    buildRoute()
                    toastMessage = "Route built"
                } label: { Label("Build Route", systemImage: "wand.and.stars") }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        rounding.toggle()
                        if rounding { visited = [] }
                    }
                } label: { Label(rounding ? "End Round" : "Start Round",
                                 systemImage: rounding ? "stop.circle.fill" : "play.circle.fill") }
                .buttonStyle(SecondaryButtonStyle(color: rounding ? Palette.danger : Palette.amberDeep))
            }

            if rounding {
                CoopCard(accent: Palette.sage) {
                    HStack {
                        Text("Round progress").font(.system(size: 14, weight: .bold))
                            .foregroundColor(Palette.primaryText(scheme))
                        Spacer()
                        Text("\(visited.count)/\(stops.count)")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundColor(Palette.sage)
                    }
                }
            }

            Button { adding = true } label: {
                Label("Add Checkpoint", systemImage: "plus.circle.fill")
            }
            .buttonStyle(SecondaryButtonStyle())

            if stops.isEmpty {
                EmptyHint(symbol: "map", title: "No route yet", message: "Tap Build Route to lay one out from your zones.")
            } else {
                ForEach(Array(stops.enumerated()), id: \.element.id) { idx, stop in
                    stopCard(stop, index: idx)
                }
            }

            NavigationLink(destination: TransportPrepView()) {
                Label("Transport Prep", systemImage: "shippingbox.fill")
            }
            .buttonStyle(SecondaryButtonStyle(color: Palette.clay))
        }
        .sheet(isPresented: $adding) {
            RouteStopEditor { zoneId, label, minutes in
                let order = (store.data.routeStops.map { $0.order }.max() ?? -1) + 1
                store.data.routeStops.append(RouteStop(zoneId: zoneId, label: label, minutes: minutes, order: order))
                toastMessage = "Checkpoint added"
            }.environmentObject(store)
        }
        .toast($toastMessage)
    }

    private func stopCard(_ stop: RouteStop, index: Int) -> some View {
        let isVisited = visited.contains(stop.id)
        return CoopCard(accent: isVisited ? Palette.sage : Palette.amber) {
            HStack(spacing: 12) {
                if rounding {
                    Button {
                        withAnimation { if isVisited { visited.remove(stop.id) } else { visited.insert(stop.id) } }
                    } label: {
                        Image(systemName: isVisited ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 24)).foregroundColor(isVisited ? Palette.sage : Palette.secondaryText(scheme))
                    }
                } else {
                    ZStack {
                        Circle().fill(Palette.amber).frame(width: 30, height: 30)
                        Text("\(index + 1)").font(.system(size: 14, weight: .heavy)).foregroundColor(.white)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(stop.label).font(.system(size: 15, weight: .bold))
                        .foregroundColor(Palette.primaryText(scheme))
                        .strikethrough(isVisited, color: Palette.secondaryText(scheme))
                    Text("~\(stop.minutes) min").font(.system(size: 12))
                        .foregroundColor(Palette.secondaryText(scheme))
                }
                Spacer()
                if !rounding {
                    VStack(spacing: 4) {
                        Button { reorder(stop, up: true) } label: { Image(systemName: "chevron.up.circle.fill") }
                            .disabled(index == 0).opacity(index == 0 ? 0.3 : 1)
                        Button { reorder(stop, up: false) } label: { Image(systemName: "chevron.down.circle.fill") }
                            .disabled(index == stops.count - 1).opacity(index == stops.count - 1 ? 0.3 : 1)
                    }
                    .font(.system(size: 20)).foregroundColor(Palette.amberDeep)
                    Button { store.data.routeStops.removeAll { $0.id == stop.id } } label: {
                        Image(systemName: "trash").foregroundColor(Palette.danger)
                    }
                }
            }
        }
    }

    private func buildRoute() {
        let zones = store.data.zones.sorted { $0.order < $1.order }
        store.data.routeStops = zones.enumerated().map { idx, z in
            RouteStop(zoneId: z.id, label: z.name, minutes: defaultMinutes(z.kind), order: idx)
        }
    }

    private func defaultMinutes(_ kind: ZoneKind) -> Int {
        switch kind {
        case .coop: return 8
        case .yard: return 10
        case .run: return 6
        case .quarantine: return 5
        case .transport: return 4
        }
    }

    private func reorder(_ stop: RouteStop, up: Bool) {
        var sorted = stops
        guard let i = sorted.firstIndex(where: { $0.id == stop.id }) else { return }
        let j = up ? i - 1 : i + 1
        guard j >= 0 && j < sorted.count else { return }
        sorted.swapAt(i, j)
        for (k, s) in sorted.enumerated() {
            if let idx = store.data.routeStops.firstIndex(where: { $0.id == s.id }) {
                store.data.routeStops[idx].order = k
            }
        }
    }
}

struct RouteStopEditor: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.colorScheme) private var scheme
    var onSave: (UUID?, String, Int) -> Void

    @State private var zoneId: UUID?
    @State private var label = ""
    @State private var minutes = 8

    var body: some View {
        NavigationView {
            ZStack {
                BarnWoodBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(icon: "mappin.and.ellipse", title: "Add Checkpoint")
                        VStack(alignment: .leading, spacing: 6) {
                            FieldLabel(text: "Zone")
                            Menu {
                                ForEach(store.data.zones) { z in
                                    Button(z.name) { zoneId = z.id; label = z.name }
                                }
                            } label: {
                                HStack {
                                    Text(zoneId == nil ? "Select zone" : store.zoneName(zoneId))
                                        .foregroundColor(Palette.primaryText(scheme))
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down").foregroundColor(Palette.secondaryText(scheme))
                                }.fieldChrome()
                            }
                        }
                        ThemedField(title: "Label", placeholder: "Checkpoint name", text: $label)
                        StepperRow(title: "Minutes", value: $minutes, range: 1...90).fieldChrome()
                        Button {
                            onSave(zoneId, label.isEmpty ? "Checkpoint" : label, minutes)
                            presentationMode.wrappedValue.dismiss()
                        } label: { Label("Add", systemImage: "checkmark.circle.fill") }
                        .buttonStyle(PrimaryButtonStyle())
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
            .onAppear { if zoneId == nil, let z = store.data.zones.first { zoneId = z.id; label = z.name } }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Screen 3: Transport Prep

struct TransportPrepView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) private var scheme

    @State private var departure = Date().addingTimeInterval(3600)
    @State private var stopsText = "1"
    @State private var adding = false
    @State private var toastMessage: String?

    private var totalBirds: Int { store.data.crates.reduce(0) { $0 + $1.birdCount } }
    private var allLoaded: Bool { !store.data.crates.isEmpty && store.data.crates.allSatisfy { $0.loaded } }
    private var waterOnboard: Bool { store.data.crates.contains { $0.hasWater } }

    var body: some View {
        ScreenScaffold(icon: "shippingbox.fill", title: "Transit Checklist",
                       subtitle: "Crates, water & departure — nothing forgotten") {

            CoopCard(accent: Palette.clay) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: "Departure time")
                        DatePicker("", selection: $departure, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden().datePickerStyle(CompactDatePickerStyle())
                    }
                    ThemedField(title: "Planned stops", placeholder: "1", text: $stopsText, keyboard: .numberPad)
                    Divider().background(Palette.cardStroke(scheme))
                    InfoRow(label: "Crates", value: "\(store.data.crates.count)")
                    InfoRow(label: "Birds aboard", value: "\(totalBirds)", color: Palette.clay)
                }
            }

            // Pre-flight readiness
            CoopCard(accent: allLoaded ? Palette.sage : Palette.amber) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Pre-flight", systemImage: "checkmark.shield.fill")
                        .font(.system(size: 15, weight: .bold)).foregroundColor(Palette.primaryText(scheme))
                    readyRow("At least one crate", store.data.crates.count > 0)
                    readyRow("Water onboard", waterOnboard)
                    readyRow("Departure set", departure > Date())
                    readyRow("All crates loaded", allLoaded)
                }
            }

            HStack(spacing: 12) {
                Button { adding = true } label: { Label("Add Crate", systemImage: "plus.circle.fill") }
                    .buttonStyle(PrimaryButtonStyle(color: Palette.clay))
                Button {
                    for i in store.data.crates.indices { store.data.crates[i].loaded = true }
                    store.addEntry(CareEntry(date: Date(), kind: .move, groupId: nil, zoneId: nil,
                                             detail: "Transport load confirmed (\(totalBirds) birds)"))
                    toastMessage = "Load confirmed"
                } label: { Label("Confirm Load", systemImage: "checkmark.seal.fill") }
                .buttonStyle(SecondaryButtonStyle(color: Palette.sage))
                .disabled(store.data.crates.isEmpty).opacity(store.data.crates.isEmpty ? 0.6 : 1)
            }

            if store.data.crates.isEmpty {
                EmptyHint(symbol: "shippingbox", title: "No crates", message: "Add crates to prepare a safe transit.")
            } else {
                ForEach(store.data.crates) { crate in crateCard(crate) }
            }
        }
        .sheet(isPresented: $adding) {
            CrateEditor { label, count, water in
                store.data.crates.append(TransportCrate(label: label, birdCount: count, hasWater: water))
                toastMessage = "Crate added"
            }.environmentObject(store)
        }
        .toast($toastMessage)
    }

    private func readyRow(_ title: String, _ ok: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: ok ? "checkmark.circle.fill" : "circle")
                .foregroundColor(ok ? Palette.sage : Palette.secondaryText(scheme))
            Text(title).font(.system(size: 14)).foregroundColor(Palette.primaryText(scheme))
            Spacer()
        }
    }

    private func crateCard(_ crate: TransportCrate) -> some View {
        CoopCard(accent: crate.loaded ? Palette.sage : Palette.clay) {
            HStack(spacing: 12) {
                Image(systemName: "shippingbox.fill").font(.system(size: 20))
                    .foregroundColor(crate.loaded ? Palette.sage : Palette.clay)
                VStack(alignment: .leading, spacing: 2) {
                    Text(crate.label).font(.system(size: 15, weight: .bold)).foregroundColor(Palette.primaryText(scheme))
                    Text("\(crate.birdCount) birds · \(crate.hasWater ? "water ✓" : "no water")")
                        .font(.system(size: 12)).foregroundColor(Palette.secondaryText(scheme))
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { crate.loaded },
                    set: { v in if let i = store.data.crates.firstIndex(where: { $0.id == crate.id }) { store.data.crates[i].loaded = v } }
                )).labelsHidden()
                Button { store.data.crates.removeAll { $0.id == crate.id } } label: {
                    Image(systemName: "trash").foregroundColor(Palette.danger)
                }.padding(.leading, 4)
            }
        }
    }
}

struct CrateEditor: View {
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.colorScheme) private var scheme
    var onSave: (String, Int, Bool) -> Void

    @State private var label = ""
    @State private var count = 4
    @State private var water = true

    var body: some View {
        NavigationView {
            ZStack {
                BarnWoodBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(icon: "shippingbox.fill", title: "Add Crate")
                        ThemedField(title: "Label", placeholder: "e.g. Crate A", text: $label)
                        StepperRow(title: "Birds in crate", value: $count, range: 1...50).fieldChrome()
                        ToggleRow(icon: "drop.fill", title: "Water onboard", isOn: $water, tint: Palette.sky).fieldChrome()
                        Button {
                            onSave(label.isEmpty ? "Crate" : label, count, water)
                            presentationMode.wrappedValue.dismiss()
                        } label: { Label("Add Crate", systemImage: "checkmark.circle.fill") }
                        .buttonStyle(PrimaryButtonStyle(color: Palette.clay))
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
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
