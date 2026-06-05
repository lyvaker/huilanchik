//
//  Theme.swift
//  Цвета из десктопной версии (точное совпадение)
//

import SwiftUI

enum Theme {
    // Брендовые
    static let red       = Color(hex: 0xE8192C)
    static let redHover  = Color(hex: 0xC8111F)
    static let redLight  = Color(hex: 0xFFF0F1)
    static let blue      = Color(hex: 0x00B4D8)
    static let green     = Color(hex: 0x22C55E)

    // Фоны
    static let bg        = Color(hex: 0xF5F4F2)
    static let bg2       = Color(hex: 0xFFFFFF)
    static let bg3       = Color(hex: 0xF0EFEB)

    // Текст
    static let text      = Color(hex: 0x1C1C1C)
    static let text2     = Color(hex: 0x5A5A58)
    static let text3     = Color(hex: 0x9A9A96)

    static let border    = Color(hex: 0xE2E0DA)

    // Пузыри чата
    static let chatUserBg    = Color(hex: 0xE8192C)
    static let chatUserText  = Color.white
    static let chatBotBg     = Color(hex: 0xF0EFEB)
    static let chatBotText   = Color(hex: 0x1C1C1C)
    static let chatThinkBg   = Color(hex: 0xF7F7F5)
    static let avatarAI      = Color(hex: 0x1C2B3A)
    static let avatarAIIcon  = Color(hex: 0x00C8F0)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}
