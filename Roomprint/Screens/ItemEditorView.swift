import SwiftUI
import SwiftData
import PhotosUI
import UIKit

/// Add or edit one item. Changes are kept in a draft until Save.
struct ItemEditorView: View {
    let room: Room
    let item: Item?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var unitValue: Double = 0
    @State private var quantity = 1
    @State private var brand = ""
    @State private var modelNumber = ""
    @State private var serial = ""
    @State private var purchasePrice: Double?
    @State private var knowsPurchaseDate = false
    @State private var purchaseDate = Date()
    @State private var hasReceipt = false
    @State private var notes = ""
    @State private var photos: [DraftPhoto] = []

    @State private var showDetails = false
    @State private var cameraKind: PhotoKind?
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showScanner = false
    @State private var confirmDelete = false
    @State private var loaded = false

    struct DraftPhoto: Identifiable {
        let id = UUID()
        let data: Data
        let thumb: Data
        let kind: PhotoKind
        let existing: ItemPhoto?
    }

    var body: some View {
        NavigationStack {
            Form {
                photoSection

                Section {
                    TextField("What is it?", text: $name)
                        .font(.title3)
                        .textInputAutocapitalization(.sentences)
                }

                Section {
                    HStack {
                        Text("Replacement value")
                        Spacer()
                        TextField("$0", value: $unitValue, format: .currency(code: Money.code))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 140)
                    }
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...999)
                } footer: {
                    Text("What it would cost to buy a similar new one today.")
                }

                Section {
                    DisclosureGroup("More details", isExpanded: $showDetails) {
                        detailFields
                    }
                }

                if item != nil {
                    Section {
                        Button("Delete item", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(item == nil ? "New item" : "Edit item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hideKeyboard() }
                }
            }
            .onAppear(perform: load)
            .onChange(of: pickerItems) { _, newItems in
                importPicked(newItems)
            }
            .fullScreenCover(item: $cameraKind) { kind in
                CaptureView(title: kind.title, mode: .single) { image in
                    addDraft(image, kind: kind)
                    return false
                }
            }
            .sheet(isPresented: $showScanner) {
                LabelScanView { field, text in
                    switch field {
                    case .name: name = text
                    case .brand: brand = text
                    case .model: modelNumber = text
                    case .serial: serial = text
                    }
                    showDetails = true
                } onLabelPhoto: { image in
                    addDraft(image, kind: .label)
                }
            }
            .confirmationDialog("Delete this item?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete item", role: .destructive) {
                    let doomed = item
                    let ctx = context
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        if let doomed { ctx.delete(doomed) }
                    }
                }
            }
        }
    }

    // MARK: Sections

    private var photoSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(photos) { photo in
                        ZStack(alignment: .topTrailing) {
                            Thumb(data: photo.thumb, size: 84)
                            Button {
                                photos.removeAll { $0.id == photo.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(Color.white, Color.black.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                            .padding(4)
                            .accessibilityLabel("Remove photo")
                            if photo.kind != .item {
                                Text(photo.kind.title)
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.6), in: Capsule())
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                                    .padding(6)
                            }
                        }
                        .frame(width: 84, height: 84)
                    }

                    Button {
                        cameraKind = .item
                    } label: {
                        AddPhotoTile(symbol: "camera.fill", title: "Camera")
                    }
                    .buttonStyle(.plain)

                    PhotosPicker(selection: $pickerItems, maxSelectionCount: 6, matching: .images) {
                        AddPhotoTile(symbol: "photo.on.rectangle", title: "Library")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private var detailFields: some View {
        Button {
            showScanner = true
        } label: {
            Label("Scan a label for model or serial", systemImage: "text.viewfinder")
        }
        TextField("Brand", text: $brand)
        TextField("Model", text: $modelNumber)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
        TextField("Serial number", text: $serial)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
        HStack {
            Text("What you paid")
            Spacer()
            TextField("Optional", value: $purchasePrice, format: .currency(code: Money.code))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 140)
        }
        Toggle("I know when I bought it", isOn: $knowsPurchaseDate)
        if knowsPurchaseDate {
            DatePicker("Purchased", selection: $purchaseDate, in: ...Date(), displayedComponents: .date)
        }
        Toggle("I have a receipt or appraisal", isOn: $hasReceipt)
        if hasReceipt {
            Button {
                cameraKind = .receipt
            } label: {
                Label("Photograph the receipt", systemImage: "doc.text.viewfinder")
            }
        }
        TextField("Notes", text: $notes, axis: .vertical)
            .lineLimit(2...5)
    }

    // MARK: Data

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let item else { return }
        name = item.name
        unitValue = item.unitValue
        quantity = max(1, item.quantity)
        brand = item.brand
        modelNumber = item.modelNumber
        serial = item.serial
        purchasePrice = item.purchasePrice
        if let date = item.purchaseDate {
            knowsPurchaseDate = true
            purchaseDate = date
        }
        hasReceipt = item.hasReceipt
        notes = item.notes
        photos = item.sortedPhotos.map {
            DraftPhoto(data: $0.data, thumb: $0.thumb, kind: PhotoKind(rawValue: $0.kind) ?? .item, existing: $0)
        }
        showDetails = !item.detailLine.isEmpty || !item.serial.isEmpty || item.purchasePrice != nil
            || item.hasReceipt || !item.notes.isEmpty
    }

    private func addDraft(_ image: UIImage, kind: PhotoKind) {
        guard let pair = image.storagePair() else { return }
        photos.append(DraftPhoto(data: pair.data, thumb: pair.thumb, kind: kind, existing: nil))
    }

    private func importPicked(_ picked: [PhotosPickerItem]) {
        guard !picked.isEmpty else { return }
        Task {
            for entry in picked {
                if let data = try? await entry.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    addDraft(image, kind: .item)
                }
            }
            pickerItems = []
        }
    }

    private func save() {
        let target: Item
        if let item {
            target = item
        } else {
            target = Item()
            context.insert(target)
            target.room = room
        }
        target.name = name.trimmed
        target.unitValue = max(0, unitValue)
        target.quantity = max(1, quantity)
        target.brand = brand.trimmed
        target.modelNumber = modelNumber.trimmed
        target.serial = serial.trimmed
        target.purchasePrice = purchasePrice
        target.purchaseDate = knowsPurchaseDate ? purchaseDate : nil
        target.hasReceipt = hasReceipt
        target.notes = notes.trimmed

        let kept = Set(photos.compactMap { $0.existing?.persistentModelID })
        for old in Array(target.photos) where !kept.contains(old.persistentModelID) {
            context.delete(old)
        }
        for draft in photos where draft.existing == nil {
            let photo = ItemPhoto(data: draft.data, thumb: draft.thumb, kind: draft.kind)
            context.insert(photo)
            photo.item = target
        }
        Haptics.success()
        dismiss()
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension PhotoKind: Identifiable {
    var id: String { rawValue }
}

struct AddPhotoTile: View {
    let symbol: String
    let title: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.title3)
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(Color.accentColor)
        .frame(width: 84, height: 84)
        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
