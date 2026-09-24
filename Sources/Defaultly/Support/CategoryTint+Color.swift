import DefaultlyCore
import SwiftUI

extension CategoryTint {
    var color: Color {
        switch self {
        case .blue: .blue
        case .green: .green
        case .orange: .orange
        case .red: .red
        case .brown: .brown
        case .gray: .gray
        case .cyan: .cyan
        case .indigo: .indigo
        case .teal: .teal
        case .pink: .pink
        case .purple: .purple
        case .yellow: .yellow
        case .mint: .mint
        }
    }
}
