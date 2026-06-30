//
//  InventoryView.swift
//  RoamKeeper
//
//  Screen 4 — Supplies (Inventory Shelf) and Screen 5 — Farm Costs
//  (Cost Tracker).
//

import SwiftUI

// MARK: - Screen 4: Inventory Shelf

struct InventoryShelfView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) private var scheme

    @State private var filter: InventoryCategory? = nil
    @State private var lowOnly = false
    @State private var editing: InventoryItem?
    @State private var creating = false
    @State private var toastMessage: String?

    private var items: [InventoryItem] {
        store.data.inventory.filter { item in
            (filter == nil || item.category == filter) && (!lowOnly || item.isLow)
        }
    }

    var body: some View {
        ScreenScaffold(icon: "shippingbox.fill", title: "Supplies",
                       subtitle: "\(store.lowStockItems.count) below minimum") {

            HStack(spacing: 12) {
                Button { creating = true } label: { Label("Add Item", systemImage: "plus.circle.fill") }
                    .buttonStyle(PrimaryButtonStyle(color: Palette.clay))
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { lowOnly.toggle() }
                } label: { Label("Low Stock", systemImage: lowOnly ? "checkmark.circle.fill" : "exclamationmark.triangle.fill") }
                .buttonStyle(SecondaryButtonStyle(color: lowOnly ? Palette.sage : Palette.danger))
            }

            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button { withAnimation { filter = nil } } label: {
                        Chip(text: "All", color: Palette.amber, selected: filter == nil)
                    }
                    ForEach(InventoryCategory.allCases) { c in
                        Button { withAnimation { filter = (filter == c ? nil : c) } } label: {
                            Chip(text: c.rawValue, symbol: c.symbol, color: Palette.amber, selected: filter == c)
                        }
                    }
                }
            }

            if items.isEmpty {
                EmptyHint(symbol: "shippingbox", title: lowOnly ? "Nothing low" : "No supplies",
                          message: lowOnly ? "All stock is above its minimum level." : "Add feed, bedding and hardware to track stock.")
            } else {
                ForEach(items) { item in itemCard(item) }
            }
        }
        .sheet(isPresented: $creating) {
            InventoryEditorView(item: nil) { toastMessage = "Item added" }.environmentObject(store)
        }
        .sheet(item: $editing) { i in
            InventoryEditorView(item: i) { toastMessage = "Item saved" }.environmentObject(store)
        }
        .toast($toastMessage)
    }

    private func itemCard(_ item: InventoryItem) -> some View {
        CoopCard(accent: item.isLow ? Palette.danger : Palette.sage) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill((item.isLow ? Palette.danger : Palette.sage).opacity(0.18)).frame(width: 40, height: 40)
                        Image(systemName: item.category.symbol).foregroundColor(item.isLow ? Palette.danger : Palette.sage)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(item.name).font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(Palette.primaryText(scheme))
                            if item.isLow {
                                Text("LOW").font(.system(size: 9, weight: .heavy)).foregroundColor(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Capsule().fill(Palette.danger))
                            }
                        }
                        Text("\(item.category.rawValue) · min \(store.trim(item.minLevel)) \(item.unit)")
                            .font(.system(size: 12)).foregroundColor(Palette.secondaryText(scheme))
                    }
                    Spacer()
                    Menu {
                        Button { editing = item } label: { Label("Edit", systemImage: "pencil") }
                        Button { store.data.inventory.removeAll { $0.id == item.id } } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis").foregroundColor(Palette.secondaryText(scheme)).padding(4)
                    }
                }
                HStack {
                    Text("In stock").font(.system(size: 13, weight: .semibold)).foregroundColor(Palette.secondaryText(scheme))
                    Spacer()
                    HStack(spacing: 14) {
                        Button { adjust(item, -1) } label: { Image(systemName: "minus.circle.fill") }
                        Text("\(store.trim(item.quantity)) \(item.unit)")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(Palette.primaryText(scheme))
                        Button { adjust(item, 1) } label: { Image(systemName: "plus.circle.fill") }
                    }
                    .font(.system(size: 24)).foregroundColor(Palette.amberDeep)
                }
            }
        }
    }

    private func adjust(_ item: InventoryItem, _ delta: Double) {
        guard let idx = store.data.inventory.firstIndex(where: { $0.id == item.id }) else { return }
        store.data.inventory[idx].quantity = Swift.max(0, store.data.inventory[idx].quantity + delta)
    }
}

