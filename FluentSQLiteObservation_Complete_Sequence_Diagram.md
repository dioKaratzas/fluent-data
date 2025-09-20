# FluentSQLiteObservation - Complete System Sequence Diagram

This diagram shows the complete flow of the FluentSQLiteObservation system when fully implemented, based on GRDB's proven patterns.

## 🚀 Phase 1: Database Connection & Observer Setup

```mermaid
sequenceDiagram
    participant User
    participant FluentValueObservation
    participant FluentValueObserver
    participant ConnectionObservationRegistry
    participant DatabaseObservationBroker
    participant StatementAuthorizer
    participant SQLiteConnection
    participant TransactionObserverRegistry

    Note over User,TransactionObserverRegistry: 1. OBSERVATION SETUP PHASE

    User->>FluentValueObservation: ValueObservation.tracking { db in User.query(on: db).all() }
    FluentValueObservation-->>User: observation instance

    User->>FluentValueObservation: observation.start(in: database, onChange: { users in ... })
    
    FluentValueObservation->>FluentValueObservation: fetchWithRegionDiscovery(database)
    FluentValueObservation->>ConnectionObservationRegistry: broker(for: connection)
    ConnectionObservationRegistry->>DatabaseObservationBroker: installBrokerIfNeeded(connection)
    
    alt First time setup
        DatabaseObservationBroker->>StatementAuthorizer: init(connection)
        StatementAuthorizer->>SQLiteConnection: sqlite3_set_authorizer(baseCallback)
        Note right of StatementAuthorizer: Permanent base authorizer prevents statement invalidation
        
        DatabaseObservationBroker->>SQLiteConnection: sqlite3_commit_hook(commitCallback)
        DatabaseObservationBroker->>SQLiteConnection: sqlite3_rollback_hook(rollbackCallback)
        Note right of DatabaseObservationBroker: Commit/rollback hooks installed permanently
    end

    FluentValueObservation->>DatabaseObservationBroker: withRegionTracking { fetch() }
    DatabaseObservationBroker->>StatementAuthorizer: withRegionTracking { ... }
    
    StatementAuthorizer->>SQLiteConnection: withAuthorizerObserver { SELECT * FROM users }
    SQLiteConnection->>StatementAuthorizer: authorize(SQLITE_READ, "users", "id")
    SQLiteConnection->>StatementAuthorizer: authorize(SQLITE_READ, "users", "name")
    StatementAuthorizer->>StatementAuthorizer: selectedRegion.formUnion(users.id, users.name)
    
    SQLiteConnection-->>StatementAuthorizer: query results: [User(Alice), User(Bob)]
    StatementAuthorizer-->>DatabaseObservationBroker: (users, DatabaseRegion(users: [id,name]))
    DatabaseObservationBroker-->>FluentValueObservation: (users, region)

    FluentValueObservation->>FluentValueObserver: init(database, fetch, onChange, region)
    FluentValueObservation->>User: onChange([Alice, Bob]) // Initial value
    
    FluentValueObservation->>ConnectionObservationRegistry: addObserver(fluentValueObserver)
    ConnectionObservationRegistry->>TransactionObserverRegistry: addObserver(fluentValueObserver)
    
    alt First observer added
        TransactionObserverRegistry->>ConnectionObservationRegistry: onObservationShouldStart()
        ConnectionObservationRegistry->>DatabaseObservationBroker: installHooks()
        Note right of DatabaseObservationBroker: Update hook NOT installed yet (no active statements)
    end

    FluentValueObservation-->>User: FluentObservationCancellable
```

## 📝 Phase 2: Database Change Detection & Event Processing

