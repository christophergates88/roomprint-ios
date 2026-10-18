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
    @State private var confirmDelete = false

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SummaryCard(home: home)

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
        .navigationDestination(for: Room.self) { room in
            RoomDetailView(room: room)
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
                if home.needsProofCount > 0 {
                    Pill(text: "\(home.needsProofCount) need proof", color: .rpRecordDeep)
                } else if home.itemCount > 0 {
                    Pill(text: "All proven", color: .green)
                }
            }
            .font(.subheadline)
            if home.itemCount == 0 {
                Text("Open a room and tap Snap items to start.")
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