struct InventoryEditorView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.colorScheme) private var scheme
    let item: InventoryItem?
    var onSave: () -> Void

    @State private var name = ""
    @State private var category: InventoryCategory = .feed
    @State private var quantityText = ""
    @State private var unit = "kg"
    @State private var minText = ""

    var body: some View {
        NavigationView {
            ZStack {
                BarnWoodBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(icon: "shippingbox.fill", title: item == nil ? "New Item" : "Edit Item")
                        ThemedField(title: "Name", placeholder: "e.g. Layer Pellets", text: $name)
                        EnumChips(title: "Category", options: InventoryCategory.allCases, selection: $category,
                                  label: { $0.rawValue }, symbol: { $0.symbol })
                        HStack(spacing: 12) {
                            ThemedField(title: "Quantity", placeholder: "0", text: $quantityText, keyboard: .decimalPad)
                            ThemedField(title: "Unit", placeholder: "kg", text: $unit)
                        }
                        ThemedField(title: "Minimum level", placeholder: "0", text: $minText, keyboard: .decimalPad)
                        Button(action: save) { Label("Save Item", systemImage: "checkmark.circle.fill") }
                            .buttonStyle(PrimaryButtonStyle(color: Palette.clay))
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
        guard let i = item else { return }
        name = i.name; category = i.category; quantityText = store.trim(i.quantity); unit = i.unit; minText = store.trim(i.minLevel)
    }
    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let qty = Double(quantityText) ?? 0
        let min = Double(minText) ?? 0
        if let i = item, let idx = store.data.inventory.firstIndex(where: { $0.id == i.id }) {
            store.data.inventory[idx].name = trimmed
            store.data.inventory[idx].category = category
            store.data.inventory[idx].quantity = qty
            store.data.inventory[idx].unit = unit
            store.data.inventory[idx].minLevel = min
        } else {
            store.data.inventory.insert(InventoryItem(name: trimmed, category: category, quantity: qty,
                                                      unit: unit, minLevel: min), at: 0)
        }
        onSave(); presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Screen 5: Cost Tracker

struct CostTrackerView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) private var scheme

    @State private var monthRef = Date()
    @State private var showBreakdown = true
    @State private var creating = false
    @State private var toastMessage: String?

    private var monthCosts: [CostItem] {
        store.data.costs.filter { Calendar.current.isDate($0.date, equalTo: monthRef, toGranularity: .month) }
            .sorted { $0.date > $1.date }
    }
    private var monthTotal: Double { monthCosts.reduce(0) { $0 + $1.amount } }

    private var monthLabel: String {
        let f = DateFormatter(); f.dateFormat = "LLLL yyyy"; return f.string(from: monthRef)
    }

    var body: some View {
        ScreenScaffold(icon: "dollarsign.circle.fill", title: "Farm Costs",
                       subtitle: "Spending by category, week & group") {

            // Month navigator
            CoopCard(accent: Palette.sage) {
                HStack {
                    Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left.circle.fill") }
                        .font(.system(size: 24)).foregroundColor(Palette.amberDeep)
                    Spacer()
                    VStack(spacing: 2) {
                        Text(monthLabel).font(.system(size: 15, weight: .bold)).foregroundColor(Palette.primaryText(scheme))
                        Text(store.currency(monthTotal)).font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundColor(Palette.sage)
                    }
                    Spacer()
                    Button { shiftMonth(1) } label: { Image(systemName: "chevron.right.circle.fill") }
                        .font(.system(size: 24)).foregroundColor(Palette.amberDeep)
                }
            }

            HStack(spacing: 12) {
                Button { creating = true } label: { Label("Add Cost", systemImage: "plus.circle.fill") }
                    .buttonStyle(PrimaryButtonStyle(color: Palette.sage))
                Button { withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showBreakdown.toggle() } } label: {
                    Label("View Month", systemImage: showBreakdown ? "eye.fill" : "eye.slash.fill")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            if showBreakdown {
                CoopCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("By category").font(.system(size: 14, weight: .bold)).foregroundColor(Palette.primaryText(scheme))
                        let cats = store.costByCategory(now: monthRef)
                        if cats.isEmpty {
                            Text("No costs this month.").font(.system(size: 13)).foregroundColor(Palette.secondaryText(scheme))
                        } else {
                            MiniBarChart(points: cats.map { BarPoint(label: shortCat($0.0), value: $0.1) },
                                         color: Palette.sage, height: 110)
                        }
                    }
                }
                CoopCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Last 4 weeks").font(.system(size: 14, weight: .bold)).foregroundColor(Palette.primaryText(scheme))
                        MiniBarChart(points: store.weeklyCostSeries(), color: Palette.amber, height: 110)
                    }
                }
            }

            SectionHeader(icon: "list.bullet.rectangle", title: "Entries")
            if monthCosts.isEmpty {
                EmptyHint(symbol: "dollarsign.circle", title: "No costs", message: "Add a cost to see weekly and category trends.")
            } else {
                ForEach(monthCosts) { c in costRow(c) }
            }
        }
        .sheet(isPresented: $creating) {
            CostEditorView { toastMessage = "Cost added" }.environmentObject(store)
        }
        .toast($toastMessage)
    }

    private func costRow(_ c: CostItem) -> some View {
        CoopCard {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Palette.sage.opacity(0.18)).frame(width: 38, height: 38)
                    Image(systemName: c.category.symbol).foregroundColor(Palette.sage)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(c.title).font(.system(size: 14, weight: .bold)).foregroundColor(Palette.primaryText(scheme))
                    Text("\(c.category.rawValue) · \(store.groupName(c.groupId)) · \(AppStore.dateString(c.date))")
                        .font(.system(size: 12)).foregroundColor(Palette.secondaryText(scheme)).lineLimit(1)
                }
                Spacer()
                Text(store.currency(c.amount)).font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(Palette.sage)
                Button { store.data.costs.removeAll { $0.id == c.id } } label: {
                    Image(systemName: "trash").foregroundColor(Palette.danger)
                }.padding(.leading, 4)
            }
        }
    }

    private func shiftMonth(_ delta: Int) {
        if let d = Calendar.current.date(byAdding: .month, value: delta, to: monthRef) {
            withAnimation { monthRef = d }
        }
    }
    private func shortCat(_ c: CostCategory) -> String { String(c.rawValue.prefix(4)) }
}

