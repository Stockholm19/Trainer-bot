//
//  Migrations.swift
//  Trainer-bot
//
//  Created by Roman on 18.12.2025.
//

import Vapor
import Fluent

enum Migrations {
    static func add(to app: Application) {
        app.migrations.add(CreateQuestions())
        app.migrations.add(CreateTrainingSessions())
        app.migrations.add(CreateAnswers())
    }
}

struct CreateQuestions: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("questions")
            .id()
            .field("suite", .string, .required)
            .field("code", .string, .required)
            .field("text", .string, .required)
            .field("topic", .string)
            .field("difficulty", .int, .required, .sql(.default(1)))
            .field("is_active", .bool, .required, .sql(.default(true)))
            .field("updated_at", .datetime)
            .unique(on: "suite", "code")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("questions").delete()
    }
}

struct CreateTrainingSessions: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("training_sessions")
            .id()
            .field("tg_user_id", .int64, .required)
            .field("suite", .string, .required)
            .field("status", .string, .required)
            .field("current_index", .int, .required, .sql(.default(0)))
            .field("draft_answer", .string)
            .field("started_at", .datetime)
            .field("finished_at", .datetime)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("training_sessions").delete()
    }
}

struct CreateAnswers: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("answers")
            .id()
            .field("session_id", .uuid, .required, .references("training_sessions", "id", onDelete: .cascade))
            .field("question_id", .uuid, .references("questions", "id", onDelete: .setNull))
            .field("question_text_snapshot", .string, .required)
            .field("answer_text", .string, .required)
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("answers").delete()
    }
}
