//
//  TelegramClient.swift
//  Trainer-bot
//
//  Created by Roman on 18.12.2025.
//

import Vapor

final class TelegramClient {

    private let app: Application
    private let token: String
    private let baseURL: String

    init(app: Application, token: String) {
        self.app = app
        self.token = token
        self.baseURL = "https://api.telegram.org/bot\(token)"
    }

    // MARK: - Send message

    // MARK: - Request models

    struct SendMessageRequest: Content {
        let chat_id: Int64
        let text: String
        let reply_markup: ReplyMarkup?
    }

    /// Minimal reply markup. Extend when you need more fields.
    struct ReplyMarkup: Content {
        // Reply keyboard (sends message text when user taps)
        let keyboard: [[KeyboardButton]]?
        let resize_keyboard: Bool?
        let one_time_keyboard: Bool?

        // Inline keyboard (handled via callback_query)
        let inline_keyboard: [[InlineKeyboardButton]]?

        init(
            keyboard: [[KeyboardButton]]? = nil,
            resize_keyboard: Bool? = nil,
            one_time_keyboard: Bool? = nil,
            inline_keyboard: [[InlineKeyboardButton]]? = nil
        ) {
            self.keyboard = keyboard
            self.resize_keyboard = resize_keyboard
            self.one_time_keyboard = one_time_keyboard
            self.inline_keyboard = inline_keyboard
        }

        struct KeyboardButton: Content {
            let text: String
        }

        struct InlineKeyboardButton: Content {
            let text: String
            let callback_data: String?
            let url: String?
        }
    }

    struct GetUpdatesRequest: Content {
        let offset: Int?
        let timeout: Int
    }

    func sendMessage(
        chatId: Int64,
        text: String,
        replyMarkup: ReplyMarkup? = nil
    ) async throws {

        let uri = URI(string: "\(baseURL)/sendMessage")

        let body = SendMessageRequest(
            chat_id: chatId,
            text: text,
            reply_markup: replyMarkup
        )

        _ = try await app.client.post(uri) { (req: inout ClientRequest) in
            try req.content.encode(body, as: .json)
        }
    }

    // MARK: - Long polling

    func getUpdates(offset: Int?, timeout: Int = 25) async throws -> [TgUpdate] {
        let uri = URI(string: "\(baseURL)/getUpdates")

        let response = try await app.client.post(uri) { (req: inout ClientRequest) in
            try req.content.encode(GetUpdatesRequest(offset: offset, timeout: timeout), as: .json)
        }

        let decoded = try response.content.decode(TgResponse<[TgUpdate]>.self)
        return decoded.result
    }
}

// MARK: - Application storage

extension Application {
    private struct TelegramKey: StorageKey {
        typealias Value = TelegramClient
    }

    var telegram: TelegramClient {
        get {
            guard let value = storage[TelegramKey.self] else {
                fatalError("TelegramClient is not configured")
            }
            return value
        }
        set {
            storage[TelegramKey.self] = newValue
        }
    }
}
