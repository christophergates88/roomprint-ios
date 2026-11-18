import SwiftUI

/// Compares what's recorded with the contents coverage on the owner's policy, and points out
/// belongings that policies commonly cap. Facts and questions for their agent, never advice.
struct CoverageView: View {
    @Bindable var home: Home
    @Environment(\.dismiss) private var dismiss
    @State private var limitText = ""
    @FocusState private var editingLimit: Bool

    private var total: Double { home.totalValue }
    private var limit: Double { home.coverageLimit }
    private var capped: [SpecialLimitTotal] { home.specialLimitTotals }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    verdict
                    limitEntry
                    if !capped.isEmpty { cappedSection }
                    agentSection
                    Text("Roomprint compares numbers you entered. It isn't insurance advice and can't see your policy. Your policy and your agent decide what's covered.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .background(Color.rpGround)
            .navigationTitle("Coverage check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { commitLimit(); dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { editingLimit = false }
                }
            }
            .onAppear {
                if limit > 0 { limitText = String(Int(limit)) }
            }
            .onChange(of: editingLimit) { _, focused in
                if !focused { commitLimit() }
            }
        }
    }

    // MARK: Pieces

    private var verdict: some View {
        VStack(alignment: .leading, spacing: 14) {
            if limit <= 0 {
                Text("You've recorded")
                    .font(.subheadline.weight(.medium)).opacity(0.75)
                Text(Money.string(total))
                    .font(.system(size: 40, weight: .bold, design: .rounded)).monospacedDigit()
                Text("Is your policy enough to replace it? Enter your contents coverage below to find out.")
                    .font(.subheadline).opacity(0.85)
            } else {
                let gap = total - limit
                Text(gap > 0 ? "Recorded above your coverage" : "Room left in your coverage")
                    .font(.subheadline.weight(.medium)).opacity(0.75)
                Text(Money.string(abs(gap)))
                    .font(.system(size: 40, weight: .bold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(gap > 0 ? Color.rpRecord : Color.rpVellum)
                CoverageBar(total: total, limit: limit)
                HStack {
                    label("Recorded", Money.string(total))
                    Spacer()
                    label("Your coverage", Money.string(limit), trailing: true)
                }
                if gap > 0 {
                    Text("If everything were lost, your policy's contents limit would fall \(Money.string(gap)) short of what you've recorded.")
                        .font(.subheadline).opacity(0.9)
                }
                if home.emptyRoomCount > 0 {
                    Text(home.emptyRoomCount == 1
                         ? "1 room isn't recorded yet, so the real total is higher."
                         : "\(home.emptyRoomCount) rooms aren't recorded yet, so the real total is higher.")
                        .font(.footnote).opacity(0.8)
                }
            }
        }
        .foregroundStyle(Color.rpVellum)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.rpNavy, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func label(_ title: String, _ value: String, trailing: Bool = false) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 2) {
            Text(title).font(.caption).opacity(0.7)
            Text(value).font(.headline).monospacedDigit()
        }
    }

    private var limitEntry: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your contents coverage")
                .font(.headline)
            HStack(spacing: 6) {
                Text(Locale.current.currencySymbol ?? "$")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("e.g. 75000", text: $limitText)
                    .keyboardType(.numberPad)
                    .font(.title3.weight(.semibold))
                    .focused($editingLimit)
            }
            .padding(12)
            .background(Color(UIColor.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text("It's on your policy's declarations page as Personal Property or Coverage C. Renters: it's your main coverage amount.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .card()
    }

    private var cappedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Often capped by policies")
                .font(.headline)
            Text("Many policies pay only up to a small set amount for these unless they're listed separately. Check yours.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            ForEach(capped) { entry in
                HStack(spacing: 12) {
                    Image(systemName: entry.limit.symbol)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 36, height: 36)
                        .background(Color.accentColor.opacity(0.12), in: Circle())
                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.limit.title).font(.subheadline.weight(.semibold))
                        Text(entry.count == 1 ? "1 entry" : "\(entry.count) entries")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(Money.string(entry.value))
                        .font(.subheadline.weight(.semibold)).monospacedDigit()
                }
            }
        }
        .card()
    }

    private var agentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ask your agent")
                .font(.headline)
            Text("Send your numbers to your insurance agent and ask for a review. It takes them a few minutes.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            ShareLink(item: agentNote) {
                Label("Send a note to my agent", systemImage: "paperplane.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(total <= 0)
        }
        .card()
    }

    /// A short message the owner can text or email to their agent.
    var agentNote: String {
        var lines = ["Hi, I just finished a home inventory. Could you review my coverage with me?", ""]
        lines.append("Contents recorded so far: about \(Money.string(total)) (\(home.itemCount) items, replacement cost).")
        if limit > 0 {
            lines.append("Personal property coverage on my policy: \(Money.string(limit)).")
            if total > limit { lines.append("That's about \(Money.string(total - limit)) more than my coverage.") }
        }
        if !capped.isEmpty {
            lines.append("")
            lines.append("Things I'd like to ask about listing separately:")
            for entry in capped { lines.append("- \(entry.limit.title): about \(Money.string(entry.value))") }
        }
        lines.append("")
        lines.append("I can send the full itemized record as a PDF. Thank you!")
        return lines.joined(separator: "\n")
    }

    private func commitLimit() {
        let digits = limitText.filter { $0.isNumber }
        home.coverageLimit = Double(digits) ?? 0
    }
}

/// Recorded value against the coverage limit: one bar, the limit marked.
struct CoverageBar: View {
    let total: Double
    let limit: Double

    var body: some View {
        GeometryReader { proxy in
            let scale = max(total, limit, 1)
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.16))
                Capsule()
                    .fill(total > limit ? Color.rpRecord : Color.green)
                    .frame(width: max(8, width * total / scale))
                Rectangle()
                    .fill(Color.rpVellum)
                    .frame(width: 3, height: 22)
                    .offset(x: min(width - 3, width * limit / scale))
            }
        }
        .frame(height: 14)
        .padding(.vertical, 4)
        .accessibilityLabel("Recorded \(Money.string(total)) against coverage of \(Money.string(limit))")
    }
}

/// The card on the home screen that opens the coverage check.
struct CoverageCard: View {
    let home: Home

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: home.coverageGap > 0 ? "exclamationmark.shield.fill" : "checkmark.shield.fill")
                .font(.title3)
                .foregroundStyle(home.coverageGap > 0 ? Color.rpRecordDeep : Color.accentColor)
                .frame(width: 40, height: 40)
                .background((home.coverageGap > 0 ? Color.rpRecordDeep : Color.accentColor).opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).multilineTextAlignment(.leading)
                Text(detail).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.leading)
            }
            Spacer(minLength: 6)
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
        }
        .card()
        .contentShape(Rectangle())
    }

    private var title: String {
        if home.coverageLimit <= 0 { return "Are you covered for \(Money.string(home.totalValue))?" }
        if home.coverageGap > 0 { return "\(Money.string(home.coverageGap)) above your coverage" }
        return "Within your coverage"
    }

    private var detail: String {
        if home.coverageLimit <= 0 { return "Compare your record with your policy in 10 seconds." }
        let capped = home.specialLimitTotals.count
        if home.coverageGap > 0 { return "Your record is bigger than your policy's contents limit. See the details." }
        return capped > 0 ? "\(capped) kinds of items may have their own caps. See which." : "Your contents limit is above what you've recorded."
    }
}
