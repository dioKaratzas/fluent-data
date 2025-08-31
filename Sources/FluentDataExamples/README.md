# FluentClient Examples - Organized Structure

This directory contains a well-organized example demonstrating how to use FluentClient with multiple databases.

## File Structure

```
Sources/FluentClientExamples/
├── CLI.swift              # Main entry point with async support
├── DatabaseID+Keys.swift     # Database ID extensions
├── Models.swift           # User and Product models
├── Migrations.swift       # Database migration definitions
├── DatabaseManager.swift  # Database setup and operations
└── README.md             # This documentation
```

## Key Features

### 1. **Database ID Extensions** (`DatabaseKeys.swift`)
```swift
extension DatabaseID {
    static let users = DatabaseID(string: "users")
    static let products = DatabaseID(string: "products")
}
```

### 2. **Default Database Configuration**
```swift
// Set a database as default during configuration
try client.configureSQLite(configuration: .init(
    id: .users, 
    url: usersURL, 
    isDefault: true
))

// Or use the convenience method (automatically sets as default)
try client.configureSQLite(url: databaseURL)

// Change default database at runtime
client.setDefaultDatabase(.products)

// Get current default database
let defaultID = client.defaultDatabaseID
```

### 3. **Separated Models** (`Models.swift`)
- `User` model with name and email fields
- `Product` model with name and price fields
- Clean, focused model definitions

### 4. **Organized Migrations** (`Migrations.swift`)
- `CreateUser` migration for users table
- `CreateProduct` migration for products table
- Each migration is self-contained

### 5. **Database Manager** (`DatabaseManager.swift`)
- Handles database configuration
- Manages migrations for each database
- Provides CRUD operations
- Handles cleanup and shutdown

### 6. **Clean CLI Entry Point** (`CLI.swift`)
- Simple, focused main function
- Demonstrates the complete workflow
- Proper error handling and cleanup

## Running the Example

```bash
swift run FluentClientExamples
```

## What the Example Demonstrates

1. **Multiple Database Setup**: Two separate SQLite databases
2. **Database ID Extensions**: Clean extension-based database ID definitions
3. **Organized Code Structure**: Separation of concerns
4. **Migration Management**: Manual migration execution per database
5. **CRUD Operations**: Create, read operations on both databases
6. **Resource Management**: Automatic cleanup and shutdown

## Benefits of This Structure

- ✅ **Maintainable**: Each component has a single responsibility
- ✅ **Reusable**: Database ID extensions and models can be easily reused
- ✅ **Testable**: Each component can be tested independently
- ✅ **Scalable**: Easy to add more databases and models
- ✅ **Clean**: Clear separation between different concerns

## Usage Pattern

This structure demonstrates a production-ready pattern for:
- Client applications using FluentClient
- Multiple database management
- Organized code architecture
- Proper resource management
