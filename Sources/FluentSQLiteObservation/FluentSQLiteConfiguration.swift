//===----------------------------------------------------------------------===//
//
// This source file is part of the FluentData open source project
//
// Copyright (c) Dionysios Karatzas
// Licensed under the MIT license
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: MIT
//
//===----------------------------------------------------------------------===//

import NIO
import Logging
import FluentKit
import SQLiteKit
import FluentSQLiteDriver

extension DatabaseConfigurationFactory {
    /// Shorthand for ``sqliteWithObservation(_:connectionPoolTimeout:dataEncoder:dataDecoder:sqlLogLevel:configureConnection:)``.
    public static func sqliteWithObservation(
        _ config: SQLiteConfiguration = .memory,
        connectionPoolTimeout: TimeAmount = .seconds(10),
        configureConnection: (@Sendable (SQLiteConnection, Logger) -> EventLoopFuture<Void>)? = nil
    ) -> Self {
        self.sqliteWithObservation(
            config,
            connectionPoolTimeout: connectionPoolTimeout,
            dataEncoder: .init(),
            dataDecoder: .init(),
            sqlLogLevel: .debug,
            configureConnection: configureConnection
        )
    }

    /// Shorthand for ``sqliteWithObservation(_:connectionPoolTimeout:dataEncoder:dataDecoder:sqlLogLevel:configureConnection:)``.
    public static func sqliteWithObservation(
        _ config: SQLiteConfiguration = .memory,
        connectionPoolTimeout: TimeAmount = .seconds(10),
        dataEncoder: SQLiteDataEncoder,
        configureConnection: (@Sendable (SQLiteConnection, Logger) -> EventLoopFuture<Void>)? = nil
    ) -> Self {
        self.sqliteWithObservation(
            config,
            connectionPoolTimeout: connectionPoolTimeout,
            dataEncoder: dataEncoder,
            dataDecoder: .init(),
            sqlLogLevel: .debug,
            configureConnection: configureConnection
        )
    }

    /// Shorthand for ``sqliteWithObservation(_:connectionPoolTimeout:dataEncoder:dataDecoder:sqlLogLevel:configureConnection:)``.
    public static func sqliteWithObservation(
        _ config: SQLiteConfiguration = .memory,
        connectionPoolTimeout: TimeAmount = .seconds(10),
        dataEncoder: SQLiteDataEncoder,
        dataDecoder: SQLiteDataDecoder,
        configureConnection: (@Sendable (SQLiteConnection, Logger) -> EventLoopFuture<Void>)? = nil
    ) -> Self {
        self.sqliteWithObservation(
            config,
            connectionPoolTimeout: connectionPoolTimeout,
            dataEncoder: dataEncoder,
            dataDecoder: dataDecoder,
            sqlLogLevel: .debug,
            configureConnection: configureConnection
        )
    }

    /// Shorthand for ``sqliteWithObservation(_:connectionPoolTimeout:dataEncoder:dataDecoder:sqlLogLevel:configureConnection:)``.
    public static func sqliteWithObservation(
        _ config: SQLiteConfiguration = .memory, connectionPoolTimeout: TimeAmount = .seconds(10),
        sqlLogLevel: Logger.Level?,
        configureConnection: (@Sendable (SQLiteConnection, Logger) -> EventLoopFuture<Void>)? = nil
    ) -> Self {
        self.sqliteWithObservation(
            config,
            connectionPoolTimeout: connectionPoolTimeout,
            dataEncoder: .init(),
            dataDecoder: .init(),
            sqlLogLevel: sqlLogLevel,
            configureConnection: configureConnection
        )
    }

    /// Shorthand for ``sqliteWithObservation(_:connectionPoolTimeout:dataEncoder:dataDecoder:sqlLogLevel:configureConnection:)``.
    public static func sqliteWithObservation(
        _ config: SQLiteConfiguration = .memory,
        connectionPoolTimeout: TimeAmount = .seconds(10),
        dataEncoder: SQLiteDataEncoder,
        sqlLogLevel: Logger.Level?,
        configureConnection: (@Sendable (SQLiteConnection, Logger) -> EventLoopFuture<Void>)? = nil
    ) -> Self {
        self.sqliteWithObservation(
            config,
            connectionPoolTimeout: connectionPoolTimeout,
            dataEncoder: dataEncoder,
            dataDecoder: .init(),
            sqlLogLevel: sqlLogLevel,
            configureConnection: configureConnection
        )
    }

