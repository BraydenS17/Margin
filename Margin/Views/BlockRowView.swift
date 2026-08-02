import SwiftUI
import SwiftData
import PhotosUI

struct BlockRowView: View {
    @Bindable var block: Block
    var numberedListIndex: Int = 1
    var focus: FocusState<UUID?>.Binding
    var onDelete: () -> Void
    var onDuplicate: () -> Void = {}
    /// Called when the user presses return inside a textual block: `head` stays in
    /// this block, `tail` belongs in the next one.
    var onSplit: (String, String) -> Void = { _, _ in }
    var onOpenPage: ((Page) -> Void)? = nil

    @State private var showingFlashcardSheet = false

    private static let maxIndent = 4
    private static let indentStep: CGFloat = 24

    var body: some View {
        content
            .padding(.leading, CGFloat(min(block.indentLevel, Self.maxIndent)) * Self.indentStep)
            .onChange(of: block.textContent) { _, newValue in
                guard block.type.isTextual, let split = BlockOutline.splitOnReturn(newValue) else { return }
                onSplit(split.head, split.tail)
            }
            .contextMenu {
                Menu("Turn Into", systemImage: "arrow.triangle.2.circlepath") {
                    ForEach(BlockType.allCases.filter { $0 != block.type && $0 != .image && $0 != .pageLink }, id: \.self) { type in
                        Button {
                            block.type = type
                            block.updatedAt = Date()
                        } label: {
                            Label(type.displayName, systemImage: type.systemImage)
                        }
                    }
                }
                Button("Duplicate", systemImage: "plus.square.on.square", action: onDuplicate)
                if block.type.isTextual && !block.textContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button("Make Flashcard", systemImage: "rectangle.stack.badge.plus") {
                        showingFlashcardSheet = true
                    }
                }
                if block.indentLevel < Self.maxIndent {
                    Button("Indent", systemImage: "increase.indent") { block.indentLevel += 1 }
                }
                if block.indentLevel > 0 {
                    Button("Outdent", systemImage: "decrease.indent") { block.indentLevel -= 1 }
                }
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
            }
            .sheet(isPresented: $showingFlashcardSheet) {
                MakeFlashcardSheet(frontText: RichText.plainText(from: block.textContent))
            }
    }

    @ViewBuilder
    private var content: some View {
        switch block.type {
        case .heading:
            FormattableText(block: block, placeholder: "Heading", font: .title2.bold(), focus: focus)
                .padding(.vertical, 4)

        case .paragraph:
            FormattableText(block: block, placeholder: "Type “/” for blocks…", font: .body, focus: focus)
                .padding(.vertical, 4)

        case .bulletList:
            HStack(alignment: .top, spacing: 10) {
                Text("•")
                    .font(.body)
                    .foregroundStyle(.secondary)
                FormattableText(block: block, placeholder: "List item", font: .body, focus: focus)
            }
            .padding(.vertical, 4)

        case .numberedList:
            HStack(alignment: .top, spacing: 10) {
                Text("\(numberedListIndex).")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 18, alignment: .trailing)
                FormattableText(block: block, placeholder: "List item", font: .body, focus: focus)
            }
            .padding(.vertical, 4)

        case .checkbox:
            HStack(alignment: .top, spacing: 8) {
                Button {
                    block.isChecked.toggle()
                } label: {
                    Image(systemName: block.isChecked ? "checkmark.square.fill" : "square")
                        .font(.title3)
                        .foregroundStyle(block.isChecked ? Color.accentColor : Color.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                TextField("To-do", text: $block.textContent, axis: .vertical)
                    .font(.body)
                    .strikethrough(block.isChecked)
                    .foregroundStyle(block.isChecked ? .secondary : .primary)
                    .focused(focus, equals: block.id)
                    .padding(.top, 5)
            }

        case .divider:
            Divider()
                .padding(.vertical, 10)

        case .callout:
            HStack(alignment: .top, spacing: 10) {
                Text("💡")
                    .font(.body)
                FormattableText(block: block, placeholder: "Callout", font: .body, focus: focus)
            }
            .padding(12)
            .background(.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))

        case .quote:
            HStack(spacing: 10) {
                Rectangle()
                    .fill(.secondary)
                    .frame(width: 3)
                FormattableText(block: block, placeholder: "Quote", font: .body.italic(), focus: focus)
            }
            .padding(.vertical, 4)

        case .toggle:
            HStack(alignment: .top, spacing: 8) {
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        block.isCollapsed.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(block.isCollapsed ? 0 : 90))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(block.isCollapsed ? "Expand Toggle" : "Collapse Toggle")
                TextField("Toggle — indent blocks under me", text: $block.textContent, axis: .vertical)
                    .font(.body.weight(.semibold))
                    .focused(focus, equals: block.id)
                    .padding(.top, 4)
            }

        case .code:
            TextField("Code", text: $block.textContent, axis: .vertical)
                .font(.system(size: 14, design: .monospaced))
                .focused(focus, equals: block.id)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .padding(12)
                .background(Theme.text.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.border, lineWidth: 1))
                .padding(.vertical, 4)

        case .pageLink:
            PageLinkBlockView(block: block, onOpenPage: onOpenPage)
                .padding(.vertical, 4)

        case .image:
            ImageBlockView(block: block)
                .padding(.vertical, 4)

        case .table:
            TableBlockView(block: block)
                .padding(.vertical, 6)
        }
    }
}

