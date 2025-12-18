
//
//  QuestionsSyncService.swift
//  Trainer-bot
//
//  Created by Roman on 18.12.2025.
//

import Vapor
import Fluent

/// Synchronizes questions from CSV files into the database.
///
/// Strategy (safe for existing sessions):
/// 1) Read CSV
/// 2) Upsert into `questions` (create or update)
/// 3) Mark missing questions as `isActive = false`
struct QuestionsSyncService {

    struct SyncReport: Sendable {
        let suite: String
        let created: Int
        let updated: Int
        let deactivated: Int
        let totalInCSV: Int
    }

    /// Sync all known suites if their CSV files exist.
    /// Missing files are skipped (useful while you bootstrap only one direction).
    static func syncAll(app: Application) async throws -> [SyncReport] {
        let candidates: [(suite: String, file: String)] = [
            ("ed", "ed.csv"),
            ("mos", "mos.csv"),
            ("ng", "ng.csv")
        ]

        var reports: [SyncReport] = []

        for item in candidates {
            do {
                let loaded = try QuestionsCSVLoader.loadSuite(app: app, suite: item.suite, fileName: item.file)
                let report = try await syncSuite(app: app, suite: item.suite, loaded: loaded)
                reports.append(report)
            } catch QuestionsCSVLoader.LoaderError.fileNotFound {
                app.logger.info("QuestionsSync: CSV for suite '\(item.suite)' not found yet (\(item.file)) — skipped")
                continue
            } catch {
                // For other errors we fail fast: invalid header/row etc.
                app.logger.error("QuestionsSync: failed to load CSV for suite '\(item.suite)': \(error)")
                throw error
            }
        }

        return reports
    }

    /// Sync a single suite from already-loaded questions.
    static func syncSuite(app: Application, suite: String, loaded: [QuestionsCSVLoader.LoadedQuestion]) async throws -> SyncReport {
        // Defensive: only keep rows for this suite.
        let csvQuestions = loaded.filter { $0.suite == suite }

        return try await app.db.transaction { db in
            // 1) Load all DB questions for suite into a dictionary by code.
            let dbAll = try await Question.query(on: db)
                .filter(\.$suite == suite)
                .all()

            var dbByCode: [String: Question] = Dictionary(uniqueKeysWithValues: dbAll.map { ($0.code, $0) })

            var created = 0
            var updated = 0
            var deactivated = 0

            // 2) Upsert CSV rows.
            for row in csvQuestions {
                if let existing = dbByCode[row.code] {
                    var needsUpdate = false

                    if existing.text != row.text {
                        existing.text = row.text
                        needsUpdate = true
                    }

                    if existing.topic != row.topic {
                        existing.topic = row.topic
                        needsUpdate = true
                    }

                    if existing.difficulty != row.difficulty {
                        existing.difficulty = row.difficulty
                        needsUpdate = true
                    }

                    if existing.isActive == false {
                        existing.isActive = true
                        needsUpdate = true
                    }

                    if needsUpdate {
                        try await existing.update(on: db)
                        updated += 1
                    }

                    // Mark as processed.
                    dbByCode.removeValue(forKey: row.code)
                } else {
                    let q = Question(
                        suite: suite,
                        code: row.code,
                        text: row.text,
                        topic: row.topic,
                        difficulty: row.difficulty,
                        isActive: true
                    )
                    try await q.create(on: db)
                    created += 1
                }
            }

            // 3) Deactivate missing questions (keep rows for history).
            for (_, old) in dbByCode {
                if old.isActive {
                    old.isActive = false
                    try await old.update(on: db)
                    deactivated += 1
                }
            }

            app.logger.info(
                "QuestionsSync: suite=\(suite) csv=\(csvQuestions.count) created=\(created) updated=\(updated) deactivated=\(deactivated)"
            )

            return SyncReport(
                suite: suite,
                created: created,
                updated: updated,
                deactivated: deactivated,
                totalInCSV: csvQuestions.count
            )
        }
    }
}
