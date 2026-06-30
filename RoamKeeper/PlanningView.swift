//
//  PlanningView.swift
//  RoamKeeper
//
//  Screen 6 — Farm Tasks, 7 — Local Reminders, 8 — Structured Notes,
//  9 — Photo Notes, 10 — Farm Alerts, 11 — End of Day Review.
//

import SwiftUI
import PhotosUI
import UserNotifications

// MARK: - Photo picker (PHPicker, iOS 14+)

struct PhotoPicker: UIViewControllerRepresentable {
    var onPick: (UIImage) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        init(_ parent: PhotoPicker) { self.parent = parent }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { image, _ in
                if let img = image as? UIImage {
                    DispatchQueue.main.async { self.parent.onPick(img) }
                }
            }
        }
    }
}

// MARK: - Screen 6: Task Board

struct TaskBoardView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) private var scheme
    @State private var sortByPriority = false
    @State private var showDone = false
    @State private var creating = false
    @State private var toastMessage: String?

    private var tasks: [FarmTask] {
        var t = store.data.tasks.filter { showDone || !$0.done }
        if sortByPriority { t.sort { $0.priority.rank > $1.priority.rank } }
        else { t.sort { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) } }
        return t
    }

    var body: some View {
        ScreenScaffold(icon: "list.bullet.rectangle", title: "Farm Tasks",
                       subtitle: "\(store.openTasks.count) open · \(store.overdueTasks().count) overdue") {
            HStack(spacing: 12) {
                Button { creating = true } label: { Label("New Task", systemImage: "plus.circle.fill") }
                    .buttonStyle(PrimaryButtonStyle())
                Button { withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { sortByPriority.toggle() } } label: {
                    Label("Set Priority", systemImage: sortByPriority ? "arrow.up.arrow.down.circle.fill" : "arrow.up.arrow.down.circle")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            Toggle(isOn: $showDone) {
                Text("Show completed").font(.system(size: 14, weight: .semibold)).foregroundColor(Palette.primaryText(scheme))
            }
            .toggleStyle(SwitchToggleStyle(tint: Palette.amber))
            .padding(.horizontal, 4)

            if tasks.isEmpty {
                EmptyHint(symbol: "list.bullet.rectangle", title: "No tasks", message: "Add repairs, purchases, cleaning or control tasks.")
            } else {
                ForEach(tasks) { task in taskCard(task) }
            }
        }
        .sheet(isPresented: $creating) {
            TaskEditorView { toastMessage = "Task added" }.environmentObject(store)
        }
        .toast($toastMessage)
    }

    private func taskCard(_ task: FarmTask) -> some View {
        let overdue = task.dueDate != nil && task.dueDate! < Calendar.current.startOfDay(for: Date()) && !task.done
        return CoopCard(accent: task.done ? Palette.sage : task.priority.color) {
            HStack(spacing: 12) {
                Button { toggleDone(task) } label: {
                    Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24)).foregroundColor(task.done ? Palette.sage : Palette.secondaryText(scheme))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title).font(.system(size: 15, weight: .bold))
                        .foregroundColor(Palette.primaryText(scheme))
                        .strikethrough(task.done, color: Palette.secondaryText(scheme))
                    HStack(spacing: 6) {
                        Text(task.priority.rawValue).font(.system(size: 10, weight: .heavy)).foregroundColor(.white)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Capsule().fill(task.priority.color))
                        Label(task.category.rawValue, systemImage: task.category.symbol)
                            .font(.system(size: 11)).foregroundColor(Palette.secondaryText(scheme))
                        if let due = task.dueDate {
                            Text(AppStore.dateString(due)).font(.system(size: 11))
                                .foregroundColor(overdue ? Palette.danger : Palette.secondaryText(scheme))
                        }
                    }
                }
                Spacer()
                Menu {
                    Menu("Priority") {
                        ForEach(Priority.allCases) { p in Button(p.rawValue) { setPriority(task, p) } }
                    }
                    Button { store.data.tasks.removeAll { $0.id == task.id } } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis").foregroundColor(Palette.secondaryText(scheme)).padding(4)
                }
            }
        }
    }

    private func toggleDone(_ task: FarmTask) {
        guard let idx = store.data.tasks.firstIndex(where: { $0.id == task.id }) else { return }
        withAnimation { store.data.tasks[idx].done.toggle() }
    }
    private func setPriority(_ task: FarmTask, _ p: Priority) {
        guard let idx = store.data.tasks.firstIndex(where: { $0.id == task.id }) else { return }
        store.data.tasks[idx].priority = p
    }
}

