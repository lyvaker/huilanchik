//
//  AppModel.swift
//  Центральное состояние приложения. Сессия 2: + smart pills,
//  follow-up чат программы, поток для фото-анализа.
//

import SwiftUI
import Observation

@Observable
final class AppModel {

    // MARK: - Настройки

    var lang: AppLanguage = .ru
    var apiKey: String = ""
    var saveKey: Bool = true
    var chatModel: ClaudeModel = .sonnet
    var machineProfile = MachineProfile()

    // MARK: - Состояние UI

    var chatMessages: [ChatMessage] = []
    var chatPendingImage: UIImage?

    /// Follow-up диалог в анализе программы
    var programChat: [ChatMessage] = []

    var history: [HistoryEntry] = []
    var savedChats: [SavedChat] = []
    var currentChatID: String?

    /// Smart pills: код → сколько раз использовали
    var smartAlarms: [String: Int] = [:]
    var smartCodes:  [String: Int] = [:]

    var isBusy: Bool = false
    var errorMessage: String?

    // MARK: - Локализация
    func t(_ key: String) -> String { L10n.string(key, lang: lang) }

    // MARK: - Init
    init() {
        loadConfig()
        loadHistory()
        loadSavedChats()
        loadSmartPills()
        if chatMessages.isEmpty {
            startNewChat(saveCurrent: false)
        }
    }

    // MARK: - Файловые пути
    private func appDir() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private var configURL:  URL { appDir().appendingPathComponent("config.json") }
    private var historyURL: URL { appDir().appendingPathComponent("history.json") }
    private var chatsURL:   URL { appDir().appendingPathComponent("saved_chats.json") }
    private var smartURL:   URL { appDir().appendingPathComponent("smart_pills.json") }
    private var imagesDir:  URL {
        let d = appDir().appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    // MARK: - Config
    private struct ConfigDTO: Codable {
        var lang: String
        var saveKey: Bool
        var model: String
        var apiKey: String?
        var machineProfile: MachineProfile
    }

    func loadConfig() {
        guard let data = try? Data(contentsOf: configURL),
              let cfg  = try? JSONDecoder().decode(ConfigDTO.self, from: data)
        else { return }
        lang        = AppLanguage(rawValue: cfg.lang) ?? .ru
        saveKey     = cfg.saveKey
        chatModel   = ClaudeModel(rawValue: cfg.model) ?? .sonnet
        if saveKey { apiKey = cfg.apiKey ?? "" }
        machineProfile = cfg.machineProfile
    }

    func saveConfig() {
        let cfg = ConfigDTO(
            lang: lang.rawValue, saveKey: saveKey,
            model: chatModel.rawValue,
            apiKey: saveKey ? apiKey : nil,
            machineProfile: machineProfile
        )
        if let data = try? JSONEncoder().encode(cfg) {
            try? data.write(to: configURL, options: .atomic)
        }
    }

    // MARK: - History
    func loadHistory() {
        if let data = try? Data(contentsOf: historyURL),
           let h    = try? JSONDecoder().decode([HistoryEntry].self, from: data) {
            history = h
        }
    }

    func saveHistory() {
        let trimmed = history.suffix(100)
        if let data = try? JSONEncoder().encode(Array(trimmed)) {
            try? data.write(to: historyURL, options: .atomic)
        }
    }

    func addHistory(kind: EntryKind, query: String, reply: String) {
        history.append(HistoryEntry(kind: kind, query: query, reply: reply))
        saveHistory()
    }

    func clearHistory() {
        history.removeAll(); saveHistory()
    }

    func deleteHistoryEntry(_ entry: HistoryEntry) {
        history.removeAll { $0.id == entry.id }
        saveHistory()
    }

    // MARK: - Smart pills
    private struct SmartDTO: Codable {
        var alarms: [String: Int]
        var codes:  [String: Int]
    }

    func loadSmartPills() {
        if let data = try? Data(contentsOf: smartURL),
           let dto  = try? JSONDecoder().decode(SmartDTO.self, from: data) {
            smartAlarms = dto.alarms
            smartCodes  = dto.codes
        }
    }

    func saveSmartPills() {
        let dto = SmartDTO(alarms: smartAlarms, codes: smartCodes)
        if let data = try? JSONEncoder().encode(dto) {
            try? data.write(to: smartURL, options: .atomic)
        }
    }

    func bumpAlarm(_ s: String) {
        let key = s.uppercased().trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return }
        smartAlarms[key, default: 0] += 1
        saveSmartPills()
    }

