import SwiftUI

// Warm neutrals and soft chrome from the owner's supplied visual reference.
enum NidaStyle {
    static let surface = Color(red: 0.141, green: 0.145, blue: 0.129)
    static let chrome = Color(red: 0.204, green: 0.208, blue: 0.184)
    static let raised = Color(red: 0.278, green: 0.282, blue: 0.251)
    static let text = Color(red: 0.965, green: 0.965, blue: 0.949)
    static let secondaryText = Color(red: 0.710, green: 0.714, blue: 0.682)
    static let accent = Color(red: 0.788, green: 0.863, blue: 0.667)
    static let hairline = Color.white.opacity(0.12)

    static let panelInset: CGFloat = 24
    static let sectionGap: CGFloat = 20
    static let groupGap: CGFloat = 12
    static let controlHeight: CGFloat = 34
    static let rowRadius: CGFloat = 14
    static let panelShape = UnevenRoundedRectangle(
        topLeadingRadius: 12, bottomLeadingRadius: 32,
        bottomTrailingRadius: 32, topTrailingRadius: 12, style: .continuous
    )
}