struct TaskEditorView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.colorScheme) private var scheme
    var onSave: () -> Void

    @State private var title = ""
    @State private var priority: Priority = .medium
    @State private var category: TaskCategory = .control
    @State private var hasDue = true
    @State private var due = Date()
    @State private var zoneId: UUID?

    var body: some View {
        NavigationView {
            ZStack {
                BarnWoodBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(icon: "list.bullet.rectangle", title: "New Task")
                        ThemedField(title: "Title", placeholder: "What needs doing?", text: $title)
                        EnumChips(title: "Priority", options: Priority.allCases, selection: $priority,
                                  label: { $0.rawValue }, color: priority.color)
                        EnumChips(title: "Category", options: TaskCategory.allCases, selection: $category,
                                  label: { $0.rawValue }, symbol: { $0.symbol })
                        ToggleRow(icon: "calendar", title: "Has due date", isOn: $hasDue).fieldChrome()
                        if hasDue {
                            DatePicker("", selection: $due, displayedComponents: [.date])
                                .labelsHidden().datePickerStyle(GraphicalDatePickerStyle())
                                .accentColor(Palette.amber)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            FieldLabel(text: "Zone")
                            Menu {
                                Button("None") { zoneId = nil }
                                ForEach(store.data.zones) { z in Button(z.name) { zoneId = z.id } }
                            } label: {
                                HStack {
                                    Text(zoneId == nil ? "None" : store.zoneName(zoneId)).foregroundColor(Palette.primaryText(scheme))
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down").foregroundColor(Palette.secondaryText(scheme))
                                }.fieldChrome()
                            }
                        }
                        Button {
                            store.data.tasks.insert(FarmTask(title: title.isEmpty ? "Task" : title, priority: priority,
                                                             category: category, dueDate: hasDue ? due : nil, zoneId: zoneId), at: 0)
                            onSave(); presentationMode.wrappedValue.dismiss()
                        } label: { Label("Save Task", systemImage: "checkmark.circle.fill") }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity(title.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1)
                    }
                    .padding(16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { presentationMode.wrappedValue.dismiss() } }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Screen 7: Reminder Queue

struct ReminderQueueView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) private var scheme
    @State private var creating = false
    @State private var toastMessage: String?

    var body: some View {
        ScreenScaffold(icon: "bell.fill", title: "Local Reminders",
                       subtitle: "Offline nudges — no account needed") {

            if !settings.notificationsEnabled {
                CoopCard(accent: Palette.amber) {
                    HStack(spacing: 10) {
                        Image(systemName: "bell.slash.fill").foregroundColor(Palette.amber)
                        Text("Turn on notifications in Settings to deliver these reminders.")
                            .font(.system(size: 13)).foregroundColor(Palette.primaryText(scheme))
                    }
                }
            }

            HStack(spacing: 12) {
                Button { creating = true } label: { Label("Add Reminder", systemImage: "plus.circle.fill") }
                    .buttonStyle(PrimaryButtonStyle(color: Palette.berry))
                Button {
                    scheduleSnooze()
                    toastMessage = "Snoozed 10 min"
                } label: { Label("Snooze", systemImage: "zzz") }
                .buttonStyle(SecondaryButtonStyle())
            }

            if store.data.reminders.isEmpty {
                EmptyHint(symbol: "bell", title: "No reminders", message: "Add morning, evening, transport or cleaning nudges.")
            } else {
                ForEach(store.data.reminders) { reminder in reminderCard(reminder) }
            }
        }
        .sheet(isPresented: $creating) {
            ReminderEditorView { reminder in
                store.data.reminders.insert(reminder, at: 0)
                store.syncNotifications(enabled: settings.notificationsEnabled)
                toastMessage = "Reminder added"
            }
        }
        .toast($toastMessage)
    }

    private func reminderCard(_ reminder: Reminder) -> some View {
        CoopCard(accent: reminder.enabled ? Palette.berry : Palette.slateColor) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Palette.berry.opacity(0.18)).frame(width: 40, height: 40)
                    Image(systemName: reminder.kind.symbol).foregroundColor(Palette.berry)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(reminder.title).font(.system(size: 15, weight: .bold)).foregroundColor(Palette.primaryText(scheme))
                    Text("\(timeText(reminder)) · \(reminder.kind.rawValue)\(reminder.routeTarget.isEmpty ? "" : " → \(reminder.routeTarget)")")
                        .font(.system(size: 12)).foregroundColor(Palette.secondaryText(scheme)).lineLimit(1)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { reminder.enabled },
                    set: { v in
                        if let i = store.data.reminders.firstIndex(where: { $0.id == reminder.id }) {
                            store.data.reminders[i].enabled = v
                            store.syncNotifications(enabled: settings.notificationsEnabled)
                        }
                    }
                )).labelsHidden()
                Button { store.data.reminders.removeAll { $0.id == reminder.id }; store.syncNotifications(enabled: settings.notificationsEnabled) } label: {
                    Image(systemName: "trash").foregroundColor(Palette.danger)
                }.padding(.leading, 4)
            }
        }
    }

    private func timeText(_ r: Reminder) -> String {
        var comps = DateComponents(); comps.hour = r.hour; comps.minute = r.minute
        let date = Calendar.current.date(from: comps) ?? Date()
        return AppStore.timeString(date)
    }

    private func scheduleSnooze() {
        let content = UNMutableNotificationContent()
        content.title = "Roam Keeper"
        content.body = "Snoozed reminder — time to check the flock."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 600, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "snooze-\(UUID().uuidString)", content: content, trigger: trigger))
    }
}