```mermaid
sequenceDiagram
    participant User
    participant SQLiteConnection
    participant StatementAuthorizer
    participant DatabaseObservationBroker
    participant SavepointStack
    participant TransactionObservation
    participant FluentValueObserver

    Note over User,FluentValueObserver: 2. DATABASE CHANGE DETECTION PHASE

    User->>SQLiteConnection: execute("INSERT INTO users (name) VALUES ('Charlie')")
    
    SQLiteConnection->>DatabaseObservationBroker: statementWillExecute(statement)
    DatabaseObservationBroker->>DatabaseObservationBroker: Create statementObservations from interested observers
    
    loop For each TransactionObservation
        DatabaseObservationBroker->>TransactionObservation: observes(eventsOfKind: .insert("users"))
        TransactionObservation->>FluentValueObserver: observes(operation: .insert("users"))
        FluentValueObserver->>FluentValueObserver: observedRegion.isModified(by: .insert("users"))
        FluentValueObserver-->>TransactionObservation: true (interested)
        TransactionObservation-->>DatabaseObservationBroker: true
    end
    
    DatabaseObservationBroker->>DatabaseObservationBroker: statementObservations = [interested observers]
    
    alt First time observers exist
        DatabaseObservationBroker->>SQLiteConnection: installUpdateHook()
        Note right of DatabaseObservationBroker: Update hook installed dynamically when needed
    end

    SQLiteConnection->>StatementAuthorizer: authorize(SQLITE_INSERT, "users", NULL)
    StatementAuthorizer->>StatementAuthorizer: eventKinds.append(.insert("users"))
    
    SQLiteConnection->>SQLiteConnection: sqlite3_step() // Execute INSERT
    SQLiteConnection->>DatabaseObservationBroker: sqlite3_update_hook(INSERT, "users", rowID: 3)
    
    DatabaseObservationBroker->>DatabaseObservationBroker: databaseDidChange(DatabaseEvent(.insert, "users", 3))
    
    alt No active savepoints
        DatabaseObservationBroker->>SavepointStack: isEmpty
        SavepointStack-->>DatabaseObservationBroker: true
        
        loop For each interested StatementObservation
            DatabaseObservationBroker->>TransactionObservation: databaseDidChange(with: event)
            TransactionObservation->>FluentValueObserver: databaseDidChange(with: event)
            FluentValueObserver->>FluentValueObserver: isModified = true
            FluentValueObserver->>FluentValueObserver: stopObservingDatabaseChangesUntilNextTransaction()
            Note right of FluentValueObserver: Efficiency: stop processing further events this transaction
        end
    else Active savepoints
        DatabaseObservationBroker->>SavepointStack: eventsBuffer.append((event, statementObservations))
        Note right of SavepointStack: Events buffered until savepoint released
    end

    SQLiteConnection-->>DatabaseObservationBroker: statement execution complete
    DatabaseObservationBroker->>DatabaseObservationBroker: statementDidExecute(statement)
    DatabaseObservationBroker->>DatabaseObservationBroker: statementObservations = [] // Clear for next statement
```

## 🔄 Phase 3: Transaction Commit & Observer Notification

```mermaid
sequenceDiagram
    participant SQLiteConnection
    participant DatabaseObservationBroker
    participant SavepointStack
    participant TransactionObservation
    participant FluentValueObserver
    participant User

    Note over SQLiteConnection,User: 3. TRANSACTION COMMIT & NOTIFICATION PHASE

    SQLiteConnection->>DatabaseObservationBroker: sqlite3_commit_hook()
    DatabaseObservationBroker->>DatabaseObservationBroker: databaseWillCommit()
    
    alt Process buffered events
        DatabaseObservationBroker->>SavepointStack: notifyBufferedEvents()
        SavepointStack->>SavepointStack: Process eventsBuffer
        loop For each buffered (event, statementObservations)
            SavepointStack->>TransactionObservation: databaseDidChange(with: event)
            TransactionObservation->>FluentValueObserver: databaseDidChange(with: event)
            FluentValueObserver->>FluentValueObserver: isModified = true
        end
        SavepointStack->>SavepointStack: eventsBuffer.removeAll()
    end

    loop For each TransactionObservation
        DatabaseObservationBroker->>TransactionObservation: databaseWillCommit()
        TransactionObservation->>FluentValueObserver: databaseWillCommit()
        FluentValueObserver-->>TransactionObservation: success (or throw to cancel)
        TransactionObservation-->>DatabaseObservationBroker: success
    end

    DatabaseObservationBroker-->>SQLiteConnection: 0 (allow commit)
    SQLiteConnection->>SQLiteConnection: COMMIT TRANSACTION

    SQLiteConnection->>DatabaseObservationBroker: statementDidExecute(COMMIT)
    DatabaseObservationBroker->>DatabaseObservationBroker: databaseDidCommit()
    DatabaseObservationBroker->>SavepointStack: clear()

    loop For each TransactionObservation
        DatabaseObservationBroker->>TransactionObservation: databaseDidCommit(database)
        TransactionObservation->>FluentValueObserver: databaseDidCommit()
        
        FluentValueObserver->>FluentValueObserver: guard isModified else { return }
        Note right of FluentValueObserver: KEY OPTIMIZATION: Only re-fetch if changes occurred
        
        FluentValueObserver->>FluentValueObserver: isModified = false // Reset for next transaction
        
        FluentValueObserver->>FluentValueObserver: fetch(database) // Re-execute query
        FluentValueObserver->>FluentValueObserver: newUsers = [Alice, Bob, Charlie]
        FluentValueObserver->>User: onChange([Alice, Bob, Charlie])
        Note right of User: User receives updated data
    end

    DatabaseObservationBroker->>DatabaseObservationBroker: databaseDidEndTransaction()
    DatabaseObservationBroker->>DatabaseObservationBroker: Re-enable all observers for next transaction
```

## 🏗 Phase 4: Savepoint Handling (Nested Transactions)