    /// Shorthand for ``sqliteWithObservation(_:connectionPoolTimeout:dataEncoder:dataDecoder:sqlLogLevel:configureConnection:)``.
    public static func sqliteWithObservation(
        _ config: SQLiteConfiguration = .memory,
        connectionPoolTimeout: TimeAmount = .seconds(10),
        dataDecoder: SQLiteDataDecoder,
        sqlLogLevel: Logger.Level?,
        configureConnection: (@Sendable (SQLiteConnection, Logger) -> EventLoopFuture<Void>)? = nil
    ) -> Self {
        self.sqliteWithObservation(
            config,
            connectionPoolTimeout: connectionPoolTimeout,
            dataEncoder: .init(),
            dataDecoder: dataDecoder,
            sqlLogLevel: sqlLogLevel,
            configureConnection: configureConnection
        )
    }

    /// Shorthand for ``sqliteWithObservation(_:connectionPoolTimeout:dataEncoder:dataDecoder:sqlLogLevel:configureConnection:)``.
    public static func sqliteWithObservation(
        _ config: SQLiteConfiguration = .memory,
        connectionPoolTimeout: TimeAmount = .seconds(10),
        dataDecoder: SQLiteDataDecoder,
        configureConnection: (@Sendable (SQLiteConnection, Logger) -> EventLoopFuture<Void>)? = nil
    ) -> Self {
        self.sqliteWithObservation(
            config,
            connectionPoolTimeout: connectionPoolTimeout,
            dataEncoder: .init(),
            dataDecoder: dataDecoder,
            sqlLogLevel: .debug,
            configureConnection: configureConnection
        )
    }

    /// Shorthand for ``sqliteWithObservation(_:connectionPoolTimeout:dataEncoder:dataDecoder:sqlLogLevel:configureConnection:)``.
    public static func sqliteWithObservation(
        _ config: SQLiteConfiguration = .memory,
        configureConnection: (@Sendable (SQLiteConnection, Logger) -> EventLoopFuture<Void>)? = nil
    ) -> Self {
        self.sqliteWithObservation(
            config,
            connectionPoolTimeout: .seconds(10),
            dataEncoder: .init(),
            dataDecoder: .init(),
            sqlLogLevel: .debug,
            configureConnection: configureConnection
        )
    }

    /// Return a configuration factory using the provided parameters with database observation support.
    ///
    /// - Parameters:
    ///   - configuration: The underlying `SQLiteConfiguration`.
    ///   - connectionPoolTimeout: The maximum amount of time to wait for a connection to become available.
    ///   - dataEncoder: An `SQLiteDataEncoder` used to translate bound query parameters into `SQLiteData` values.
    ///   - dataDecoder: An `SQLiteDataDecoder` used to translate `SQLiteData` values into output values.
    ///   - sqlLogLevel: The level at which SQL queries issued through the Fluent or SQLKit interfaces will be logged.
    ///   - configureConnection: An optional closure to configure each connection as it is created.
    /// - Returns: A configuration factory.
    public static func sqliteWithObservation(
        _ configuration: SQLiteConfiguration = .memory,
        connectionPoolTimeout: TimeAmount = .seconds(10),
        dataEncoder: SQLiteDataEncoder,
        dataDecoder: SQLiteDataDecoder,
        sqlLogLevel: Logger.Level?,
        configureConnection: (@Sendable (SQLiteConnection, Logger) -> EventLoopFuture<Void>)?
    ) -> Self {
        .sqlite(
            configuration,
            maxConnectionsPerEventLoop: 1,
            connectionPoolTimeout: connectionPoolTimeout,
            dataEncoder: dataEncoder,
            dataDecoder: dataDecoder,
            sqlLogLevel: sqlLogLevel,
            configureConnection: { connection, logger in
                ConnectionObservationRegistry.shared.createBrokerIfNeeded(for: connection)
                return (configureConnection?(connection, logger) ?? connection.eventLoop.makeSucceededVoidFuture()).flatMap {
                    connection.eventLoop.makeSucceededVoidFuture()
                }
            }
        )
    }
}