struct ReminderEditorView: View {
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.colorScheme) private var scheme
    var onSave: (Reminder) -> Void

    @State private var title = ""
    @State private var kind: ReminderKind = .morning
    @State private var time = Date()
    @State private var target = ""

    var body: some View {
        NavigationView {
            ZStack {
                BarnWoodBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(icon: "bell.fill", title: "New Reminder")
                        ThemedField(title: "Title", placeholder: "e.g. Open coop & feed", text: $title)
                        EnumChips(title: "Kind", options: ReminderKind.allCases, selection: $kind,
                                  label: { $0.rawValue }, symbol: { $0.symbol }, color: Palette.berry)
                        VStack(alignment: .leading, spacing: 6) {
                            FieldLabel(text: "Time")
                            DatePicker("", selection: $time, displayedComponents: [.hourAndMinute])
                                .labelsHidden().datePickerStyle(WheelDatePickerStyle())
                                .frame(maxHeight: 140)
                        }
                        ThemedField(title: "Leads to (optional)", placeholder: "e.g. Daily Care Checklist", text: $target)
                        Button {
                            let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
                            onSave(Reminder(title: title.isEmpty ? kind.rawValue : title, kind: kind,
                                            hour: comps.hour ?? 7, minute: comps.minute ?? 0, enabled: true, routeTarget: target))
                            presentationMode.wrappedValue.dismiss()
                        } label: { Label("Save Reminder", systemImage: "checkmark.circle.fill") }
                        .buttonStyle(PrimaryButtonStyle(color: Palette.berry))
                    }
                    .padding(16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { presentationMode.wrappedValue.dismiss() } }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Screen 8: Notes Board

struct NotesBoardView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) private var scheme
    @State private var zoneFilter: UUID?
    @State private var editing: FarmNote?
    @State private var creating = false
    @State private var toastMessage: String?

    private var notes: [FarmNote] {
        store.data.notes.filter { zoneFilter == nil || $0.zoneId == zoneFilter }.sorted { $0.date > $1.date }
    }

    var body: some View {
        ScreenScaffold(icon: "note.text", title: "Structured Notes",
                       subtitle: "Cards with zone, group, tag & date") {
            HStack(spacing: 12) {
                Button { creating = true } label: { Label("Add Note", systemImage: "plus.circle.fill") }
                    .buttonStyle(PrimaryButtonStyle(color: Palette.sky))
                Menu {
                    Button("All zones") { zoneFilter = nil }
                    ForEach(store.data.zones) { z in Button(z.name) { zoneFilter = z.id } }
                } label: {
                    Label(zoneFilter == nil ? "Link to Zone" : store.zoneName(zoneFilter), systemImage: "map.fill")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(Palette.amberDeep)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Palette.amberDeep.opacity(0.12)))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.amberDeep.opacity(0.4), lineWidth: 1))
                }
            }

            if notes.isEmpty {
                EmptyHint(symbol: "note.text", title: "No notes", message: "Capture observations linked to a zone or group.")
            } else {
                ForEach(notes) { note in noteCard(note) }
            }
        }
        .sheet(isPresented: $creating) {
            NoteEditorView(note: nil) { toastMessage = "Note added" }.environmentObject(store)
        }
        .sheet(item: $editing) { n in
            NoteEditorView(note: n) { toastMessage = "Note saved" }.environmentObject(store)
        }
        .toast($toastMessage)
    }

    private func noteCard(_ note: FarmNote) -> some View {
        CoopCard(accent: Palette.sky) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(note.title).font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Palette.primaryText(scheme))
                    Spacer()
                    Menu {
                        Button { editing = note } label: { Label("Edit", systemImage: "pencil") }
                        Button {
                            PhotoStore.delete(note.photoFile)
                            store.data.notes.removeAll { $0.id == note.id }
                        } label: { Label("Delete", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis").foregroundColor(Palette.secondaryText(scheme)).padding(4)
                    }
                }
                if !note.body.isEmpty {
                    Text(note.body).font(.system(size: 13)).foregroundColor(Palette.secondaryText(scheme))
                }
                HStack(spacing: 8) {
                    if !note.tag.isEmpty { Chip(text: note.tag, symbol: "tag.fill", color: Palette.sky) }
                    Chip(text: store.zoneName(note.zoneId), symbol: "map.fill", color: Palette.sage)
                    Spacer()
                    Text(AppStore.dateString(note.date)).font(.system(size: 11))
                        .foregroundColor(Palette.secondaryText(scheme))
                }
            }
        }
    }
}

