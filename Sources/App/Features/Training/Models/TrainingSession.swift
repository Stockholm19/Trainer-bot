//
//  TrainingSession.swift
//  Trainer-bot
//
//  Created by Roman on 18.12.2025.
//

import Vapor
import Fluent

extension TrainingSession: @unchecked Sendable {}

final class TrainingSession: Model, Content {
    static let schema = "training_sessions"

    enum Status: String, Codable {
        case inProgress
        case finished
        case canceled
    }

    @ID(key: .id)
    var id: UUID?

    @Field(key: "tg_user_id")
    var tgUserId: Int64

    @Field(key: "suite")
    var suite: String // "ed" | "mos" | "ng"

    @Field(key: "status")
    var status: String // хранить как String для простоты

    @Field(key: "current_index")
    var currentIndex: Int

    @OptionalField(key: "draft_answer")
    var draftAnswer: String?

    @Timestamp(key: "started_at", on: .create)
    var startedAt: Date?

    @OptionalField(key: "finished_at")
    var finishedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        tgUserId: Int64,
        suite: String,
        status: Status = .inProgress,
        currentIndex: Int = 0,
        draftAnswer: String? = nil
    ) {
        self.id = id
        self.tgUserId = tgUserId
        self.suite = suite
        self.status = status.rawValue
        self.currentIndex = currentIndex
        self.draftAnswer = draftAnswer
    }

    var statusEnum: Status {
        get { Status(rawValue: status) ?? .inProgress }
        set { status = newValue.rawValue }
    }
}
