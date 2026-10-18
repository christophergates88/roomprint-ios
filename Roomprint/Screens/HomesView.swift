import SwiftUI
import SwiftData
import UIKit

/// First screen: your homes.
struct HomesView: View {
    @Environment(ProStore.self) private var store
    @Query(sort: \Home.createdAt) private var homes: [Home]
    @State private var showNewHome = false
    @State private var showPaywall = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if homes.isEmpty {
                        emptyState
                    } else {
                        ForEach(homes) { home in
                            NavigationLink(value: home) {
                                HomeCard(home: home)
                            }
                            .buttonStyle(.plain)
                        }
                        Button(action: addHome) {
                            Label("Add another home", systemImage: "plus")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
            .background(Color.rpGround)
            .navigationTitle("Roomprint")
            .navigationDestination(for: Home.self) { home in
                HomeDetailView(home: home)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showNewHome) { NewHomeSheet() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            LogoMark(size: 80)
                .padding(.top, 40)
            Text("Let's record your home")
                .font(.title2.bold())
            Text("Start with your house, then add rooms and snap what's in them.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button {
                showNewHome = true
            } label: {
                Label("Add your home", systemImage: "house.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 8)
        }
        .padding()
    }

    private func addHome() {
        if !store.isPro && homes.count >= AppConfig.freeHomeLimit {
            showPaywall = true
        } else {
            showNewHome = true
        }
    }
}

struct HomeCard: View {
    let home: Home

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(home.name)
                        .font(.title2.bold())
                    if !home.address.trimmed.isEmpty {
                        Text(home.address)
                            .font(.subheadline)
                            .opacity(0.75)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .opacity(0.6)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(Money.string(home.totalValue))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("\(home.itemCount) items · \(home.rooms.count) rooms")
                    .font(.subheadline)
                    .opacity(0.75)
            }
        }
        .foregroundStyle(Color.rpVellum)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.rpNavy, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contentShape(Rectangle())
    }
}

/// Create a home and pick its starting rooms.
struct NewHomeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var name = ""
    @State private var address = ""
    @State private var selected: Set<String> = Set(RoomPreset.starter)

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 10)]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, like Our house", text: $name)
                    TextField("Address (optional)", text: $address)
                        .textContentType(.fullStreetAddress)
                }
                Section {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(RoomPreset.all) { preset in
                            RoomChip(preset: preset, isOn: selected.contains(preset.name)) {
                                if selected.contains(preset.name) {
                                    selected.remove(preset.name)
                                } else {
                                    selected.insert(preset.name)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Start with these rooms")
                } footer: {
                    Text("You can add or remove rooms any time.")
                }
            }
            .navigationTitle("New home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func create() {
        let home = Home(name: name.trimmed.isEmpty ? "My home" : name.trimmed, address: address.trimmed)
        context.insert(home)
        var order = 0
        for preset in RoomPreset.all where selected.contains(preset.name) {
            let room = Room(name: preset.name, symbol: preset.symbol, order: order)
            context.insert(room)
            room.home = home
            order += 1
        }
        Haptics.success()
        dismiss()
    }
}

struct RoomChip: View {
    let preset: RoomPreset
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: preset.symbol)
                    .frame(width: 22)
                Text(preset.name)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                }
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .foregroundStyle(isOn ? Color.white : Color.primary)
            .background(isOn ? Color.accentColor : Color(UIColor.tertiarySystemFill),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

struct EditHomeSheet: View {
    @Bindable var home: Home
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $home.name)
                TextField("Address", text: $home.address)
            }
            .navigationTitle("Edit home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if home.name.trimmed.isEmpty { home.name = "My home" }
                        dismiss()
                    }
                }
            }
        }
    }
}