struct CostEditorView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.colorScheme) private var scheme
    var onSave: () -> Void

    @State private var title = ""
    @State private var amountText = ""
    @State private var category: CostCategory = .feed
    @State private var groupId: UUID?
    @State private var date = Date()

    var body: some View {
        NavigationView {
            ZStack {
                BarnWoodBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(icon: "dollarsign.circle.fill", title: "Add Cost")
                        ThemedField(title: "Title", placeholder: "e.g. Feed delivery", text: $title)
                        ThemedField(title: "Amount", placeholder: "0", text: $amountText, keyboard: .decimalPad)
                        EnumChips(title: "Category", options: CostCategory.allCases, selection: $category,
                                  label: { $0.rawValue }, symbol: { $0.symbol }, color: Palette.sage)
                        VStack(alignment: .leading, spacing: 6) {
                            FieldLabel(text: "Group")
                            Menu {
                                Button("None") { groupId = nil }
                                ForEach(store.data.groups) { g in Button(g.name) { groupId = g.id } }
                            } label: {
                                HStack {
                                    Text(groupId == nil ? "None" : store.groupName(groupId))
                                        .foregroundColor(Palette.primaryText(scheme))
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down").foregroundColor(Palette.secondaryText(scheme))
                                }.fieldChrome()
                            }
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            FieldLabel(text: "Date")
                            DatePicker("", selection: $date, displayedComponents: [.date])
                                .labelsHidden().datePickerStyle(CompactDatePickerStyle())
                        }
                        Button {
                            let amt = Double(amountText) ?? 0
                            store.data.costs.insert(CostItem(title: title.isEmpty ? category.rawValue : title,
                                                             amount: amt, category: category, date: date, groupId: groupId), at: 0)
                            onSave(); presentationMode.wrappedValue.dismiss()
                        } label: { Label("Save Cost", systemImage: "checkmark.circle.fill") }
                        .buttonStyle(PrimaryButtonStyle(color: Palette.sage))
                        .disabled((Double(amountText) ?? 0) <= 0)
                        .opacity((Double(amountText) ?? 0) <= 0 ? 0.6 : 1)
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
