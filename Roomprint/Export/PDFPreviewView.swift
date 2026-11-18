import SwiftUI
import PDFKit
import UIKit

/// Shows the finished record before it's shared, with a Share button.
struct PDFPreviewView: View {
    let url: URL
    let title: String
    var password: String? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PDFKitView(url: url, password: password)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: url) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                }
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let url: URL
    var password: String? = nil

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.pageShadowsEnabled = true
        view.backgroundColor = UIColor.secondarySystemBackground
        if let document = PDFDocument(url: url) {
            if document.isLocked, let password { document.unlock(withPassword: password) }
            view.document = document
        }
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {}
}
