import SwiftUI
import SwiftData

/// One home: the total, then a grid of rooms.
struct HomeDetailView: View {
    @Bindable var home: Home
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showAddRoom = false
    @State private var showExport = false
    @State private var showEdit = false
    @State private var showReview = false
    @State private var confirmDelete = false

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SummaryCard(home: home, onReview: { showReview = true })

                Text("Rooms")
                    .font(.title3.bold())
                    .padding(.top, 4)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(home.sortedRooms) { room in
                        NavigationLink(value: room) {
                            RoomTile(room: room)
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        showAddRoom = true
                    } label: {
                        AddRoomTile()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(Color.rpGround)
        .navigationTitle(home.name)
        .navigationBarTitleDisplayMode(.inline)
        // A labeled button for the app's whole point. The toolbar share icon stays,
        // but not everyone reads that symbol as "get my record out".
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button {
                    showExport = true
                } label: {
                    Label("Save or share the record (PDF)", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(home.itemCount == 0)

                Text("Everything is saved automatically as you go.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .background(.bar)
        }
        .navigationDestination(for: Room.self) { room in
            RoomDetailView(room: room)
        }
        .navigationDestination(isPresented: $showReview) {
            ReviewView(home: home)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showExport = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Export")
                Menu {
                    Button("Edit home", systemImage: "pencil") { showEdit = true }
                    Button("Delete home", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More")
            }
        }
        .sheet(isPresented: $showAddRoom) { AddRoomSheet(home: home) }
        .sheet(isPresented: $showExport) { ExportView(home: home) }
        .sheet(isPresented: $showEdit) { EditHomeSheet(home: home) }
        .confirmationDialog("Delete \(home.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete home and everything in it", role: .destructive) {
                let doomed = home
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    context.delete(doomed)
                }
            }
        } message: {
            Text("This removes every room, item and photo for this home. It can't be undone.")
        }
    }
}

struct SummaryCard: View {
    let home: Home
    var onReview: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Estimated replacement value")
                    .font(.subheadline.weight(.medium))
                    .opacity(0.75)
                Text(Money.string(home.totalValue))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            HStack(spacing: 10) {
                Text("\(home.itemCount) items")
                Text("·")
                Text("\(home.rooms.count) rooms")
                Spacer()
                if home.itemCount > 0 && home.needsReviewCount == 0 {
                    Pill(text: "All proven", color: .green)
                }
            }
            .font(.subheadline)
            if home.needsReviewCount > 0 {
                // One tap to see every item that still needs a value or proof.
                Button(action: { onReview?() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                        Text(home.needsReviewCount == 1
                             ? "1 item needs a value or proof"
                             : "\(home.needsReviewCount) items need a value or proof")
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 6)
                        Text("Review")
                            .font(.subheadline.weight(.bold))
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(Color.rpVellum)
                    .padding(.vertical, 11)
                    .padding(.horizontal, 12)
                    .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if home.itemCount == 0 {
                Text("Open a room and tap Scan room to start.")
                    .font(.footnote)
                    .opacity(0.8)
            }
        }
        .foregroundStyle(Color.rpVellum)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.rpNavy, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct RoomTile: View {
    let room: Room

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: room.symbol)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(room.name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(room.itemCount == 1 ? "1 item" : "\(room.itemCount) items")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(Money.string(room.totalValue))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .card()
        .contentShape(Rectangle())
    }
}

struct AddRoomTile: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
            Text("Add room")
                .font(.headline)
        }
        .foregroundStyle(Color.accentColor)
        .frame(maxWidth: .infinity, minHeight: 132)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
        )
        .contentShape(Rectangle())
    }
}

struct AddRoomSheet: View {
    let home: Home
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var customName = ""

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 10)]

    private var available: [RoomPreset] {
        let used = Set(home.rooms.map { $0.name })
        return RoomPreset.all.filter { !used.contains($0.name) }
    }

    var body: some View {
        NavigationStack {
            Form {
                if !available.isEmpty {
                    Section("Common rooms") {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(available) { preset in
                                RoomChip(preset: preset, isOn: false) {
                                    add(name: preset.name, symbol: preset.symbol)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                Section("Or name your own") {
                    HStack {
                        TextField("e.g. Guest room", text: $customName)
                            .submitLabel(.done)
                            .onSubmit(addCustom)
                        Button("Add", action: addCustom)
                            .disabled(customName.trimmed.isEmpty)
                    }
                }
            }
            .navigationTitle("Add a room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func addCustom() {
        guard !customName.trimmed.isEmpty else { return }
        add(name: customName.trimmed, symbol: RoomPreset.customSymbol)
    }

    private func add(name: String, symbol: String) {
        let nextOrder = (home.rooms.map { $0.order }.max() ?? -1) + 1
        let room = Room(name: name, symbol: symbol, order: nextOrder)
        context.insert(room)
        room.home = home
        Haptics.tap()
        dismiss()
    }
}

// MARK: - Needs review

/// Every item across the home that still needs a value or proof. Tap one, fix it, it drops off.
struct ReviewView: View {
    @Bindable var home: Home
    @State private var editing: Item?

    /// No name or no value: these count for $0 on a claim.
    private var needDetails: [Item] {
        home.allItems.filter { $0.needsDetails }.sorted { $0.createdAt > $1.createdAt }
    }
    /// Named and valued, but no serial number or receipt. Most valuable first.
    private var needProof: [Item] {
        home.allItems.filter { !$0.hasProof && !$0.needsDetails }.sorted { $0.totalValue > $1.totalValue }
    }

    var body: some View {
        List {
            if needDetails.isEmpty && needProof.isEmpty {
                ContentUnavailableView {
                    Label("All set", systemImage: "checkmark.seal.fill")
                } description: {
                    Text("Every item has a name, a value, and proof.")
                }
            }
            if !needDetails.isEmpty {
                Section {
                    ForEach(needDetails) { item in reviewRow(item) }
                } header: {
                    Text("Missing a name or value")
                        .textCase(nil)
                } footer: {
                    Text("A claim pays on the value, so these count for $0 until they're filled in. Tap one to fix it.")
                }
            }
            if !needProof.isEmpty {
                Section {
                    ForEach(needProof) { item in reviewRow(item) }
                } header: {
                    Text("Missing proof")
                        .textCase(nil)
                } footer: {
                    Text("Proof is a serial number or a receipt photo — either one. Tap an item to add it. Start at the top: the most expensive things are listed first.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.rpGround)
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { item in
            if let room = item.room {
                ItemEditorView(room: room, item: item)
            }
        }
    }

    private func reviewRow(_ item: Item) -> some View {
        Button {
            editing = item
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                ItemRow(item: item)
                if let room = item.room {
                    Text("in \(room.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
