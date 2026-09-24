import SwiftUI

/// The first few app rows, with the rest one click away (Hick's law).
struct CappedAppList<Item: Identifiable, Row: View>: View {
    let items: [Item]
    var visibleCount = 4
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        ForEach(items.prefix(visibleCount)) { row($0) }
        if items.count > visibleCount {
            RowDisclosureGroup("\(items.count - visibleCount) More Apps") {
                ForEach(items.dropFirst(visibleCount)) { row($0) }
            }
        }
    }
}