```mermaid
sequenceDiagram
    participant User
    participant SQLiteConnection
    participant DatabaseObservationBroker
    participant SavepointStack
    participant FluentValueObserver

    Note over User,FluentValueObserver: 4. SAVEPOINT HANDLING PHASE

    User->>SQLiteConnection: BEGIN TRANSACTION
    User->>SQLiteConnection: INSERT INTO users (name) VALUES ('David')
    Note right of SQLiteConnection: Event processed immediately (no savepoints)
    
    User->>SQLiteConnection: SAVEPOINT sp1
    SQLiteConnection->>DatabaseObservationBroker: statementDidExecute(SAVEPOINT sp1)
    DatabaseObservationBroker->>SavepointStack: savepointDidBegin("sp1")
    SavepointStack->>SavepointStack: savepoints.append(("sp1", eventsBuffer.count))
    SavepointStack->>SavepointStack: isEmpty = false

    User->>SQLiteConnection: INSERT INTO users (name) VALUES ('Eve')
    SQLiteConnection->>DatabaseObservationBroker: sqlite3_update_hook(INSERT, "users", 5)
    DatabaseObservationBroker->>SavepointStack: isEmpty
    SavepointStack-->>DatabaseObservationBroker: false (savepoint active)
    
    DatabaseObservationBroker->>SavepointStack: eventsBuffer.append((event, statementObservations))
    Note right of SavepointStack: Event BUFFERED, observers NOT notified yet

    User->>SQLiteConnection: ROLLBACK TO sp1
    SQLiteConnection->>DatabaseObservationBroker: statementDidExecute(ROLLBACK TO sp1)
    DatabaseObservationBroker->>SavepointStack: savepointDidRollback("sp1")
    SavepointStack->>SavepointStack: Remove events after sp1 index
    SavepointStack->>SavepointStack: eventsBuffer.removeLast() // Eve's insert discarded
    Note right of SavepointStack: Rollback discards buffered events

    User->>SQLiteConnection: COMMIT
    SQLiteConnection->>DatabaseObservationBroker: sqlite3_commit_hook()
    DatabaseObservationBroker->>SavepointStack: notifyBufferedEvents()
    SavepointStack->>SavepointStack: eventsBuffer is empty (Eve's event was discarded)
    
    DatabaseObservationBroker->>FluentValueObserver: databaseDidCommit()
    FluentValueObserver->>FluentValueObserver: isModified = true (from David's insert)
    FluentValueObserver->>User: onChange([Alice, Bob, Charlie, David])
    Note right of User: Only David appears, Eve was rolled back
```

## 🧹 Phase 5: Observer Cleanup & Resource Management

```mermaid
sequenceDiagram
    participant User
    participant FluentObservationCancellable
    participant ConnectionObservationRegistry
    participant TransactionObserverRegistry
    participant DatabaseObservationBroker
    participant SQLiteConnection

    Note over User,SQLiteConnection: 5. CLEANUP & RESOURCE MANAGEMENT PHASE

    User->>FluentObservationCancellable: cancellable.cancel()
    FluentObservationCancellable->>ConnectionObservationRegistry: removeObserver(fluentValueObserver)
    ConnectionObservationRegistry->>TransactionObserverRegistry: removeObserver(fluentValueObserver)
    
    alt Last observer removed
        TransactionObserverRegistry->>ConnectionObservationRegistry: onObservationShouldStop()
        ConnectionObservationRegistry->>DatabaseObservationBroker: removeBrokerHooks()
        DatabaseObservationBroker->>SQLiteConnection: sqlite3_update_hook(NULL, NULL)
        Note right of DatabaseObservationBroker: Update hook removed when no observers
        Note right of DatabaseObservationBroker: Commit/rollback hooks remain (lightweight)
    end

    alt Connection closing
        User->>SQLiteConnection: connection.close()
        ConnectionObservationRegistry->>ConnectionObservationRegistry: cleanup()
        ConnectionObservationRegistry->>DatabaseObservationBroker: removeHooks()
        DatabaseObservationBroker->>SQLiteConnection: Remove all hooks
        ConnectionObservationRegistry->>ConnectionObservationRegistry: Remove broker from registry
    end
```

## 🎯 Key Performance Optimizations

### ✅ **Efficient Change Detection**
1. **`observes(eventsOfKind:)`** - Called once per statement to filter interested observers
2. **`isModified` flag** - Only re-fetch when relevant changes occurred
3. **`stopObservingDatabaseChangesUntilNextTransaction()`** - Prevents redundant event processing

### ✅ **Dynamic Hook Management**
1. **Update hook** - Only installed when observers exist (`statementObservations` not empty)
2. **Commit/rollback hooks** - Installed permanently (lightweight)
3. **Authorizer** - Permanent base + temporary overlay pattern

### ✅ **Transaction Safety**
1. **SavepointStack** - Buffers events during savepoints
2. **Event filtering** - Only interested observers notified
3. **Rollback handling** - Discards buffered events on rollback

### ✅ **Resource Efficiency**
1. **Weak references** - Prevent retain cycles in observer lifecycle
2. **Automatic cleanup** - Hooks removed when last observer removed
3. **Shared observations** - Multiple subscribers share single database query

## 🔧 Implementation Priority

1. **SavepointStack** - Critical for transaction correctness
2. **DatabaseEvent & TransactionObservation** - Core event system
3. **DatabaseObservationBroker hooks** - SQLite integration
4. **FluentValueObserver `isModified` pattern** - Performance optimization
5. **SharedValueObservation** - Resource sharing for multiple UI components

This sequence diagram shows the complete, efficient observation system that will be achieved when all TODOs are implemented, providing GRDB-level performance and correctness in FluentSQLiteObservation.
