//
//  Keyboards.swift
//  Trainer-bot
//
//  Created by Roman on 18.12.2025.
//

import Vapor

enum Keyboards {

    static func suites() -> TelegramClient.ReplyMarkup {
        TelegramClient.ReplyMarkup(
            keyboard: [
                [ .init(text: "Электронный дом") ],
                [ .init(text: "MOS") ],
                [ .init(text: "NG") ]
            ],
            resize_keyboard: true,
            one_time_keyboard: true
        )
    }

    static func inSession() -> TelegramClient.ReplyMarkup {
        TelegramClient.ReplyMarkup(
            keyboard: [
                [ .init(text: "Следующий вопрос") ],
                [ .init(text: "Закончить тест") ],
                [ .init(text: "← Назад") ]
            ],
            resize_keyboard: true,
            one_time_keyboard: false
        )
    }
}
