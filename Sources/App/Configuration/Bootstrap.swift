//
//  Bootstrap.swift
//  Trainer-bot
//
//  Created by Роман Пшеничников on 18.12.2025.
//

import Vapor

/// Асинхронная инициализация приложения (используется в Main.swift)
public func bootstrap(_ app: Application) async throws {
    // Здесь вызывается стандартная конфигурация приложения
    try configure(app)
    
    // Если нужно — добавь асинхронные инициализации (например, подключение к БД, S3 и т.п.)
    // await app.someAsyncInit()
}