    func bumpCode(_ s: String) {
        let key = s.uppercased().trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return }
        smartCodes[key, default: 0] += 1
        saveSmartPills()
    }

    func topPills(smart: [String: Int], defaults: [String], count: Int) -> [String] {
        let sortedSmart = smart.sorted { $0.value > $1.value }.map(\.key)
        var result: [String] = []
        for k in sortedSmart where result.count < count { result.append(k) }
        for k in defaults where !result.contains(k) && result.count < count {
            result.append(k)
        }
        return Array(result.prefix(count))
    }

    // MARK: - Saved chats
    func loadSavedChats() {
        if let data = try? Data(contentsOf: chatsURL),
           let arr  = try? JSONDecoder().decode([SavedChat].self, from: data) {
            savedChats = arr
        }
    }

    func persistSavedChats() {
        if let data = try? JSONEncoder().encode(savedChats) {
            try? data.write(to: chatsURL, options: .atomic)
        }
    }

    func startNewChat(saveCurrent: Bool = true) {
        if saveCurrent, !chatMessages.isEmpty,
           chatMessages.contains(where: { $0.role == .user }) {
            persistCurrentChatSnapshot()
        }
        chatMessages = []
        currentChatID = UUID().uuidString
        chatPendingImage = nil
    }

    func openSavedChat(_ chat: SavedChat) {
        persistCurrentChatSnapshot()
        currentChatID = chat.id
        chatMessages = chat.messages
        chatPendingImage = nil
    }

    func deleteSavedChat(_ chat: SavedChat) {
        savedChats.removeAll { $0.id == chat.id }
        persistSavedChats()
        if chat.id == currentChatID {
            startNewChat(saveCurrent: false)
        }
    }

    func renameSavedChat(_ chat: SavedChat, to newTitle: String) {
        guard let idx = savedChats.firstIndex(where: { $0.id == chat.id }) else { return }
        savedChats[idx].title = newTitle
        persistSavedChats()
    }

    private func persistCurrentChatSnapshot() {
        guard !chatMessages.isEmpty else { return }
        guard let id = currentChatID else { return }
        let title = autoTitle()
        if let idx = savedChats.firstIndex(where: { $0.id == id }) {
            savedChats[idx].title    = title
            savedChats[idx].messages = chatMessages
            savedChats[idx].lang     = lang.rawValue
            savedChats[idx].updatedAt = .now
        } else {
            savedChats.append(SavedChat(
                id: id, title: title, lang: lang.rawValue,
                messages: chatMessages, updatedAt: .now
            ))
        }
        savedChats.sort { $0.updatedAt > $1.updatedAt }
        persistSavedChats()
    }

    private func autoTitle() -> String {
        guard let first = chatMessages.first(where: { $0.role == .user }) else {
            return t("chat_new")
        }
        let s = first.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(s.prefix(40))
    }

    // MARK: - Images
    func storeImage(_ image: UIImage) -> String? {
        guard let data = image.jpegForAPI() else { return nil }
        let name = "\(UUID().uuidString).jpg"
        let url  = imagesDir.appendingPathComponent(name)
        do { try data.write(to: url); return name }
        catch { return nil }
    }

    func loadImage(named: String) -> UIImage? {
        let url = imagesDir.appendingPathComponent(named)
        guard let d = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: d)
    }

    // MARK: - Chat send
    @MainActor
    func sendChatMessage(text rawText: String) async {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasImage = chatPendingImage != nil
        guard !text.isEmpty || hasImage else { return }
        guard !apiKey.isEmpty else {
            errorMessage = t("err_key"); return
        }

        var savedImageName: String?
        if let img = chatPendingImage {
            savedImageName = storeImage(img)
        }

        let userMsg = ChatMessage(role: .user, text: text, imagePath: savedImageName)
        chatMessages.append(userMsg)
        chatPendingImage = nil

        let assistantMsg = ChatMessage(role: .assistant, text: "")
        chatMessages.append(assistantMsg)
        let assistantIndex = chatMessages.count - 1
        isBusy = true

        var apiMessages: [APIMessage] = []
        for m in chatMessages.prefix(chatMessages.count - 1) {
            var content: [APIContent] = []
            if let imgName = m.imagePath, let img = loadImage(named: imgName),
               let d = img.jpegForAPI() {
                content.append(.image(data: d, mediaType: "image/jpeg"))
            }
            if !m.text.isEmpty {
                content.append(.text(m.text))
            }
            if !content.isEmpty {
                apiMessages.append(APIMessage(role: m.role.rawValue, content: content))
            }
        }

        do {
            var fullReply = ""
            let stream = await ClaudeAPI.shared.stream(
                apiKey: apiKey, model: chatModel,
                system: t("sys"), messages: apiMessages
            )
            for try await chunk in stream {
                fullReply += chunk
                if assistantIndex < chatMessages.count {
                    chatMessages[assistantIndex].text = fullReply
                }
            }
            persistCurrentChatSnapshot()
        } catch {
            if assistantIndex < chatMessages.count, chatMessages[assistantIndex].text.isEmpty {
                chatMessages[assistantIndex].text = "❌ \(error.localizedDescription)"
            } else {
                errorMessage = error.localizedDescription
            }
        }
        isBusy = false
    }

    // MARK: - Универсальный стриминг текста
    @MainActor
    func streamSingle(prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { cont in
            Task {
                guard !apiKey.isEmpty else {
                    cont.finish(throwing: ClaudeAPIError.missingKey); return
                }
                let msg = APIMessage(role: "user", content: [.text(prompt)])
                do {
                    let stream = await ClaudeAPI.shared.stream(
                        apiKey: apiKey, model: chatModel,
                        system: t("sys"), messages: [msg]
                    )
                    for try await c in stream { cont.yield(c) }
                    cont.finish()
                } catch {
                    cont.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Стриминг с фото
    @MainActor
    func streamWithImage(prompt: String, image: UIImage) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { cont in
            Task {
                guard !apiKey.isEmpty else {
                    cont.finish(throwing: ClaudeAPIError.missingKey); return
                }
                guard let data = image.jpegForAPI() else {
                    cont.finish(throwing: ClaudeAPIError.decoding("JPEG encode failed"))
                    return
                }
                let msg = APIMessage(role: "user", content: [
                    .image(data: data, mediaType: "image/jpeg"),
                    .text(prompt)
                ])
                do {
                    let stream = await ClaudeAPI.shared.stream(
                        apiKey: apiKey, model: chatModel,
                        system: t("sys"), messages: [msg]
                    )
                    for try await c in stream { cont.yield(c) }
                    cont.finish()
                } catch {
                    cont.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Follow-up программы
    @MainActor
    func sendProgramFollowUp(question: String, programCode: String) async {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        guard !apiKey.isEmpty else {
            errorMessage = t("err_key"); return
        }

        programChat.append(ChatMessage(role: .user, text: q))
        let assistantIdx = programChat.count
        programChat.append(ChatMessage(role: .assistant, text: ""))
        isBusy = true

        var systemText = t("sys") + "\n\n"
        if !machineProfile.isEmpty {
            systemText += "Параметры станка пользователя:\n\(machineProfile.promptText)\n\n"
        }
        systemText += "Контекст программы:\n```\n\(programCode)\n```"

        var apiMessages: [APIMessage] = []
        for m in programChat.prefix(programChat.count - 1) where !m.text.isEmpty {
            apiMessages.append(APIMessage(role: m.role.rawValue, content: [.text(m.text)]))
        }

        do {
            var full = ""
            let stream = await ClaudeAPI.shared.stream(
                apiKey: apiKey, model: chatModel,
                system: systemText, messages: apiMessages
            )
            for try await chunk in stream {
                full += chunk
                if assistantIdx < programChat.count {
                    programChat[assistantIdx].text = full
                }
            }
        } catch {
            if assistantIdx < programChat.count, programChat[assistantIdx].text.isEmpty {
                programChat[assistantIdx].text = "❌ \(error.localizedDescription)"
            }
        }
        isBusy = false
    }

    func resetProgramChat() {
        programChat.removeAll()
    }
}
