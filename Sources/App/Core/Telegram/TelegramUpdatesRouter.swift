//
//  TelegramUpdatesRouter.swift
//  Trainer-bot
//
//  Created by Roman on 18.12.2025.
//

import Vapor

/// Starts Telegram long polling and routes updates to handlers.
enum TelegramUpdatesRouter {

    /// Launch background long-polling loop.
    static func start(app: Application) {
        Task.detached(priority: .background) {
            var offset: Int? = nil

            app.logger.info("Telegram long polling started")

            while !Task.isCancelled {
                do {
                    let updates = try await app.telegram.getUpdates(offset: offset)

                    for update in updates {
                        offset = update.update_id + 1
                        try await TrainingHandler.handle(app: app, update: update)
                    }
                } catch {
                    app.logger.error("Telegram polling error: \(error)")
                    // Small backoff to avoid tight loop on errors
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
        }
    }
}
