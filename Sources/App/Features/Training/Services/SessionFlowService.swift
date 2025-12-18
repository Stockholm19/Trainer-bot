//
//  SessionFlowService.swift
//  Trainer-bot
//
//  Created by Roman on 18.12.2025.
//

import Vapor
import Fluent

/// Core training session flow (no Telegram/UI here).
///
/// Responsibilities:
/// - start a session
/// - pick active questions for a suite
/// - keep draft answer (multiple user messages)
/// - on "Next": persist Answer snapshot and advance index
/// - on "Finish": persist last draft (if any) and mark session finished
struct SessionFlowService {

    enum FlowError: Error {
        case noActiveQuestions(suite: String)
        case sessionNotInProgress
        case sessionNotFound
        case invalidState(String)
    }

    // MARK: - Start

    /// Creates a new training session for a Telegram user.
    ///
    /// Important: We do NOT store the randomized list in DB yet (MVP).
    /// Instead we use deterministic ordering: by `code`.
    ///
    /// This makes the flow predictable and avoids extra tables.
    static func start(app: Application, tgUserId: Int64, suite: String) async throws -> TrainingSession {
        try await app.db.transaction { db in
            // Optionally: close unfinished sessions for this user.
            // (So "Start" always creates a clean new session.)
            try await TrainingSession.query(on: db)
                .filter(\.$tgUserId == tgUserId)
                .filter(\.$status == TrainingSession.Status.inProgress.rawValue)
                .all()
                .asyncForEach { s in
                    s.statusEnum = .canceled
                    s.finishedAt = Date()
                    try await s.update(on: db)
                }

            // Ensure there are questions.
            let count = try await Question.query(on: db)
                .filter(\.$suite == suite)
                .filter(\.$isActive == true)
                .count()

            guard count > 0 else {
                throw FlowError.noActiveQuestions(suite: suite)
            }

            let session = TrainingSession(
                tgUserId: tgUserId,
                suite: suite,
                status: .inProgress,
                currentIndex: 0,
                draftAnswer: nil
            )
            try await session.create(on: db)
            return session
        }
    }

    // MARK: - Current question

    /// Returns current question based on session.currentIndex.
    /// Deterministic order: active questions ordered by `code`.
    static func currentQuestion(app: Application, sessionId: UUID) async throws -> Question? {
        try await app.db.transaction { db in
            guard let session = try await TrainingSession.find(sessionId, on: db) else {
                throw FlowError.sessionNotFound
            }
            return try await currentQuestion(session: session, on: db)
        }
    }

    static func currentQuestion(session: TrainingSession, on db: Database) async throws -> Question? {
        guard session.statusEnum == .inProgress else {
            throw FlowError.sessionNotInProgress
        }

        let questions = try await Question.query(on: db)
            .filter(\.$suite == session.suite)
            .filter(\.$isActive == true)
            .sort(\.$code, .ascending)
            .all()

        guard session.currentIndex >= 0 else {
            throw FlowError.invalidState("currentIndex < 0")
        }

        if session.currentIndex >= questions.count {
            return nil
        }

        return questions[session.currentIndex]
    }

    // MARK: - Draft answer

    /// Appends message text to the session draft answer.
    ///
    /// Telegram sends user text as separate messages. For MVP we accumulate them.
    static func appendToDraft(app: Application, sessionId: UUID, text: String) async throws {
        try await app.db.transaction { db in
            guard let session = try await TrainingSession.find(sessionId, on: db) else {
                throw FlowError.sessionNotFound
            }
            try await appendToDraft(session: session, text: text, on: db)
        }
    }

    static func appendToDraft(session: TrainingSession, text: String, on db: Database) async throws {
        guard session.statusEnum == .inProgress else {
            throw FlowError.sessionNotInProgress
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let current = session.draftAnswer, !current.isEmpty {
            session.draftAnswer = current + "\n" + trimmed
        } else {
            session.draftAnswer = trimmed
        }

        try await session.update(on: db)
    }

    // MARK: - Next

    /// Persists current draft answer (if any) as Answer snapshot and moves to next question.
    /// Returns the next question (or nil if no more questions).
    static func next(app: Application, sessionId: UUID) async throws -> Question? {
        try await app.db.transaction { db in
            guard let session = try await TrainingSession.find(sessionId, on: db) else {
                throw FlowError.sessionNotFound
            }

            let current = try await currentQuestion(session: session, on: db)
            try await persistDraftAsAnswerIfNeeded(session: session, question: current, on: db)

            // advance index
            session.currentIndex += 1
            session.draftAnswer = nil
            try await session.update(on: db)

            // fetch next
            return try await currentQuestion(session: session, on: db)
        }
    }

    // MARK: - Finish

    /// Finishes the session.
    /// Persists last draft answer (if any) and marks session as finished.
    static func finish(app: Application, sessionId: UUID) async throws {
        try await app.db.transaction { db in
            guard let session = try await TrainingSession.find(sessionId, on: db) else {
                throw FlowError.sessionNotFound
            }

            let current = try await currentQuestion(session: session, on: db)
            try await persistDraftAsAnswerIfNeeded(session: session, question: current, on: db)

            session.statusEnum = .finished
            session.finishedAt = Date()
            session.draftAnswer = nil
            try await session.update(on: db)
        }
    }

    // MARK: - Internals

    /// Writes an Answer if draftAnswer is not empty.
    ///
    /// If `question` is nil (end of list), we still persist the draft with questionTextSnapshot = "".
    private static func persistDraftAsAnswerIfNeeded(session: TrainingSession, question: Question?, on db: Database) async throws {
        let draft = (session.draftAnswer ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !draft.isEmpty else { return }

        let qText = question?.text ?? ""

        let ans = Answer(
            sessionId: try session.requireID(),
            questionId: question?.id,
            questionTextSnapshot: qText,
            answerText: draft
        )
        try await ans.create(on: db)
    }
}

// MARK: - Small async helper

private extension Array where Element: Sendable {
    func asyncForEach(_ op: @Sendable (Element) async throws -> Void) async rethrows {
        for el in self {
            try await op(el)
        }
    }
}