/// A text field that renders **bold**/*italic*/etc. markers as real styling once the
/// block isn't focused, and drops back to raw-marker plain text while editing (SwiftUI
/// has no native live-formatting text editor, so this is the source/rendered toggle).
private struct FormattableText: View {
    @Bindable var block: Block
    var placeholder: String
    var font: Font
    var focus: FocusState<UUID?>.Binding

    var body: some View {
        if focus.wrappedValue == block.id || !RichText.hasFormatting(block.textContent) {
            TextField(placeholder, text: $block.textContent, axis: .vertical)
                .font(font)
                .focused(focus, equals: block.id)
        } else {
            Text(RichText.attributedString(from: block.textContent, baseFont: font))
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { focus.wrappedValue = block.id }
        }
    }
}

/// A photo living in the block flow: empty blocks show a dashed "Add a photo" target,
/// filled ones render the picture with swap/remove controls on long-press.
private struct ImageBlockView: View {
    @Bindable var block: Block

    @State private var pickerItem: PhotosPickerItem?
    @State private var showingPicker = false

    var body: some View {
        Group {
            #if os(iOS)
            if let data = block.imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 460)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Theme.border, lineWidth: 1)
                    )
                    .contextMenu {
                        Button("Replace Photo", systemImage: "photo.on.rectangle.angled") {
                            // Re-present the picker by clearing the item first.
                            pickerItem = nil
                            showingPicker = true
                        }
                        Button("Remove Photo", systemImage: "xmark.circle") {
                            block.imageData = nil
                            block.updatedAt = Date()
                        }
                    }
                    .onTapGesture { showingPicker = true }
                    .accessibilityLabel("Photo. Tap to replace.")
            } else {
                emptyTarget
            }
            #else
            emptyTarget
            #endif
        }
        .photosPicker(isPresented: $showingPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                block.imageData = Self.downscaled(data)
                block.updatedAt = Date()
                pickerItem = nil
            }
        }
    }

    private var emptyTarget: some View {
        Button {
            showingPicker = true
        } label: {
            Label("Add a photo", systemImage: "photo.badge.plus")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.border, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add a Photo")
    }

    /// Camera photos run 5-10 MB each; a note page doesn't need more than ~1600pt of
    /// pixels, so re-encode anything bigger before it hits the store.
    private static func downscaled(_ data: Data) -> Data {
        #if os(iOS)
        let maxDimension: CGFloat = 1600
        guard let image = UIImage(data: data) else { return data }
        let largest = max(image.size.width, image.size.height)
        guard largest > maxDimension else { return data }
        let scale = maxDimension / largest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return resized.jpegData(compressionQuality: 0.85) ?? data
        #else
        return data
        #endif
    }
}