struct NoteEditorView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.colorScheme) private var scheme
    let note: FarmNote?
    var onSave: () -> Void

    @State private var title = ""
    @State private var body_ = ""
    @State private var tag = ""
    @State private var zoneId: UUID?
    @State private var groupId: UUID?

    var body: some View {
        NavigationView {
            ZStack {
                BarnWoodBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(icon: "note.text", title: note == nil ? "New Note" : "Edit Note")
                        ThemedField(title: "Title", placeholder: "Short headline", text: $title)
                        VStack(alignment: .leading, spacing: 6) {
                            FieldLabel(text: "Body")
                            TextEditor(text: $body_)
                                .frame(height: 110)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 12).fill(scheme == .dark ? Color.black.opacity(0.25) : Color.white.opacity(0.7)))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.cardStroke(scheme), lineWidth: 1))
                        }
                        ThemedField(title: "Tag", placeholder: "e.g. repair", text: $tag)
                        VStack(alignment: .leading, spacing: 6) {
                            FieldLabel(text: "Zone")
                            Menu {
                                Button("None") { zoneId = nil }
                                ForEach(store.data.zones) { z in Button(z.name) { zoneId = z.id } }
                            } label: {
                                HStack {
                                    Text(zoneId == nil ? "None" : store.zoneName(zoneId)).foregroundColor(Palette.primaryText(scheme))
                                    Spacer(); Image(systemName: "chevron.up.chevron.down").foregroundColor(Palette.secondaryText(scheme))
                                }.fieldChrome()
                            }
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            FieldLabel(text: "Group")
                            Menu {
                                Button("None") { groupId = nil }
                                ForEach(store.data.groups) { g in Button(g.name) { groupId = g.id } }
                            } label: {
                                HStack {
                                    Text(groupId == nil ? "None" : store.groupName(groupId)).foregroundColor(Palette.primaryText(scheme))
                                    Spacer(); Image(systemName: "chevron.up.chevron.down").foregroundColor(Palette.secondaryText(scheme))
                                }.fieldChrome()
                            }
                        }
                        Button(action: save) { Label("Save Note", systemImage: "checkmark.circle.fill") }
                            .buttonStyle(PrimaryButtonStyle(color: Palette.sky))
                            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                            .opacity(title.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1)
                    }
                    .padding(16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { presentationMode.wrappedValue.dismiss() } }
            }
            .onAppear(perform: load)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func load() {
        guard let n = note else { return }
        title = n.title; body_ = n.body; tag = n.tag; zoneId = n.zoneId; groupId = n.groupId
    }
    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if let n = note, let idx = store.data.notes.firstIndex(where: { $0.id == n.id }) {
            store.data.notes[idx].title = trimmed
            store.data.notes[idx].body = body_
            store.data.notes[idx].tag = tag
            store.data.notes[idx].zoneId = zoneId
            store.data.notes[idx].groupId = groupId
        } else {
            store.data.notes.insert(FarmNote(title: trimmed, body: body_, tag: tag, zoneId: zoneId,
                                             groupId: groupId, date: Date()), at: 0)
        }
        onSave(); presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Screen 9: Photo Markup

