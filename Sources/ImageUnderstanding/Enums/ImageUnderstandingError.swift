//
//  ImageUnderstandingError.swift
//  ImageUnderstanding
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Every way asking the model about an image can fail, with a message worth
/// showing a person.
public enum ImageUnderstandingError: Error, LocalizedError {

    /// The on-device model can't run — Apple Intelligence is off, the device
    /// doesn't support it, or the model assets haven't downloaded yet.
    case modelUnavailable(String)

    /// The path does not exist.
    case fileNotFound(String)

    /// The file exists but isn't a decodable image.
    case notAnImage(String)

    /// The extraction schema couldn't be understood. The string names the
    /// exact problem — an unknown type, a missing `properties`.
    case invalidSchema(String)

    /// The model declined the request under its safety rules.
    case guardrailViolation

    /// The model failed for another reason. The string is the underlying
    /// error's description, kept for the log rather than the user.
    case generationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .modelUnavailable(let reason):
            return "The on-device model isn't available: \(reason)"
        case .fileNotFound(let path):
            return "No such file: \(path)"
        case .notAnImage(let path):
            return "Not a decodable image: \(path). Supported formats include PNG, JPEG, HEIC and TIFF."
        case .invalidSchema(let detail):
            return "Invalid extraction schema: \(detail)"
        case .guardrailViolation:
            return "The model declined this request under its safety rules."
        case .generationFailed(let reason):
            return "Generation failed: \(reason)"
        }
    }
}
