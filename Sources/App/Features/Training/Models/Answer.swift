//
//  Answer.swift
//  Trainer-bot
//
//  Created by Roman on 18.12.2025.
//

import Vapor
import Fluent

// Fluent models are reference types and are not Sendable by design.
// This conformance is required to silence Swift 6 warnings and is safe here.
extension Answer: @unchecked Sendable {}

final class Answer: Model, Content {
    static let schema = "answers"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "session_id")
    var session: TrainingSession

    @OptionalParent(key: "question_id")
    var question: Question?

    @Field(key: "question_text_snapshot")
    var questionTextSnapshot: String

    @Field(key: "answer_text")
    var answerText: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        sessionId: UUID,
        questionId: UUID?,
        questionTextSnapshot: String,
        answerText: String
    ) {
        self.id = id
        self.$session.id = sessionId
        self.$question.id = questionId
        self.questionTextSnapshot = questionTextSnapshot
        self.answerText = answerText
    }
}
