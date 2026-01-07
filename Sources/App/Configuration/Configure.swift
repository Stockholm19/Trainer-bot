//
//  Configure.swift
//  Trainer-bot
//
//  Created by Роман Пшеничников on 18.12.2025.
//

import Vapor
import Fluent
import FluentPostgresDriver
import Foundation

public func configure(_ app: Application) throws {

    // --- DB configuration ---
    // Стабильный вариант для Vapor 4: работаем через DATABASE_URL, иначе собираем URL из переменных.
    // (Избегает текущих deprecated API вокруг PostgresConfiguration/SQLPostgresConfiguration.)

    let databaseURL: String

    if let envURL = Environment.get("DATABASE_URL") {
        databaseURL = envURL
    } else {
        let host = Environment.get("DATABASE_HOST") ?? "localhost"
        let port = Environment.get("DATABASE_PORT") ?? "5432"
        let user = Environment.get("DATABASE_USERNAME") ?? "trainer"
        let pass = Environment.get("DATABASE_PASSWORD") ?? "trainer"
        let name = Environment.get("DATABASE_NAME") ?? "trainer"
        // Для локальной разработки удобно явно отключить SSL.
        databaseURL = "postgresql://\(user):\(pass)@\(host):\(port)/\(name)?sslmode=disable"
    }

    try app.databases.use(.postgres(url: databaseURL), as: .psql)
    // --- End DB configuration ---

    // Migrations
    Migrations.add(to: app)

    // Routes
    try routes(app)

    // Инициализация телеги
    if let token = Environment.get("BOT_TOKEN") {
        app.telegram = TelegramClient(app: app, token: token)
    } else {
        app.logger.critical("BOT_TOKEN is missing")
    }

    // Auto migrate + sync (НЕ в тестах)
    // Важно: запускаем long polling ПОСЛЕ того, как схема БД и вопросы готовы.
    if app.environment != .testing {
        Task {
            do {
                try await app.autoMigrate()
                _ = try await QuestionsSyncService.syncAll(app: app)

                // Запускаем long polling только после миграций/синка
                if Environment.get("BOT_TOKEN") != nil {
                    TelegramUpdatesRouter.start(app: app)
                }
            } catch {
                app.logger.critical("Migration failed: \(error)")
            }
        }
    }
    
    app.http.server.configuration.hostname =
        Environment.get("HOST") ?? "0.0.0.0"
    app.http.server.configuration.port =
        Environment.get("PORT").flatMap(Int.init) ?? 8080
}
