import Foundation
import SwiftUI

/// UUIDs give blocks a varied color while keeping every surface and refresh consistent.
enum BlockWidgetPalette {
    // Sage, blue, lavender, rose, peach, sand, and teal.
    private static let lightAccents: [UInt32] = [0x356B5B, 0x3D6589, 0x71578E, 0x965568, 0x925D3C, 0x76632F, 0x326C70]
    private static let darkAccents: [UInt32] = [0x8FD3B8, 0xA2C5E8, 0xC7B4E5, 0xE5B0C0, 0xE7BD9C, 0xDACC9A, 0x9DD5D3]
    private static let lightBackgrounds: [UInt32] = [0xF0F6F2, 0xEFF4F9, 0xF4F0F8, 0xFAF0F3, 0xFAF3ED, 0xF7F5EB, 0xEDF6F5]
    private static let darkBackgrounds: [UInt32] = [0x111E19, 0x141D27, 0x1D1926, 0x25191E, 0x251D17, 0x211F16, 0x111F20]

    static func accent(for blockID: UUID?, dark: Bool) -> Color {
        color((dark ? darkAccents : lightAccents)[index(for: blockID)])
    }

    static func background(for blockID: UUID?, dark: Bool) -> Color {
        color((dark ? darkBackgrounds : lightBackgrounds)[index(for: blockID)])
    }

    private static func index(for blockID: UUID?) -> Int {
        guard let blockID else { return 0 }
        // Swift's hashValue changes between launches; this mapping does not.
        return blockID.uuidString.utf8.reduce(0) { ($0 * 31 + Int($1)) % darkAccents.count }
    }

    private static func color(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 0xFF) / 255,
              green: Double((hex >> 8) & 0xFF) / 255,
              blue: Double(hex & 0xFF) / 255)
    }
}
