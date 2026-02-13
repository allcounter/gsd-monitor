import SwiftUI

// MARK: - Themed Button Style

struct GSDButtonStyle: ButtonStyle {
    enum Variant {
        case primary
        case secondary
        case ghost
    }

    let variant: Variant

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(borderColor, lineWidth: variant == .ghost ? 0 : 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary:
            return Theme.bg0
        case .secondary:
            return Theme.fg1
        case .ghost:
            return Theme.fg2
        }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        switch variant {
        case .primary:
            return isPressed ? Theme.brightBlue.opacity(0.8) : Theme.brightBlue
        case .secondary:
            return isPressed ? Theme.bg3 : Theme.bg2
        case .ghost:
            return isPressed ? Theme.bg2 : Color.clear
        }
    }

    private var borderColor: Color {
        switch variant {
        case .primary:
            return Theme.brightBlue.opacity(0.6)
        case .secondary:
            return Theme.bg3
        case .ghost:
            return .clear
        }
    }
}

extension View {
    func gsdButtonStyle(_ variant: GSDButtonStyle.Variant) -> some View {
        self.buttonStyle(GSDButtonStyle(variant: variant))
    }
}
