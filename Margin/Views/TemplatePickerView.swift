import SwiftUI

struct TemplatePickerView: View {
    let onSelect: (PageTemplate) -> Void

    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(PageTemplate.all) { template in
                        Button {
                            onSelect(template)
                            dismiss()
                        } label: {
                            TemplateCard(template: template)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("New Page")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct TemplateCard: View {
    let template: PageTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: template.systemImage)
                .font(.title)
                .foregroundStyle(.tint)
            Text(template.name)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(template.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding()
        .frame(height: 140, alignment: .topLeading)
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }
}