struct PhotoMarkupView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) private var scheme

    @State private var image: UIImage?
    @State private var marker: CGPoint? = nil   // normalized 0..1
    @State private var marking = false
    @State private var showPicker = false
    @State private var title = ""
    @State private var toastMessage: String?

    var body: some View {
        ScreenScaffold(icon: "photo.fill", title: "Photo Notes",
                       subtitle: "Attach a photo & mark the problem area") {

            HStack(spacing: 12) {
                Button { showPicker = true } label: { Label("Attach Photo", systemImage: "photo.on.rectangle.angled") }
                    .buttonStyle(PrimaryButtonStyle(color: Palette.clay))
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { marking.toggle() }
                } label: { Label(marking ? "Done Marking" : "Mark Area",
                                 systemImage: marking ? "checkmark.circle.fill" : "mappin.circle.fill") }
                .buttonStyle(SecondaryButtonStyle(color: marking ? Palette.sage : Palette.amberDeep))
                .disabled(image == nil).opacity(image == nil ? 0.6 : 1)
            }

            CoopCard(accent: Palette.clay) {
                if let img = image {
                    GeometryReader { geo in
                        ZStack {
                            Image(uiImage: img)
                                .resizable().scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.width * 0.7)
                                .clipped()
                                .cornerRadius(12)
                            if let m = marker {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 34)).foregroundColor(Palette.danger)
                                    .shadow(color: .black.opacity(0.4), radius: 3)
                                    .position(x: m.x * geo.size.width, y: m.y * geo.size.width * 0.7)
                            }
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    guard marking else { return }
                                    let h = geo.size.width * 0.7
                                    let nx = Swift.min(Swift.max(value.location.x / geo.size.width, 0), 1)
                                    let ny = Swift.min(Swift.max(value.location.y / h, 0), 1)
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        marker = CGPoint(x: nx, y: ny)
                                    }
                                }
                        )
                    }
                    .frame(height: UIScreen.main.bounds.width * 0.7)
                } else {
                    EmptyHint(symbol: "photo", title: "No photo yet", message: "Attach a photo of a coop or yard to mark a spot.")
                }
            }

            if marking {
                Text("Tap the photo to drop a marker on the problem area.")
                    .font(.system(size: 12)).foregroundColor(Palette.secondaryText(scheme))
            }

            if image != nil {
                ThemedField(title: "Title", placeholder: "e.g. Loose board, south wall", text: $title)
                Button {
                    saveNote()
                } label: { Label("Save Photo Note", systemImage: "tray.and.arrow.down.fill") }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(title.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1)
            }

            // Existing photo notes
            let photoNotes = store.data.notes.filter { $0.photoFile != nil }
            if !photoNotes.isEmpty {
                SectionHeader(icon: "rectangle.stack.fill", title: "Saved photo notes")
                ForEach(photoNotes) { note in
                    CoopCard {
                        HStack(spacing: 12) {
                            if let img = PhotoStore.load(note.photoFile) {
                                Image(uiImage: img).resizable().scaledToFill()
                                    .frame(width: 56, height: 56).clipped().cornerRadius(10)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(note.title).font(.system(size: 14, weight: .bold)).foregroundColor(Palette.primaryText(scheme))
                                Text(AppStore.dateString(note.date)).font(.system(size: 12)).foregroundColor(Palette.secondaryText(scheme))
                            }
                            Spacer()
                            Button {
                                PhotoStore.delete(note.photoFile)
                                store.data.notes.removeAll { $0.id == note.id }
                            } label: { Image(systemName: "trash").foregroundColor(Palette.danger) }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            PhotoPicker { img in
                image = img; marker = nil; marking = true
            }
        }
        .toast($toastMessage)
    }

    private func saveNote() {
        guard let img = image, let file = PhotoStore.save(img) else { return }
        var note = FarmNote(title: title, body: "Photo note", tag: "photo", zoneId: store.data.zones.first?.id,
                            groupId: nil, date: Date(), photoFile: file)
        note.markerX = marker.map { Double($0.x) }
        note.markerY = marker.map { Double($0.y) }
        store.data.notes.insert(note, at: 0)
        image = nil; marker = nil; marking = false; title = ""
        toastMessage = "Photo note saved"
    }
}

// MARK: - Screen 10: Risk Flags

struct RiskFlagsView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) private var scheme
    @State private var toastMessage: String?

    var body: some View {
        let flags = store.riskFlags()
        return ScreenScaffold(icon: "exclamationmark.triangle.fill", title: "Farm Alerts",
                              subtitle: "What to check first") {
            HStack(spacing: 12) {
                StatTile(value: "\(flags.filter { $0.severity == .high }.count)", label: "High priority", symbol: "flame.fill", color: Palette.danger)
                StatTile(value: "\(flags.count)", label: "Active flags", symbol: "exclamationmark.triangle.fill", color: Palette.amber)
            }

            Button {
                store.resolvedFlags = []
                toastMessage = "Re-scanned"
            } label: { Label("Review Flags", systemImage: "arrow.clockwise.circle.fill") }
            .buttonStyle(PrimaryButtonStyle(color: Palette.amberDeep))

            if flags.isEmpty {
                EmptyHint(symbol: "checkmark.shield.fill", title: "All clear", message: "No active risks. Tap Review Flags to re-scan resolved items.")
            } else {
                ForEach(flags) { flag in
                    CoopCard(accent: flag.severity.color) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(flag.severity.color.opacity(0.18)).frame(width: 40, height: 40)
                                Image(systemName: flag.symbol).foregroundColor(flag.severity.color)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(flag.title).font(.system(size: 15, weight: .bold)).foregroundColor(Palette.primaryText(scheme))
                                Text(flag.detail).font(.system(size: 12)).foregroundColor(Palette.secondaryText(scheme))
                            }
                            Spacer()
                            Button {
                                withAnimation { store.resolveFlag(flag) }
                                toastMessage = "Resolved"
                            } label: {
                                Text("Resolve").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(Capsule().fill(Palette.sage))
                            }
                        }
                    }
                }
            }
        }
        .toast($toastMessage)
    }
}

