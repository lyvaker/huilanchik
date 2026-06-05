//
//  ClaudeAPI.swift
//  Клиент Anthropic API со стримингом через Server-Sent Events.
//  Полностью на нативном URLSession + AsyncSequence (iOS 17+).
//

import Foundation
import UIKit

/// Контент сообщения для Anthropic API (поддерживает текст и изображения).
enum APIContent {
    case text(String)
    case image(data: Data, mediaType: String)
}

struct APIMessage {
    var role: String       // "user" | "assistant"
    var content: [APIContent]
}

enum ClaudeAPIError: Error, LocalizedError {
    case missingKey
    case badResponse(Int, String)
    case decoding(String)
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .missingKey:                 return "API ключ не задан"
        case .badResponse(let c, let s):  return "Ошибка API (\(c)): \(s)"
        case .decoding(let s):            return "Ошибка декодирования: \(s)"
        case .network(let e):             return "Сеть: \(e.localizedDescription)"
        }
    }
}

actor ClaudeAPI {
    static let shared = ClaudeAPI()
    private init() {}

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let apiVersion = "2023-06-01"

    /// Стриминговый вызов: возвращает асинхронный поток чанков текста.
    func stream(
        apiKey: String,
        model: ClaudeModel,
        system: String,
        messages: [APIMessage],
        maxTokens: Int = 2000
    ) -> AsyncThrowingStream<String, Error> {

        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard !apiKey.isEmpty else {
                        continuation.finish(throwing: ClaudeAPIError.missingKey)
                        return
                    }

                    var req = URLRequest(url: endpoint)
                    req.httpMethod = "POST"
                    req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    req.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
                    req.setValue("application/json", forHTTPHeaderField: "content-type")
                    req.timeoutInterval = 90

                    // Тело запроса
                    let body: [String: Any] = [
                        "model": model.rawValue,
                        "max_tokens": maxTokens,
                        "stream": true,
                        "system": system,
                        "messages": try Self.encodeMessages(messages)
                    ]
                    req.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: req)

                    guard let http = response as? HTTPURLResponse else {
                        continuation.finish(throwing: ClaudeAPIError.badResponse(0, "no response"))
                        return
                    }

                    if http.statusCode != 200 {
                        var errText = "HTTP \(http.statusCode)"
                        var collected = Data()
                        for try await b in bytes {
                            collected.append(b)
                            if collected.count > 4096 { break }
                        }
                        if let s = String(data: collected, encoding: .utf8) {
                            errText = s
                        }
                        continuation.finish(throwing: ClaudeAPIError.badResponse(http.statusCode, errText))
                        return
                    }

                    // Парсинг SSE
                    for try await line in bytes.lines {
                        if Task.isCancelled {
                            continuation.finish()
                            return
                        }
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        guard !payload.isEmpty, payload != "[DONE]" else { continue }

                        guard let data = payload.data(using: .utf8),
                              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                        else { continue }

                        // Тип события
                        let type = obj["type"] as? String ?? ""

                        if type == "content_block_delta" {
                            if let delta = obj["delta"] as? [String: Any],
                               let txt = delta["text"] as? String {
                                continuation.yield(txt)
                            }
                        } else if type == "message_stop" {
                            continuation.finish()
                            return
                        } else if type == "error" {
                            if let err = obj["error"] as? [String: Any],
                               let msg = err["message"] as? String {
                                continuation.finish(throwing: ClaudeAPIError.badResponse(500, msg))
                                return
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: ClaudeAPIError.network(error))
                }
            }
        }
    }

    /// Удобная функция: собрать полный ответ строкой (для не-чат вкладок).
    func complete(
        apiKey: String,
        model: ClaudeModel,
        system: String,
        userText: String,
        image: (data: Data, mediaType: String)? = nil,
        onChunk: @escaping (String) -> Void
    ) async throws -> String {

        var content: [APIContent] = []
        if let img = image {
            content.append(.image(data: img.data, mediaType: img.mediaType))
        }
        content.append(.text(userText))
        let msg = APIMessage(role: "user", content: content)

        var full = ""
        for try await chunk in stream(apiKey: apiKey, model: model, system: system, messages: [msg]) {
            full += chunk
            onChunk(chunk)
        }
        return full
    }

    // MARK: - Кодирование messages в JSON
    private static func encodeMessages(_ messages: [APIMessage]) throws -> [[String: Any]] {
        var out: [[String: Any]] = []
        for m in messages {
            var contentArr: [[String: Any]] = []
            for c in m.content {
                switch c {
                case .text(let s):
                    contentArr.append(["type": "text", "text": s])
                case .image(let data, let mediaType):
                    let b64 = data.base64EncodedString()
                    contentArr.append([
                        "type": "image",
                        "source": [
                            "type": "base64",
                            "media_type": mediaType,
                            "data": b64
                        ]
                    ])
                }
            }
            out.append(["role": m.role, "content": contentArr])
        }
        return out
    }
}

// MARK: - Утилиты для UIImage → JPEG для отправки в API
extension UIImage {
    func jpegForAPI(maxBytes: Int = 4_000_000) -> Data? {
        var quality: CGFloat = 0.9
        var data = self.jpegData(compressionQuality: quality)
        while let d = data, d.count > maxBytes, quality > 0.2 {
            quality -= 0.15
            data = self.jpegData(compressionQuality: quality)
        }
        return data
    }
}
