import SwiftUI
import SwiftData
import UIKit

/// One room: its items, plus Snap and Add buttons.
struct RoomDetailView: View {
    @Bindable var room: Room
    @Environment(\.modelContext) private var context
    @Environment(ProStore.self) private var store
    @Environment(ScanStore.self) private var scans
    @Environment(\.dismiss) private var dismiss

    @State private var editingItem: Item?
    @State private var addingItem = false
    @State private var snapping = false
    @State private var scanning = false
    @State private var showScanCredits = false
    @State private var showPaywall = false
    @State private var renaming = false
    @State private var newName = ""
    @State private var confirmDelete = false

    var body: some View {
        Group {
            if room.items.isEmpty {
                emptyState
            } else {
                itemList
            }
        }
        .background(Color.rpGround)
        .navigationTitle(room.name)
        .safeAreaInset(edge: .bottom) { actionBar }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Rename room", systemImage: "pencil") {
                        newName = room.name
                        renaming = true
                    }
                    Button("Delete room", systemImage: "trash", role: .destructive) {
                        confirmDelete = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More")
            }
        }
        .sheet(item: $editingItem) { item in
            ItemEditorView(room: room, item: item)
        }
        .sheet(isPresented: $addingItem) {
            ItemEditorView(room: room, item: nil)
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showScanCredits) { ScanCreditsView() }
        .fullScreenCover(isPresented: $scanning) { ScanView(room: room) }
        .fullScreenCover(isPresented: $snapping) {
            CaptureView(title: room.name, mode: .multi) { image in
                addSnap(image)
            }
        }
        .alert("Rename room", isPresented: $renaming) {
            TextField("Room name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if !newName.trimmed.isEmpty { room.name = newName.trimmed }
            }
        }
        .confirmationDialog("Delete \(room.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete room and its items", role: .destructive) {
                let doomed = room
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    context.delete(doomed)
                }
            }
        } message: {
            Text("This removes \(room.items.count) items and their photos. It can't be undone.")
        }
    }

    // MARK: Pieces

    private var itemList: some View {
        List {
            Section {
                ForEach(room.sortedItems) { item in
                    Button {
                        editingItem = item
                    } label: {
                        ItemRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    let items = room.sortedItems
                    for index in offsets {
                        context.delete(items[index])
                    }
                }
            } header: {
                HStack {
                    Text(room.itemCount == 1 ? "1 item" : "\(room.itemCount) items")
                    Spacer()
                    Text(Money.string(room.totalValue))
                        .monospacedDigit()
                }
                .font(.subheadline.weight(.semibold))
                .textCase(nil)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: room.symbol)
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 96, height: 96)
                .background(Color.accentColor.opacity(0.12), in: Circle())
            Text("Nothing in \(room.name) yet")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            Text("Tap Scan room, film a slow walkthrough, and approve the list it finds. Snap and Add are there for one-offs.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var actionBar: some View {
        VStack(spacing: 10) {
            Button(action: startScan) {
                Label("Scan room", systemImage: "video.badge.waveform.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.rpRecordDeep)

            HStack(spacing: 12) {
                Button(action: startSnap) {
                    Label("Snap", systemImage: "camera.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: startAdd) {
                    Label("Add", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .controlSize(.large)
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(.bar)
    }

    // MARK: Actions

    private var canAddItem: Bool {
        if store.isPro { return true }
        let count = (try? context.fetchCount(FetchDescriptor<Item>())) ?? 0
        return count < AppConfig.freeItemLimit
    }

    private func startScan() {
        if scans.canScan { scanning = true } else { showScanCredits = true }
    }

    private func startSnap() {
        if canAddItem { snapping = true } else { showPaywall = true }
    }

    private func startAdd() {
        if canAddItem { addingItem = true } else { showPaywall = true }
    }

    /// Saves one snapped photo as a new item. Returns false to stop the camera.
    private func addSnap(_ image: UIImage) -> Bool {
        guard canAddItem else {
            snapping = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showPaywall = true }
            return false
        }
        guard let pair = image.storagePair() else { return true }
        let item = Item()
        context.insert(item)
        item.room = room
        let photo = ItemPhoto(data: pair.data, thumb: pair.thumb, kind: .item)
        context.insert(photo)
        photo.item = item
        return true
    }
}

struct ItemRow: View {
    let item: Item

    var body: some View {
        HStack(spacing: 14) {
            Thumb(data: item.coverThumb, size: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayName)
                    .font(.headline)
                    .foregroundStyle(item.name.trimmed.isEmpty ? Color.secondary : Color.primary)
                    .lineLimit(1)
                if item.needsDetails {
                    Text("Add details")
                        .font(.subheadline)
                        .foregroundStyle(Color.orange)
                } else if !item.detailLine.isEmpty {
                    Text(item.detailLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text(Money.string(item.totalValue))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                if item.hasProof {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel("Has proof")
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
