import SwiftUI

// The only place that touches Liquid Glass APIs, so every use has one fallback for macOS 14–15.
// Glass is reserved for the control layer that floats above content.

extension View {
    /// A floating control surface, such as the activity capsule.
    @ViewBuilder
    func floatingGlass(in shape: some Shape) -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.regularMaterial, in: shape)
                .overlay(shape.stroke(.separator, lineWidth: 0.5))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 3)
        }
    }

    /// Action buttons: glass on macOS 26+, bordered before.
    @ViewBuilder
    func glassButton(prominent: Bool = false) -> some View {
        if #available(macOS 26, *) {
            if prominent { buttonStyle(.glassProminent) } else { buttonStyle(.glass) }
        } else {
            if prominent { buttonStyle(.borderedProminent) } else { buttonStyle(.bordered) }
        }
    }

    /// A bar pinned to the bottom of scrolling content. macOS 26 separates it with the system's hard
    /// scroll-edge effect, which keeps its text legible without stacking glass on glass;
    /// earlier versions use a bar material.
    @ViewBuilder
    func bottomActionBar(@ViewBuilder content: () -> some View) -> some View {
        if #available(macOS 26, *) {
            safeAreaBar(edge: .bottom, content: content)
                .scrollEdgeEffectStyle(.hard, for: .bottom)
        } else {
            safeAreaInset(edge: .bottom) { content().background(.bar) }
        }
    }
}
