//
//  Question.swift
//  Trainer-bot
//
//  Created by Roman on 18.12.2025.
//

import Vapor
import Fluent

extension Question: @unchecked Sendable {}

final class Question: Model, Content {
    static let schema = "questions"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "suite")
    var suite: String   // "ed" | "mos" | "ng"

    @Field(key: "code")
    var code: String    // stable id like mos_001

    @Field(key: "text")
    var text: String

    @OptionalField(key: "topic")
    var topic: String?

    @Field(key: "difficulty")
    var difficulty: Int // default 1

    @Field(key: "is_active")
    var isActive: Bool  // default true

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        suite: String,
        code: String,
        text: String,
        topic: String? = nil,
        difficulty: Int = 1,
        isActive: Bool = true
    ) {
        self.id = id
        self.suite = suite
        self.code = code
        self.text = text
        self.topic = topic
        self.difficulty = difficulty
        self.isActive = isActive
    }
}