// MARK: - Screen 11: Daily Review

struct DailyReviewView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) private var scheme
    @State private var showQuickAdd = false
    @State private var toastMessage: String?
    @State private var refresh = false

    var body: some View {
        let progress = store.todayChecklistProgress()
        let out = store.activeRoamSessions()
        let overdue = store.overdueTasks()
        return ScreenScaffold(icon: "moon.stars.fill", title: "End of Day Review",
                              subtitle: "Reconcile today before you save it") {

            CoopCard(accent: Palette.sky) {
                HStack(spacing: 16) {
                    RingProgress(progress: Double(progress.done) / Double(Swift.max(progress.total, 1)),
                                 color: Palette.sky,
                                 centerLabel: "\(progress.done)/\(progress.total)")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today's checks").font(.system(size: 15, weight: .bold)).foregroundColor(Palette.primaryText(scheme))
                        Text(progress.done == progress.total ? "All checks closed 🎉" : "\(progress.total - progress.done) items still open")
                            .font(.system(size: 13)).foregroundColor(Palette.secondaryText(scheme))
                    }
                    Spacer()
                }
            }
            .id(refresh)

            CoopCard(accent: out.isEmpty ? Palette.sage : Palette.amber) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Still open", systemImage: "tray.full.fill")
                        .font(.system(size: 15, weight: .bold)).foregroundColor(Palette.primaryText(scheme))
                    reviewRow("Flocks still out", "\(out.count)", out.isEmpty)
                    reviewRow("Overdue tasks", "\(overdue.count)", overdue.isEmpty)
                    reviewRow("Low-stock items", "\(store.lowStockItems.count)", store.lowStockItems.isEmpty)
                    reviewRow("Cleanings overdue", "\(store.overdueCleaning().count)", store.overdueCleaning().isEmpty)
                }
            }

            HStack(spacing: 12) {
                Button {
                    for item in Checklist.items(for: .evening) {
                        store.setChecked(true, date: Date(), period: .evening, item: item.id)
                    }
                    store.addEntry(CareEntry(date: Date(), kind: .note, groupId: nil, zoneId: nil, detail: "Day reviewed & closed"))
                    refresh.toggle()
                    toastMessage = "Day completed"
                } label: { Label("Complete Day", systemImage: "checkmark.seal.fill") }
                .buttonStyle(PrimaryButtonStyle(color: Palette.sky))

                Button { showQuickAdd = true } label: { Label("Add Missing", systemImage: "plus.circle.fill") }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
        .sheet(isPresented: $showQuickAdd) { QuickAddView().environmentObject(store) }
        .toast($toastMessage)
    }

    private func reviewRow(_ title: String, _ value: String, _ ok: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(ok ? Palette.sage : Palette.amber)
            Text(title).font(.system(size: 14)).foregroundColor(Palette.primaryText(scheme))
            Spacer()
            Text(value).font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundColor(ok ? Palette.sage : Palette.amber)
        }
    }
}
