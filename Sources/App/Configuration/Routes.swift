//
//  Routes.swift
//  Trainer-bot
//
//  Created by Роман Пшеничников on 18.12.2025.
//

import Vapor

func routes(_ app: Application) throws {
    app.get("health") { _ in "OK" }
    app.get { _ in "Hello, Vapor!" }
}
