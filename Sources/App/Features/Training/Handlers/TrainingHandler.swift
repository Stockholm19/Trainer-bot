//
//  TrainingHandler.swift
//  Trainer-bot
//
//  Handles Telegram commands and buttons for training flow.
//

import Vapor
import Fluent

struct TrainingHandler {

    // Entry point from TelegramUpdatesRouter
    static func handle(
        app: Application,
        update: TelegramUpdate
    ) async throws {
        guard let message = update.message else { return }

        // chat.id у тебя НЕ optional (Int64), поэтому guard let тут нельзя
        let chatId = message.chat.id

        // TgUser.id у тебя Int64, оставим так же
        let userId: Int64 = message.from?.id ?? 0
        let text = message.text ?? ""

        // --- Commands ---
        if text == "/start" || text.lowercased() == "тесты" {
            try await showSuites(app: app, chatId: chatId)
            return
        }

        // --- Back to menu ---
        if text == "← Назад" {
            // Optional: cancel active session so it doesn't stay inProgress
            if let session = try await findActiveSession(app: app, userId: userId) {
                session.statusEnum = .canceled
                session.finishedAt = Date()
                session.draftAnswer = nil
                try await session.update(on: app.db)
            }

            try await showSuites(app: app, chatId: chatId)
            return
        }

        // --- Suite selection ---
        if text == "Электронный дом" {
            do {
                let session = try await SessionFlowService.start(app: app, tgUserId: userId, suite: "ed")
                try await sendCurrentQuestion(app: app, chatId: chatId, session: session)
            } catch {
                app.logger.error("Start suite failed: \(error)")
                try await app.telegram.sendMessage(
                    chatId: chatId,
                    text: "Не получилось начать тест: нет активных вопросов для этого направления.",
                    replyMarkup: Keyboards.suites()
                )
            }
            return
        }

        if text == "MOS" {
            let session = try await SessionFlowService.start(
                app: app,
                tgUserId: userId,
                suite: "mos"
            )
            try await sendCurrentQuestion(app: app, chatId: chatId, session: session)
            return
        }

        if text == "NG" {
            let session = try await SessionFlowService.start(
                app: app,
                tgUserId: userId,
                suite: "ng"
            )
            try await sendCurrentQuestion(app: app, chatId: chatId, session: session)
            return
        }

        // --- Session actions ---
        if text == "Следующий вопрос" {
            if let session = try await findActiveSession(app: app, userId: userId) {
                let next = try await SessionFlowService.next(app: app, sessionId: try session.requireID())
                if let q = next {
                    try await sendQuestion(app: app, chatId: chatId, question: q)
                } else {
                    try await finishSession(app: app, chatId: chatId, session: session)
                }
            }
            return
        }

        if text == "Закончить тест" {
            if let session = try await findActiveSession(app: app, userId: userId) {
                try await SessionFlowService.finish(app: app, sessionId: try session.requireID())
                try await app.telegram.sendMessage(
                    chatId: chatId,
                    text: "Тест завершён. Спасибо!",
                    replyMarkup: Keyboards.suites()
                )
            }
            return
        }

        // --- Default: treat as answer text ---
        if let session = try await findActiveSession(app: app, userId: userId) {
            try await SessionFlowService.appendToDraft(
                app: app,
                sessionId: try session.requireID(),
                text: text
            )
        }
    }

    // MARK: - Helpers

    private static func showSuites(app: Application, chatId: Int64) async throws {
        let keyboard = Keyboards.suites()
        let text = """
Здравствуйте! Я SkillTrainer — бот-тренажер для отработки ответов на реальные обращения.

Как это работает:
1) Вы выбираете направление теста
2) Я задаю вопросы по одному
3) Вы отвечаете и переходите к следующему вопросу

Выберите направление теста:
"""

        try await app.telegram.sendMessage(
            chatId: chatId,
            text: text,
            replyMarkup: keyboard
        )
    }

    private static func sendCurrentQuestion(
        app: Application,
        chatId: Int64,
        session: TrainingSession
    ) async throws {
        if let q = try await SessionFlowService.currentQuestion(
            app: app,
            sessionId: try session.requireID()
        ) {
            try await sendQuestion(app: app, chatId: chatId, question: q)
        } else {
            try await app.telegram.sendMessage(
                chatId: chatId,
                text: "Вопросы не найдены",
                replyMarkup: Keyboards.suites()
            )
        }
    }

    private static func sendQuestion(
        app: Application,
        chatId: Int64,
        question: Question
    ) async throws {
        let keyboard = Keyboards.inSession()
        try await app.telegram.sendMessage(
            chatId: chatId,
            text: question.text,
            replyMarkup: keyboard
        )
    }

    private static func finishSession(
        app: Application,
        chatId: Int64,
        session: TrainingSession
    ) async throws {
        try await SessionFlowService.finish(app: app, sessionId: try session.requireID())
        try await app.telegram.sendMessage(
            chatId: chatId,
            text: "Тест завершён. Спасибо за ответы!",
            replyMarkup: Keyboards.suites()
        )
    }

    private static func findActiveSession(
        app: Application,
        userId: Int64
    ) async throws -> TrainingSession? {
        try await TrainingSession.query(on: app.db)
            .filter(\.$tgUserId == userId)
            .filter(\.$status == TrainingSession.Status.inProgress.rawValue)
            .first()
    }
}
