import SwiftUI
import UIKit

/// The approval screen: everything the scan found, with its frame. Swipe to remove, tap to fix.
struct ScanReviewView: View {
    let room: Room
    let frames: [ScanFrame]
    @Binding var items: [ScanItem]
    let onApprove: () -> Void
    let onRescan: () -> Void

    @State private var editing: ScanItem?
    @State private var thumbs: [Int: UIImage] = [:]

    private var total: Int { items.reduce(0) { $0 + $1.value * max(1, $1.quantity) } }
    private var lowCount: Int { items.filter { $0.confidence == "low" }.count }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Money.string(Double(total)))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("\(items.count) items found in \(frames.count) frames")
                        .foregroundStyle(.secondary)
                    if lowCount > 0 {
                        Text("\(lowCount) marked Check: the scan wasn't sure. Tap to fix or swipe to remove.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                ForEach(items) { item in
                    Button {
                        editing = item
                    } label: {
                        row(item)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    items.remove(atOffsets: offsets)
                }
            } header: {
                Text("Swipe left to remove · tap to edit")
                    .textCase(nil)
            }
        }
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button(action: onApprove) {
                    Label(items.count == 1 ? "Approve 1 item" : "Approve \(items.count) items",
                          systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.rpRecordDeep)
                .controlSize(.large)
                .disabled(items.isEmpty)

                Button("Scan again", action: onRescan)
                    .font(.footnote)
            }
            .padding()
            .background(.bar)
        }
        .sheet(item: $editing) { item in
            ScanItemEditor(item: item) { updated in
                if let i = items.firstIndex(where: { $0.id == updated.id }) { items[i] = updated }
            }
        }
        .task { await makeThumbs() }
    }

    private func row(_ item: ScanItem) -> some View {
        HStack(spacing: 14) {
            Group {
                if let image = thumbs[item.frame] {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    ZStack {
                        Color(UIColor.tertiarySystemFill)
                        Image(systemName: "photo").foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.name).font(.headline).lineLimit(1)
                    if item.confidence == "low" { Pill(text: "Check", color: .orange) }
                }
                let detail = [item.brand, item.model].filter { !$0.isEmpty }.joined(separator: " ")
                if !detail.isEmpty {
                    Text(detail).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                if !item.serial.isEmpty {
                    Text("Serial \(item.serial)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                if item.quantity > 1 {
                    Text("× \(item.quantity)").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Text(Money.string(Double(item.value * max(1, item.quantity))))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func makeThumbs() async {
        let needed = Set(items.map(\.frame))
        var out: [Int: UIImage] = [:]
        for index in needed where frames.indices.contains(index) {
            autoreleasepool {
                out[index] = frames[index].image?.resized(maxSide: 200)
            }
        }
        thumbs = out
    }
}

/// Small editor for one scanned item before it's saved.
struct ScanItemEditor: View {
    @State var item: ScanItem
    let onSave: (ScanItem) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name", text: $item.name)
                    TextField("Brand", text: $item.brand)
                    TextField("Model", text: $item.model)
                    TextField("Serial number", text: $item.serial)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
                Section("Value") {
                    HStack {
                        Text("Replacement value, each")
                        Spacer()
                        TextField("0", value: $item.value, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 110)
                    }
                    Stepper("Quantity: \(item.quantity)", value: $item.quantity, in: 1...500)
                }
                if !item.notes.isEmpty {
                    Section("Scan notes") {
                        Text(item.notes).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Edit item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if item.confidence == "low" { item.confidence = "medium" }
                        onSave(item)
                        dismiss()
                    }
                    .disabled(item.name.trimmed.isEmpty)
                }
            }
        }
    }
}
