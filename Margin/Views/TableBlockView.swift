import SwiftUI

struct TableBlockView: View {
    @Bindable var block: Block
    @State private var rows: [[String]] = BlockTableData.empty.rows

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                ForEach(rows.indices, id: \.self) { r in
                    GridRow {
                        ForEach(rows[r].indices, id: \.self) { c in
                            TextField("", text: binding(r, c), axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .frame(minWidth: 70)
                        }
                    }
                }
            }
            HStack(spacing: 12) {
                Button("Add Row", systemImage: "plus", action: addRow)
                Button("Add Column", systemImage: "plus", action: addColumn)
            }
            .labelStyle(.titleAndIcon)
            .font(.caption)
        }
        .onAppear { rows = block.table.rows }
        .onChange(of: rows) { _, newValue in
            block.table = BlockTableData(rows: newValue)
        }
    }

    private func binding(_ r: Int, _ c: Int) -> Binding<String> {
        Binding(
            get: { rows[r][c] },
            set: { rows[r][c] = $0 }
        )
    }

    private func addRow() {
        let columnCount = rows.first?.count ?? 2
        rows.append(Array(repeating: "", count: columnCount))
    }

    private func addColumn() {
        for i in rows.indices {
            rows[i].append("")
        }
    }
}
