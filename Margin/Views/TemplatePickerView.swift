import SwiftUI

struct TemplatePickerView: View {
    let onSelect: (PageTemplate) -> Void

    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 200), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("New Page")
                            .font(.editorialDisplay(32))
                            .foregroundStyle(Theme.text)
                        AccentRule()
                        Text("Start from a template")
                            .metaLabel()
                    }
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
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
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
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: template.systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 44, height: 44)
                .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(template.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text(template.description)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }
            Spacer(minLength: 0)
        }
        .frame(height: 168, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .editorialCard()
    }
}
