//
//  TelegramDTO.swift
//  Trainer-bot
//

import Foundation

// MARK: - API Response

struct TgResponse<T: Decodable>: Decodable {
    let ok: Bool
    let result: T
}

// MARK: - Update

struct TgUpdate: Decodable {
    let update_id: Int
    let message: TgMessage?
}

// MARK: - Message

struct TgMessage: Decodable {
    let message_id: Int
    let date: Int
    let text: String?
    let chat: TgChat
    let from: TgUser?
}

struct TgChat: Decodable {
    let id: Int64
}

struct TgUser: Decodable {
    let id: Int64
    let username: String?
    let first_name: String?
    let last_name: String?
}

// MARK: - Typealiases for handlers

typealias TelegramUpdate = TgUpdate
typealias TelegramMessage = TgMessage