/// Notion-style inline link to another page: a bordered chip that opens the page on
/// tap. An unlinked block prompts for a target instead.
private struct PageLinkBlockView: View {
    @Bindable var block: Block
    var onOpenPage: ((Page) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @State private var showingPicker = false

    private var linkedPage: Page? {
        guard let target = block.linkedPageID else { return nil }
        var descriptor = FetchDescriptor<Page>(predicate: #Predicate { $0.id == target })
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }

    var body: some View {
        Group {
            if let page = linkedPage {
                Button {
                    onOpenPage?(page)
                } label: {
                    HStack(spacing: 10) {
                        if page.icon.isEmpty {
                            Image(systemName: "doc.text")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                        } else {
                            Text(page.icon).font(.system(size: 17))
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(page.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.text)
                                .underline(color: Theme.border)
                            if let notebook = page.notebook {
                                Text(notebook.title).metaLabel()
                            }
                        }
                        Spacer()
                        Button {
                            showingPicker = true
                        } label: {
                            Image(systemName: "link")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.muted)
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Change Link")
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open \(page.title)")
            } else {
                HStack(spacing: 8) {
                    Button {
                        showingPicker = true
                    } label: {
                        Label("Link a page…", systemImage: "link")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Theme.border, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Link a Page")

                    Button(action: createSubpage) {
                        Label("New sub-page", systemImage: "doc.badge.plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Theme.border, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("New Sub-page")
                }
            }
        }
        .sheet(isPresented: $showingPicker) {
            PageLinkPicker(excludedPageID: block.page?.id) { target in
                block.linkedPageID = target.id
                block.updatedAt = Date()
            }
        }
    }

    /// Creates a page nested under the current page and links this block to it,
    /// then jumps straight in — the Notion "New page" flow.
    private func createSubpage() {
        guard let parent = block.page else { return }
        let child = Page(
            title: "Untitled Page",
            notebook: parent.notebook,
            sortIndex: parent.subpages?.count ?? 0
        )
        child.parentPage = parent
        modelContext.insert(child)
        block.linkedPageID = child.id
        block.updatedAt = Date()
        onOpenPage?(child)
    }
}

/// Sheet listing every page grouped by notebook so a page-link block can pick a target.
private struct PageLinkPicker: View {
    var excludedPageID: UUID?
    var onPick: (Page) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Notebook.sortIndex) private var notebooks: [Notebook]

    var body: some View {
        NavigationStack {
            List {
                ForEach(notebooks) { notebook in
                    let pages = (notebook.pages ?? [])
                        .filter { $0.id != excludedPageID }
                        .sorted { $0.sortIndex < $1.sortIndex }
                    if !pages.isEmpty {
                        Section(notebook.title) {
                            ForEach(pages) { page in
                                Button {
                                    onPick(page)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 10) {
                                        if page.icon.isEmpty {
                                            Image(systemName: "doc.text")
                                                .foregroundStyle(Theme.muted)
                                        } else {
                                            Text(page.icon)
                                        }
                                        Text(page.title)
                                            .foregroundStyle(Theme.text)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Link a Page")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Turns a block's text into a flashcard: front is prefilled from the block, back is
/// left for the student to fill in, and the card lands in an existing or brand-new deck.
private struct MakeFlashcardSheet: View {
    let frontText: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Deck.updatedAt, order: .reverse) private var decks: [Deck]

    @State private var front: String
    @State private var back = ""
    @State private var selectedDeck: Deck?
    @State private var newDeckTitle = ""

    init(frontText: String) {
        self.frontText = frontText
        _front = State(initialValue: frontText)
    }

    private var canSave: Bool {
        let hasFront = !front.trimmingCharacters(in: .whitespaces).isEmpty
        let hasDestination = selectedDeck != nil || !newDeckTitle.trimmingCharacters(in: .whitespaces).isEmpty
        return hasFront && hasDestination
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Card") {
                    TextField("Front", text: $front, axis: .vertical)
                    TextField("Back", text: $back, axis: .vertical)
                }
                Section("Deck") {
                    if decks.isEmpty {
                        TextField("New deck name", text: $newDeckTitle)
                    } else {
                        Picker("Deck", selection: $selectedDeck) {
                            Text("New deck…").tag(Optional<Deck>.none)
                            ForEach(decks) { deck in
                                Text(deck.title).tag(Optional(deck))
                            }
                        }
                        if selectedDeck == nil {
                            TextField("New deck name", text: $newDeckTitle)
                        }
                    }
                }
            }
            .navigationTitle("Make Flashcard")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        let deck: Deck
        if let selectedDeck {
            deck = selectedDeck
        } else {
            let created = Deck(title: newDeckTitle.trimmingCharacters(in: .whitespaces))
            modelContext.insert(created)
            deck = created
        }
        let card = Flashcard(
            front: front.trimmingCharacters(in: .whitespaces),
            back: back.trimmingCharacters(in: .whitespaces),
            sortIndex: deck.cards?.count ?? 0,
            deck: deck
        )
        modelContext.insert(card)
        deck.updatedAt = Date()
        dismiss()
    }
}
