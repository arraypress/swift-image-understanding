//
//  ImageUnderstanding.swift
//  ImageUnderstanding
//
//  Created by David Sherlock on 2026.
//
//  Ask Apple's on-device model about images: describe, answer questions, and
//  extract structured JSON — offline, keyless, nothing uploaded.
//
//  ```swift
//  let answer = try await ImageUnderstanding.ask("screenshot.png", "What error is shown?")
//  let json = try await ImageUnderstanding.extract("receipt.jpg", schemaJSON: schema)
//  ```
//

import Foundation
import FoundationModels
import ImageIO

/// On-device visual question answering for local image files.
///
/// Wraps the FoundationModels framework's image input with the pieces a
/// caller otherwise writes every time: availability mapped to a typed error,
/// image validation before the model sees the file, structured extraction
/// from a runtime JSON Schema instead of a compile-time type, and one call
/// per question.
///
/// This is the *understanding* half of reading images. For verbatim OCR and
/// table structure, Vision's document reader (swift-document-reader) is
/// faster and deterministic — this library is for what OCR can't do: "what
/// is this?", "what's the total?", "which of these is selected?".
public enum ImageUnderstanding {

    /// Whether the on-device model can run right now.
    ///
    /// `false` means ``ask(_:_:instructions:)`` will throw
    /// ``ImageUnderstandingError/modelUnavailable(_:)`` — Apple Intelligence
    /// is off, unsupported hardware, or the model is still downloading.
    public static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    // MARK: - Ask

    /// Asks a question about an image.
    ///
    /// ```swift
    /// let answer = try await ImageUnderstanding.ask(
    ///     "~/Desktop/screenshot.png",
    ///     "What application is shown, and what state is it in?"
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - path: The image file. Tilde is expanded.
    ///   - prompt: What to ask.
    ///   - instructions: Optional system-level guidance, e.g. a persona or
    ///     an output-format rule.
    /// - Returns: The model's answer.
    public static func ask(
        _ path: String,
        _ prompt: String,
        instructions: String? = nil
    ) async throws -> String {
        try await ask(url: try validated(path), prompt: prompt, instructions: instructions)
    }

    /// Asks a question about an image at a URL.
    public static func ask(
        url: URL,
        prompt: String,
        instructions: String? = nil
    ) async throws -> String {
        try checkAvailability()
        let session = makeSession(instructions: instructions)
        do {
            let response = try await session.respond {
                prompt
                Attachment(imageURL: url)
            }
            return response.content
        } catch {
            throw translate(error)
        }
    }

    // MARK: - Describe

    /// Describes an image — ``ask(_:_:instructions:)`` with a general prompt.
    public static func describe(_ path: String) async throws -> String {
        try await ask(
            path,
            "Describe this image: the main subject, the setting, notable details, and any visible text."
        )
    }

    // MARK: - Read

    /// Transcribes the text visible in an image.
    ///
    /// A convenience for quick reads. For verbatim OCR at scale, tables, or
    /// PDFs, Vision's document reader is faster and deterministic — this
    /// goes through the language model, which can occasionally paraphrase.
    public static func readText(_ path: String) async throws -> String {
        try await ask(
            path,
            "Transcribe all text visible in this image, verbatim, preserving line breaks. Output only the transcribed text."
        )
    }

    // MARK: - Extract

    /// Extracts structured data from an image, shaped by a JSON Schema.
    ///
    /// The schema constrains generation itself — the model cannot produce
    /// JSON that doesn't fit it. Supported subset: `object`, `array`,
    /// `string`, `number`, `integer`, `boolean`, with `required`,
    /// `description`, `minItems`/`maxItems`; a string `enum` becomes strong
    /// guidance in the description.
    ///
    /// Mark fields `required` when the value should always be found: the
    /// on-device model fills required fields reliably and skips optional
    /// ones readily. Keep optional only what is genuinely sometimes absent.
    ///
    /// ```swift
    /// let schema = """
    /// {"type": "object", "title": "Receipt",
    ///  "properties": {
    ///    "merchant": {"type": "string"},
    ///    "total": {"type": "number"},
    ///    "date": {"type": "string", "description": "ISO 8601"}},
    ///  "required": ["merchant", "total"]}
    /// """
    /// let json = try await ImageUnderstanding.extract("receipt.jpg", schemaJSON: schema)
    /// ```
    ///
    /// - Parameters:
    ///   - path: The image file. Tilde is expanded.
    ///   - schemaJSON: A JSON Schema document describing the output shape.
    ///   - prompt: What to extract. Defaults to a generic instruction; a
    ///     specific one ("the line items and total") always does better.
    /// - Returns: A JSON string conforming to the schema.
    public static func extract(
        _ path: String,
        schemaJSON: String,
        prompt: String? = nil
    ) async throws -> String {
        try await extract(url: try validated(path), schemaJSON: schemaJSON, prompt: prompt)
    }

    /// Extracts structured data from an image at a URL.
    public static func extract(
        url: URL,
        schemaJSON: String,
        prompt: String? = nil
    ) async throws -> String {
        try checkAvailability()
        let schema = try SchemaBuilder.schema(fromJSON: schemaJSON)
        let session = makeSession(instructions: nil)
        do {
            let response = try await session.respond(
                to: Prompt {
                    prompt ?? "Extract the requested information from this image."
                    Attachment(imageURL: url)
                },
                schema: schema
            )
            return response.content.jsonString
        } catch let error as ImageUnderstandingError {
            throw error
        } catch {
            throw translate(error)
        }
    }

    // MARK: - Internals

    private static func makeSession(instructions: String?) -> LanguageModelSession {
        if let instructions {
            return LanguageModelSession(instructions: instructions)
        }
        return LanguageModelSession()
    }

    private static func checkAvailability() throws {
        if case .unavailable(let reason) = SystemLanguageModel.default.availability {
            throw ImageUnderstandingError.modelUnavailable(String(describing: reason))
        }
    }

    /// Confirms the path exists and decodes as an image, so the caller gets
    /// a precise error instead of the model's generic one.
    private static func validated(_ path: String) throws -> URL {
        let expanded = (path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expanded) else {
            throw ImageUnderstandingError.fileNotFound(path)
        }
        let url = URL(fileURLWithPath: expanded)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0 else {
            throw ImageUnderstandingError.notAnImage(path)
        }
        return url
    }

    private static func translate(_ error: Error) -> ImageUnderstandingError {
        if case LanguageModelError.guardrailViolation = error {
            return .guardrailViolation
        }
        return .generationFailed((error as? LocalizedError)?.errorDescription ?? String(describing: error))
    }
}
