//
//  QuestionsCSVLoader.swift
//  Trainer-bot
//
//  Created by Roman on 18.12.2025.
//

import Vapor

/// Loads questions from CSV files located in `Sources/App/Resources/Questions/`.
///
/// Expected CSV header (recommended):
/// `code,topic,difficulty,text`
///
/// Only `code` and `text` are required. `topic` and `difficulty` are optional.
struct QuestionsCSVLoader {

    struct LoadedQuestion: Sendable {
        let suite: String            // "ed" | "mos" | "ng"
        let code: String             // stable code, e.g. mos_001
        let text: String
        let topic: String?
        let difficulty: Int          // default 1
    }

    enum LoaderError: Error {
        case fileNotFound(String)
        case unreadableFile(String)
        case invalidHeader(String)
        case invalidRow(String)
    }

    /// Loads a single suite CSV.
    /// - Parameters:
    ///   - suite: "ed" | "mos" | "ng"
    ///   - fileName: e.g. "mos.csv"
    static func loadSuite(app: Application, suite: String, fileName: String) throws -> [LoadedQuestion] {
        let path = app.directory.resourcesDirectory + "Questions/" + fileName
        return try loadCSV(app: app, suite: suite, path: path)
    }

    /// Loads all suites using conventional filenames: `ed.csv`, `mos.csv`, `ng.csv`.
    static func loadAll(app: Application) throws -> [LoadedQuestion] {
        var result: [LoadedQuestion] = []
        result.append(contentsOf: try loadSuite(app: app, suite: "ed", fileName: "ed.csv"))
        result.append(contentsOf: try loadSuite(app: app, suite: "mos", fileName: "mos.csv"))
        result.append(contentsOf: try loadSuite(app: app, suite: "ng", fileName: "ng.csv"))
        return result
    }

    // MARK: - Internals

    private static func loadCSV(app: Application, suite: String, path: String) throws -> [LoadedQuestion] {
        let fileURL = URL(fileURLWithPath: path)

        guard FileManager.default.fileExists(atPath: path) else {
            throw LoaderError.fileNotFound(path)
        }

        guard let data = try? Data(contentsOf: fileURL),
              var content = String(data: data, encoding: .utf8) else {
            throw LoaderError.unreadableFile(path)
        }

        // Strip UTF-8 BOM if present.
        if content.hasPrefix("\u{feff}") {
            content.removeFirst()
        }

        let lines = content
            .split(whereSeparator: \.isNewline)
            .map { String($0) }

        guard let headerLine = lines.first else {
            return []
        }

        let header = parseCSVLine(headerLine)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        // Accept either full header or minimal header.
        // Required columns: code, text
        guard let codeIdx = header.firstIndex(of: "code") else {
            throw LoaderError.invalidHeader("Missing 'code' column in: \(path)")
        }
        guard let textIdx = header.firstIndex(of: "text") else {
            throw LoaderError.invalidHeader("Missing 'text' column in: \(path)")
        }

        let topicIdx = header.firstIndex(of: "topic")
        let difficultyIdx = header.firstIndex(of: "difficulty")

        var out: [LoadedQuestion] = []
        out.reserveCapacity(max(0, lines.count - 1))

        for (i, line) in lines.dropFirst().enumerated() {
            // Skip empty lines.
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }

            let cols = parseCSVLine(line)

            // Guard required columns existence in this row.
            guard codeIdx < cols.count, textIdx < cols.count else {
                throw LoaderError.invalidRow("Row \(i + 2) has not enough columns in: \(path)")
            }

            let code = cols[codeIdx].trimmingCharacters(in: .whitespacesAndNewlines)
            let text = cols[textIdx].trimmingCharacters(in: .whitespacesAndNewlines)

            guard !code.isEmpty else {
                throw LoaderError.invalidRow("Row \(i + 2) has empty 'code' in: \(path)")
            }
            guard !text.isEmpty else {
                throw LoaderError.invalidRow("Row \(i + 2) has empty 'text' for code '\(code)' in: \(path)")
            }

            let topic: String?
            if let idx = topicIdx, idx < cols.count {
                let t = cols[idx].trimmingCharacters(in: .whitespacesAndNewlines)
                topic = t.isEmpty ? nil : t
            } else {
                topic = nil
            }

            let difficulty: Int
            if let idx = difficultyIdx, idx < cols.count {
                let raw = cols[idx]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()

                switch raw {
                case "1", "базовый":
                    difficulty = 1
                case "2", "рабочий":
                    difficulty = 2
                case "3", "сложный":
                    difficulty = 3
                default:
                    difficulty = 1
                }
            } else {
                difficulty = 1
            }

            out.append(.init(suite: suite, code: code, text: text, topic: topic, difficulty: difficulty))
        }

        app.logger.info("QuestionsCSVLoader: loaded \(out.count) questions from \(path)")
        return out
    }

    /// Minimal CSV parser supporting quoted fields and commas inside quotes.
    /// Handles escaping of quotes by doubling them: "" -> ".
    private static func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        result.reserveCapacity(8)

        var current = ""
        var inQuotes = false
        var i = line.startIndex

        while i < line.endIndex {
            let ch = line[i]

            if ch == "\"" {
                if inQuotes {
                    // If next is also quote -> escaped quote.
                    let next = line.index(after: i)
                    if next < line.endIndex, line[next] == "\"" {
                        current.append("\"")
                        i = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    inQuotes = true
                }
            } else if ch == "," && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(ch)
            }

            i = line.index(after: i)
        }

        result.append(current)
        return result
    }
}
