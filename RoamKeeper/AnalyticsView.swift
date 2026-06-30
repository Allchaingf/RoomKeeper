//
//  AnalyticsView.swift
//  RoamKeeper
//
//  Screen 12 — Weekly Trends, Screen 13 — Compare Groups, Screen 14 — Farm
//  Report (with real PDF export via UIActivityViewController).
//

import SwiftUI
import UIKit

// MARK: - Share sheet

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - Screen 12: Weekly Analytics

struct WeeklyAnalyticsView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) private var scheme

    enum Metric: String, CaseIterable, Identifiable {
        case entries = "Entries"
        case consistency = "Consistency"
        case costs = "Costs"
        case stock = "Stock"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .entries: return "square.stack.3d.up.fill"
            case .consistency: return "checkmark.seal.fill"
            case .costs: return "dollarsign.circle.fill"
            case .stock: return "shippingbox.fill"
            }
        }
    }

    @State private var shown: Set<Metric> = Set(Metric.allCases)
    @State private var showFilter = false

    var body: some View {
        ScreenScaffold(icon: "chart.bar.fill", title: "Weekly Trends",
                       subtitle: "Care regularity, costs & stock at a glance") {

            HStack(spacing: 12) {
                NavigationLink(destination: TrendCompareView()) {
                    Label("Compare Weeks", systemImage: "chart.bar.xaxis")
                }
                .buttonStyle(PrimaryButtonStyle(color: Palette.amberDeep))
                Button { withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showFilter.toggle() } } label: {
                    Label("Filter", systemImage: "line.horizontal.3.decrease.circle.fill")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            if showFilter {
                CoopCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Show metrics").font(.system(size: 13, weight: .bold)).foregroundColor(Palette.primaryText(scheme))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Metric.allCases) { m in
                                    Button {
                                        withAnimation { if shown.contains(m) { shown.remove(m) } else { shown.insert(m) } }
                                    } label: {
                                        Chip(text: m.rawValue, symbol: m.symbol, color: Palette.amber, selected: shown.contains(m))
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if shown.contains(.entries) {
                chartCard(title: "Entries this week", color: Palette.amber) {
                    MiniBarChart(points: store.weeklyEntryCounts(), color: Palette.amber, height: 120)
                }
            }
            if shown.contains(.consistency) {
                chartCard(title: "Care consistency (%)", color: Palette.sage) {
                    LineChart(values: store.consistencySeries(), color: Palette.sage, height: 120)
                }
            }
            if shown.contains(.costs) {
                chartCard(title: "Costs (last 4 weeks)", color: Palette.amberDeep) {
                    MiniBarChart(points: store.weeklyCostSeries(), color: Palette.amberDeep, height: 120)
                }
            }
            if shown.contains(.stock) {
                chartCard(title: "Stock levels", color: Palette.clay) {
                    MiniBarChart(points: store.data.inventory.prefix(6).map {
                        BarPoint(label: String($0.name.prefix(4)), value: $0.quantity)
                    }, color: Palette.clay, height: 120)
                }
            }

            // Quick summary tiles
            HStack(spacing: 12) {
                StatTile(value: "\(store.data.entries.count)", label: "Total entries", symbol: "square.stack.3d.up.fill", color: Palette.amber)
                StatTile(value: store.currency(store.costsThisMonth()), label: "Spent this month", symbol: "dollarsign.circle.fill", color: Palette.sage)
            }
        }
    }

    @ViewBuilder
    private func chartCard<Content: View>(title: String, color: Color, @ViewBuilder content: @escaping () -> Content) -> some View {
        CoopCard(accent: color) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.system(size: 14, weight: .bold)).foregroundColor(Palette.primaryText(scheme))
                content()
            }
        }
    }
}

// MARK: - Screen 13: Trend Compare

