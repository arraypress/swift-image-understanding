# Swift Image Understanding

A Swift library for asking Apple's on-device foundation model about images — describe, answer questions, and extract structured JSON. No API key, no network: images never leave the machine.

This is the **understanding** half of reading images. For verbatim OCR, tables kept as tables, and PDFs, [swift-document-reader](https://github.com/arraypress/swift-document-reader) is faster and deterministic — this library is for what OCR can't do: "what is this?", "what's the total?", "which option is selected?".

## Features

- 🎯 **Simple API** — one async call per question
- 💬 **Visual Q&A** — ask anything about a local image
- 📝 **Describe & read** — general description, or transcribe visible text
- 🧱 **Structured extraction** — shape the output with a **runtime JSON Schema**; generation is constrained, so the result always parses and always fits
- 🔒 **On-device** — Apple's model, nothing uploaded, works offline
- 🛡️ **Typed error handling** — model availability, bad files, bad schemas and guardrails all get precise errors
- ⚡ **Async/await** native

## Requirements

- macOS 27.0+ / iOS 27.0+ / visionOS 27.0+ / watchOS 27.0+ to run (no tvOS — FoundationModels image input is unavailable there)
- Apple Intelligence enabled
- Swift 6.2+ / Xcode 27.0+

The package itself declares 26 floors so an app or tool that links it still runs on 26: `ImageUnderstanding` is
`@available(macOS 27, …)`, so check `#available(macOS 27, *)` before calling it (`vid analyze` skips its shot
descriptions on 26 that way).

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/arraypress/swift-image-understanding.git", from: "0.1.0")
]
```

## Usage

### Ask

```swift
import ImageUnderstanding

let answer = try await ImageUnderstanding.ask(
    "screenshot.png",
    "What application is shown, and what went wrong?"
)
```

### Describe and read

```swift
let description = try await ImageUnderstanding.describe("photo.jpg")
let text = try await ImageUnderstanding.readText("sign.jpg")   // quick reads; use document-reader for OCR at scale
```

### Structured extraction

```swift
let schema = """
{"type": "object", "title": "Receipt",
 "properties": {
   "merchant": {"type": "string"},
   "total": {"type": "number"},
   "date": {"type": "string", "description": "ISO 8601"}},
 "required": ["merchant", "total", "date"]}
"""
let json = try await ImageUnderstanding.extract("receipt.jpg", schemaJSON: schema)
```

Supported schema subset: `object`, `array`, `string`, `number`, `integer`, `boolean`, plus `required`, `description`, `minItems`/`maxItems`. A string `enum` becomes strong guidance.

**Mark fields `required` when the value should always be found** — the on-device model fills required fields reliably and skips optional ones readily. And a specific prompt ("line 1 is the label, line 2 the pack name") measurably beats the generic default.

### Availability

```swift
guard ImageUnderstanding.isAvailable else { ... }   // Apple Intelligence off, unsupported hardware, or model still downloading
```

## Error Handling

```swift
do {
    let answer = try await ImageUnderstanding.ask(path, question)
} catch ImageUnderstandingError.modelUnavailable(let reason) {
    // Apple Intelligence off / unsupported / downloading
} catch ImageUnderstandingError.guardrailViolation {
    // the model declined under its safety rules
}
```

## License

MIT
