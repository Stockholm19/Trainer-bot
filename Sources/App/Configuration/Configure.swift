//
//  Configure.swift
//  Trainer-bot
//
//  Created by Роман Пшеничников on 18.12.2025.
//

import Vapor
import Fluent
import FluentPostgresDriver

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

    // Auto migrate + sync (НЕ в тестах)
    if app.environment != .testing {
        Task {
            do {
                try await app.autoMigrate()
                // тут позже будет QuestionsSyncService
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
