//
//  SchemaBuilder.swift
//  ImageUnderstanding
//
//  Created by David Sherlock on 2026.
//
//  Turns a JSON Schema document into the framework's DynamicGenerationSchema,
//  so a caller can define an extraction shape in a plain file at runtime
//  rather than a @Generable type at compile time.
//

import Foundation
import FoundationModels

enum SchemaBuilder {

    /// Builds a constrained-generation schema from a JSON Schema document.
    ///
    /// The supported subset is the part of JSON Schema that maps onto guided
    /// generation: `object` (with `properties`, `required`, `title`,
    /// `description`), `array` (with `items`, `minItems`, `maxItems`), and
    /// the `string` / `number` / `integer` / `boolean` leaves. An `enum` on a
    /// string is folded into the description — the model treats it as strong
    /// guidance rather than a hard constraint.
    ///
    /// - Parameter json: A JSON Schema document.
    /// - Returns: The framework schema to pass to `respond(to:schema:)`.
    /// - Throws: ``ImageUnderstandingError/invalidSchema(_:)`` naming what
    ///   was wrong.
    static func schema(fromJSON json: String) throws -> GenerationSchema {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let root = object as? [String: Any] else {
            throw ImageUnderstandingError.invalidSchema("not a JSON object")
        }
        let dynamic = try build(root, name: (root["title"] as? String) ?? "Result")
        do {
            return try GenerationSchema(root: dynamic, dependencies: [])
        } catch {
            throw ImageUnderstandingError.invalidSchema(String(describing: error))
        }
    }

    // MARK: Recursion

    private static func build(_ node: [String: Any], name: String) throws -> DynamicGenerationSchema {
        let description = describe(node)

        switch node["type"] as? String {
        case "object":
            guard let properties = node["properties"] as? [String: [String: Any]] else {
                throw ImageUnderstandingError.invalidSchema("object \"\(name)\" has no properties")
            }
            let required = Set(node["required"] as? [String] ?? [])
            // Sorted for a deterministic property order — schema identity
            // should not depend on dictionary iteration.
            let built = try properties.sorted { $0.key < $1.key }.map { key, value in
                DynamicGenerationSchema.Property(
                    name: key,
                    description: describe(value),
                    schema: try build(value, name: key),
                    isOptional: !required.contains(key)
                )
            }
            return DynamicGenerationSchema(name: name, description: description, properties: built)

        case "array":
            guard let items = node["items"] as? [String: Any] else {
                throw ImageUnderstandingError.invalidSchema("array \"\(name)\" has no items")
            }
            return DynamicGenerationSchema(
                arrayOf: try build(items, name: name),
                minimumElements: node["minItems"] as? Int,
                maximumElements: node["maxItems"] as? Int
            )

        case "string":
            return DynamicGenerationSchema(type: String.self)
        case "number":
            return DynamicGenerationSchema(type: Double.self)
        case "integer":
            return DynamicGenerationSchema(type: Int.self)
        case "boolean":
            return DynamicGenerationSchema(type: Bool.self)

        case let other:
            throw ImageUnderstandingError.invalidSchema(
                "\"\(name)\" has type \(other.map { "\"\($0)\"" } ?? "missing"); supported: object, array, string, number, integer, boolean"
            )
        }
    }

    /// A node's description, with any `enum` folded in as guidance.
    private static func describe(_ node: [String: Any]) -> String? {
        let description = node["description"] as? String
        guard let values = node["enum"] as? [Any], !values.isEmpty else { return description }
        let list = "One of: " + values.map { "\($0)" }.joined(separator: ", ")
        return description.map { "\($0). \(list)" } ?? list
    }
}
