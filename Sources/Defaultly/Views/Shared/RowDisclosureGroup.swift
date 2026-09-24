import SwiftUI

/// A disclosure group that also opens when its title is clicked. In a macOS form, the system one only
/// responds to its small chevron, so clicking "5 More Apps" did nothing.
struct RowDisclosureGroup<Label: View, Content: View>: View {
    @ViewBuilder let content: () -> Content
    @ViewBuilder let label: () -> Label
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded, content: content) {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                label()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }
}

extension RowDisclosureGroup where Label == Text {
    init(_ titleKey: LocalizedStringKey, @ViewBuilder content: @escaping () -> Content) {
        self.init(content: content) { Text(titleKey) }
    }
}
