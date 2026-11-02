import SwiftUI

// Shared semantic colors, spacing and controls for native surfaces.
enum NidaStyle {
    static let surface = Color(red: 0.141, green: 0.145, blue: 0.129)
    static let text = Color(red: 0.965, green: 0.965, blue: 0.949)
    static let secondaryText = Color(red: 0.90, green: 0.90, blue: 0.87)
    static var accent: Color { Color(nsColor: .controlAccentColor) }
    static let hairline = Color.white.opacity(0.12)

    static let notchHorizontalInset: CGFloat = 38
    static let groupGap: CGFloat = 12
    static let iconControlSize: CGFloat = 28
    static let controlHeight: CGFloat = 34
    static let scheduleStatusHeight: CGFloat = 52
    static let rowRadius: CGFloat = 14
    static let opaqueGlass = Color(red: 0.34, green: 0.35, blue: 0.32)
}

// Concave shoulders meet the screen edge; convex lower corners finish the expanded panel.
struct NotchSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        let shoulder: CGFloat = min(18, rect.width / 4, rect.height / 4)
        let bottom: CGFloat = min(36, (rect.height - shoulder) / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - shoulder, y: rect.minY + shoulder),
                          control: CGPoint(x: rect.maxX - shoulder, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - shoulder, y: rect.maxY - bottom))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - shoulder - bottom, y: rect.maxY),
                          control: CGPoint(x: rect.maxX - shoulder, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + shoulder + bottom, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX + shoulder, y: rect.maxY - bottom),
                          control: CGPoint(x: rect.minX + shoulder, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + shoulder, y: rect.minY + shoulder))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY),
                          control: CGPoint(x: rect.minX + shoulder, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// Explicit colors stay legible even when the nonactivating panel isn't key.
struct NidaButtonStyle: ButtonStyle {
    var prominent = false
    var flat = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(prominent ? NidaStyle.surface : NidaStyle.text)
            .contentShape(.capsule)
            .focusEffectDisabled(false)
            .background {
                if prominent {
                    Capsule().fill(NidaStyle.text)
                } else if reduceTransparency || contrast == .increased {
                    Capsule().fill(NidaStyle.opaqueGlass)
                } else if flat {
                    Capsule().fill(.white.opacity(0.10))
                } else {
                    Capsule().fill(.white.opacity(0.10))
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
            }
            .overlay {
                Capsule().strokeBorder(contrast == .increased
                    ? (prominent ? NidaStyle.surface : NidaStyle.text) : .clear, lineWidth: 1)
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.45)
    }
}
