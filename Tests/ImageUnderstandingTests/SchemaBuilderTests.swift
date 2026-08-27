//
//  SchemaBuilderTests.swift
//  ImageUnderstanding
//
//  Created by David Sherlock on 2026.
//
//  Schema construction is pure and offline, so it tests hermetically — no
//  model, no Apple Intelligence requirement.
//

import Testing
@testable import ImageUnderstanding

struct SchemaBuilderTests {

    @Test func receiptShapeBuilds() throws {
        let schema = """
        {"type": "object", "title": "Receipt",
         "properties": {
           "merchant": {"type": "string"},
           "total": {"type": "number", "description": "Grand total"},
           "items": {"type": "array", "minItems": 1,
                     "items": {"type": "object", "properties": {
                        "name": {"type": "string"},
                        "price": {"type": "number"}},
                        "required": ["name"]}}},
         "required": ["merchant", "total"]}
        """
        #expect(throws: Never.self) { try SchemaBuilder.schema(fromJSON: schema) }
    }

    @Test func leavesBuild() throws {
        for type in ["string", "number", "integer", "boolean"] {
            let schema = """
            {"type": "object", "properties": {"value": {"type": "\(type)"}}}
            """
            #expect(throws: Never.self) { try SchemaBuilder.schema(fromJSON: schema) }
        }
    }

    @Test func notJSONIsRejected() {
        #expect(throws: ImageUnderstandingError.self) {
            try SchemaBuilder.schema(fromJSON: "not json at all")
        }
    }

    @Test func unknownTypeIsNamedInTheError() {
        do {
            _ = try SchemaBuilder.schema(fromJSON: """
            {"type": "object", "properties": {"when": {"type": "date"}}}
            """)
            Issue.record("expected invalidSchema")
        } catch let ImageUnderstandingError.invalidSchema(detail) {
            #expect(detail.contains("date"))
            #expect(detail.contains("when"))
        } catch {
            Issue.record("wrong error: \(error)")
        }
    }

    @Test func objectWithoutPropertiesIsRejected() {
        #expect(throws: ImageUnderstandingError.self) {
            try SchemaBuilder.schema(fromJSON: #"{"type": "object"}"#)
        }
    }

    @Test func arrayWithoutItemsIsRejected() {
        #expect(throws: ImageUnderstandingError.self) {
            try SchemaBuilder.schema(fromJSON: """
            {"type": "object", "properties": {"list": {"type": "array"}}}
            """)
        }
    }
}
