<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://github.com/user-attachments/assets/afdf6b1e-74c8-4471-b470-78f4f8a540ce">
    <source media="(prefers-color-scheme: light)" srcset="https://github.com/user-attachments/assets/b952ef03-08f7-4720-b4d6-388012c377e7">
    <img src="https://github.com/user-attachments/assets/b952ef03-08f7-4720-b4d6-388012c377e7" height="96" alt="Logo">
  </picture>
  <br><br>
</p>

FluentData is a client-compatible Fluent ORM for Swift with SQLCipher encryption, multiple database support, query history, and async/await. Designed for iOS, macOS, watchOS, and tvOS.

## What is FluentData?
FluentData brings Vapor's Fluent-style ORM to client apps. It adapts Fluent patterns for use without server lifecycle dependencies while maintaining a familiar API surface and strong interoperability with the Fluent ecosystem.

- Built on the Fluent family
- Works entirely on the client (no server runtime required)
- Clean integration with SQLite and optional SQLCipher encryption

## Features
- Multiple databases with `DatabaseID` extensions
- SQLCipher encryption (password or data key)
- Query history for debugging/observability
- Async/await throughout (no EventLoopFuture in public API)
- Thread-safe configuration and access
- Automatic resource cleanup

## Platform Support
- iOS 13+
- macOS 10.15+
- watchOS 6+
- tvOS 13+

## Installation

### Swift Package Manager
Add to your `Package.swift`:
```swift
.dependencies = [
    .package(url: "https://github.com/dioKaratzas/fluent-data.git", from: "1.0.0")
]
```

### Enabling SQLCipher Encryption
- Encryption support is provided via a SwiftPM package trait named “SQLCipher”.
- When this trait is enabled, encryption APIs are available and the library links against the SQLCipher-enabled SQLite driver.
- If the trait is not enabled, the library builds without encryption APIs and uses regular SQLite.
- Swift 5.9+ is fully supported. Enabling the “SQLCipher” trait requires Swift 6.2+ (SwiftPM traits).

> Note: If you don’t enable the “SQLCipher” trait, skip the encryption examples below.

## Quick Start
```swift
import FluentData
import Logging

let client = FluentData(logger: Logger(label: "app"))

// Configure SQLite (default database)
try await client.configureSQLite(url: databaseURL)

// Migrations
client.migrations.add(CreateUser())
try await client.autoMigrate()

// Use database
let users = try await User.query(on: client.db).all()
```

## Multiple Databases
```swift
extension DatabaseID {
    static let users = DatabaseID(string: "users")
    static let products = DatabaseID(string: "products")
}

try await client.configureSQLite(configuration: .init(id: .users, url: usersURL, isDefault: true))
try await client.configureSQLite(configuration: .init(id: .products, url: productsURL))

let user = try await User.query(on: client.db(.users)).first()
let product = try await Product.query(on: client.db(.products)).first()
```

## Pagination
```swift
// Limit pages globally (nil = no limit)
client.pageSizeLimit = PageLimit(100)
// or
client.pageSizeLimit = .noLimit
```

## Connection Configuration Hook
```swift
// Run per-connection setup (e.g. pragmas) during configuration
let configuration = FluentDataConfiguration(
    id: .main,
    url: databaseURL,
    configureConnection: { connection, _ in
        connection.query("PRAGMA journal_mode=WAL").map { _ in () }
    }
)
try await client.configureSQLite(configuration: configuration)
```

## Encryption (SQLCipher)

The following requires the “SQLCipher” package trait to be enabled (see Installation):

```swift
// Password-based encryption
let configuration = FluentDataConfiguration(
    id: .main, 
    url: databaseURL, 
    encryption: .password("secret")
)
try await client.configureSQLite(configuration: configuration)

// Change passphrase
try await client.changePassphrase(for: .main, newEncryption: .password("new-secret"))
```

## Query History (Debug)
```swift
client.historyEnabled = true
// ... run queries ...
let queries = client.history
client.clearHistory()
```

## Observability (Roadmap)
We are designing a shared observability layer:

- Name: FluentDataObservability
- Scope: usable from both FluentData (client) and Fluent (server with Vapor)
- Implementation: SQLite hook–based instrumentation
- Goals: query timings, connection stats, lightweight tracing

## License
MIT. See `LICENSE`.