struct TrendCompareView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) private var scheme

    enum CompareMetric: String, CaseIterable, Identifiable {
        case cost = "Cost (30d)"
        case entries = "Entries (30d)"
        case birds = "Bird count"
        var id: String { rawValue }
    }

    @State private var metric: CompareMetric = .cost
    @State private var selected: Set<UUID> = []
    @State private var showSelect = true
    @State private var applied = false

    var body: some View {
        ScreenScaffold(icon: "chart.bar.xaxis", title: "Compare Groups",
                       subtitle: "See where the load really is") {

            EnumChips(title: "Metric", options: CompareMetric.allCases, selection: $metric,
                      label: { $0.rawValue })

            HStack(spacing: 12) {
                Button { withAnimation { showSelect.toggle() } } label: {
                    Label("Select Groups", systemImage: "list.bullet.rectangle")
                }
                .buttonStyle(SecondaryButtonStyle())
                Button { withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { applied = true } } label: {
                    Label("Apply", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(PrimaryButtonStyle(color: Palette.amberDeep))
                .disabled(selected.isEmpty)
                .opacity(selected.isEmpty ? 0.6 : 1)
            }

            if showSelect {
                CoopCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Groups to compare").font(.system(size: 13, weight: .bold)).foregroundColor(Palette.primaryText(scheme))
                        ForEach(store.data.groups) { g in
                            Button {
                                withAnimation { if selected.contains(g.id) { selected.remove(g.id) } else { selected.insert(g.id) } }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: selected.contains(g.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selected.contains(g.id) ? Palette.sage : Palette.secondaryText(scheme))
                                    Circle().fill(g.tag.color).frame(width: 10, height: 10)
                                    Text(g.name).font(.system(size: 14, weight: .semibold)).foregroundColor(Palette.primaryText(scheme))
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }

            if applied && !selected.isEmpty {
                CoopCard(accent: Palette.amberDeep) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(metric.rawValue) by group").font(.system(size: 14, weight: .bold))
                            .foregroundColor(Palette.primaryText(scheme))
                        MiniBarChart(points: comparePoints(), color: Palette.amberDeep, height: 140)
                    }
                }
            } else {
                EmptyHint(symbol: "chart.bar", title: "Pick groups & Apply",
                          message: "Select two or more groups to compare them side by side.")
            }
        }
    }

    private func comparePoints() -> [BarPoint] {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return store.data.groups.filter { selected.contains($0.id) }.map { g in
            let value: Double
            switch metric {
            case .cost:
                value = store.data.costs.filter { $0.groupId == g.id && $0.date >= cutoff }.reduce(0) { $0 + $1.amount }
            case .entries:
                value = Double(store.data.entries.filter { $0.groupId == g.id && $0.date >= cutoff }.count)
            case .birds:
                value = Double(g.count)
            }
            return BarPoint(label: String(g.name.prefix(5)), value: value)
        }
    }
}

// MARK: - Screen 14: Report Builder

struct ReportBuilderView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) private var scheme

    @State private var days = 7
    @State private var generated = false
    @State private var reportText = ""
    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var toastMessage: String?

    var body: some View {
        ScreenScaffold(icon: "doc.text.fill", title: "Farm Report",
                       subtitle: "Events, costs, tasks & alerts for a period") {

            CoopCard {
                VStack(alignment: .leading, spacing: 12) {
                    FieldLabel(text: "Period")
                    HStack(spacing: 8) {
                        ForEach([7, 14, 30], id: \.self) { d in
                            Button { withAnimation { days = d; generated = false } } label: {
                                Chip(text: "\(d) days", color: Palette.berry, selected: days == d)
                            }
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                Button {
                    reportText = buildReport()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { generated = true }
                } label: { Label("Generate Report", systemImage: "doc.badge.gearshape") }
                .buttonStyle(PrimaryButtonStyle(color: Palette.berry))

                Button {
                    if !generated { reportText = buildReport(); generated = true }
                    if let url = makePDF(reportText) {
                        shareURL = url; showShare = true
                    } else { toastMessage = "Export failed" }
                } label: { Label("Export PDF", systemImage: "square.and.arrow.up") }
                .buttonStyle(SecondaryButtonStyle())
            }

            if generated {
                CoopCard(accent: Palette.berry) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview").font(.system(size: 14, weight: .bold)).foregroundColor(Palette.primaryText(scheme))
                        Text(reportText)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(Palette.primaryText(scheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .sheet(isPresented: $showShare) {
            if let url = shareURL { ShareSheet(items: [url]) }
        }
        .toast($toastMessage)
    }

    private func buildReport() -> String {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let entries = store.data.entries.filter { $0.date >= cutoff }
        let costs = store.data.costs.filter { $0.date >= cutoff }
        let costTotal = costs.reduce(0) { $0 + $1.amount }
        let openTasks = store.openTasks.count
        let flags = store.riskFlags().count

        var lines: [String] = []
        lines.append("ROAM KEEPER — FARM REPORT")
        lines.append("Generated \(AppStore.dateString(Date()))")
        lines.append("Period: last \(days) days")
        lines.append("")
        lines.append("FLOCK")
        lines.append("  Groups: \(store.data.groups.count)   Birds: \(store.totalBirds)")
        lines.append("  Zones:  \(store.data.zones.count)")
        lines.append("")
        lines.append("ACTIVITY")
        lines.append("  Care entries: \(entries.count)")
        for kind in EntryKind.allCases {
            let c = entries.filter { $0.kind == kind }.count
            if c > 0 { lines.append("    - \(kind.rawValue): \(c)") }
        }
        lines.append("  Care consistency (7d): \(Int((store.consistency() * 100).rounded()))%")
        lines.append("")
        lines.append("COSTS")
        lines.append("  Total: \(store.currency(costTotal))")
        for (cat, amt) in store.costByCategory(now: Date()) {
            lines.append("    - \(cat.rawValue): \(store.currency(amt))")
        }
        lines.append("")
        lines.append("ATTENTION")
        lines.append("  Open tasks: \(openTasks)")
        lines.append("  Low-stock items: \(store.lowStockItems.count)")
        lines.append("  Active risk flags: \(flags)")
        lines.append("")
        lines.append("Made offline with Roam Keeper.")
        return lines.joined(separator: "\n")
    }

    private func makePDF(_ text: String) -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("RoamKeeper-Report.pdf")
        do {
            try renderer.writePDF(to: url) { ctx in
                ctx.beginPage()
                // Amber header band
                let header = CGRect(x: 0, y: 0, width: pageRect.width, height: 70)
                UIColor(Palette.amber).setFill()
                ctx.cgContext.fill(header)
                let titleAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 26, weight: .heavy),
                    .foregroundColor: UIColor.white
                ]
                ("Roam Keeper" as NSString).draw(at: CGPoint(x: 36, y: 20), withAttributes: titleAttr)

                let bodyAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: UIColor.darkText
                ]
                (text as NSString).draw(in: CGRect(x: 36, y: 90, width: pageRect.width - 72, height: pageRect.height - 120),
                                        withAttributes: bodyAttr)
            }
            return url
        } catch {
            return nil
        }
    }
}
