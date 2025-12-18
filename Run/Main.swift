//
//  Main.swift
//  Trainer-bot
//
//  Created by Роман Пшеничников on 18.12.2025.
//

import Vapor
import App

@main
struct Runner {
    static func main() async {
        do {
            // Создаём приложение асинхронно (Application.make(.detect()))
            let app = try await Application.make(.detect())

            do {
                // Асинхронный bootstrap — реализуй в App/ (или оставь configure -> тогда назови/оберни в bootstrap)
                try await bootstrap(app)

                // Запуск приложения в async-режиме (вместо app.run())
                try await app.execute()
            } catch {
                let msg = String(describing: error)
                fputs("Fatal error: \(msg)\n", stderr)
                // падаем ниже через asyncShutdown
            }

            // Асинхронный корректный shutdown (вместо defer { app.shutdown() })
            try await app.asyncShutdown()
        } catch {
            let msg = String(describing: error)
            fputs("Fatal startup error: \(msg)\n", stderr)
            exit(1)
        }
    }
}
