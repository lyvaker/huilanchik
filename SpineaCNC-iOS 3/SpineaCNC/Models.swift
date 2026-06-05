//
//  Models.swift
//  Модели данных приложения. Сессия 2: + украинский язык.
//

import Foundation
import SwiftUI

// MARK: - Модели Claude API
enum ClaudeModel: String, CaseIterable, Codable, Identifiable {
    case sonnet = "claude-sonnet-4-6"
    case haiku  = "claude-haiku-4-5-20251001"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sonnet: return "Sonnet 4.6"
        case .haiku:  return "Haiku 4.5"
        }
    }

    var subtitle: String {
        switch self {
        case .sonnet: return "качество"
        case .haiku:  return "скорость ×4"
        }
    }
}

// MARK: - Языки
enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case ru = "RU"
    case sk = "SK"
    case en = "EN"
    case ua = "UA"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ru: return "Русский"
        case .sk: return "Slovenčina"
        case .en: return "English"
        case .ua: return "Українська"
        }
    }

    var flag: String {
        switch self {
        case .ru: return "🇷🇺"
        case .sk: return "🇸🇰"
        case .en: return "🇬🇧"
        case .ua: return "🇺🇦"
        }
    }
}

// MARK: - Виды записей истории
enum EntryKind: String, Codable {
    case alarm, code, program, photo, chat
}

// MARK: - Сообщение в чате
struct ChatMessage: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var role: Role
    var text: String
    var imagePath: String?

    enum Role: String, Codable { case user, assistant }
}

// MARK: - Сохранённый чат
struct SavedChat: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var title: String
    var lang: String
    var messages: [ChatMessage] = []
    var updatedAt: Date = .now
}

// MARK: - Запись истории
struct HistoryEntry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var kind: EntryKind
    var query: String
    var reply: String
    var date: Date = .now
}

// MARK: - Профиль станка
struct MachineProfile: Codable, Equatable {
    var model: String = ""
    var ctrl: String = ""
    var axes: String = ""
    var maxspeed: String = ""
    var maxfeed: String = ""
    var tools: String = ""
    var materials: String = ""
    var tolerances: String = ""
    var postproc: String = ""
    var notes: String = ""

    var isEmpty: Bool {
        model.isEmpty && ctrl.isEmpty && axes.isEmpty &&
        maxspeed.isEmpty && maxfeed.isEmpty && tools.isEmpty &&
        materials.isEmpty && tolerances.isEmpty &&
        postproc.isEmpty && notes.isEmpty
    }

    var promptText: String {
        var lines: [String] = []
        if !model.isEmpty      { lines.append("Модель: \(model)") }
        if !ctrl.isEmpty       { lines.append("Стойка: \(ctrl)") }
        if !axes.isEmpty       { lines.append("Оси: \(axes)") }
        if !maxspeed.isEmpty   { lines.append("Макс. обороты: \(maxspeed)") }
        if !maxfeed.isEmpty    { lines.append("Макс. подача: \(maxfeed)") }
        if !tools.isEmpty      { lines.append("Инструменты: \(tools)") }
        if !materials.isEmpty  { lines.append("Материалы: \(materials)") }
        if !tolerances.isEmpty { lines.append("Допуски: \(tolerances)") }
        if !postproc.isEmpty   { lines.append("Постпроцессор: \(postproc)") }
        if !notes.isEmpty      { lines.append("Заметки: \(notes)") }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Быстрые списки
enum QuickLists {
    static let alarms = ["607", "401", "9004", "SV0401", "EX1082", "OT0506"]
    static let codes  = ["M30", "G00", "G01", "G54", "M03", "M08", "G28", "M98"]
}
