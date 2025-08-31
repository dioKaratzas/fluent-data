import Foundation

extension FluentData {
    /// A pagination limit that can be set to a specific value or no limit.
    ///
    /// `PageLimit` follows Fluent's pagination pattern and provides a type-safe way
    /// to specify query result limits. It can be set to a specific integer value
    /// or to no limit at all.
    ///
    /// ## Usage
    /// ```swift
    /// client.pageSizeLimit = PageLimit(100)
    /// client.pageSizeLimit = .noLimit
    /// client.pageSizeLimit = 50  // ExpressibleByIntegerLiteral
    /// ```
    public struct PageLimit: Sendable {
        public let value: Int?

        /// Creates a page limit with no maximum.
        public static var noLimit: PageLimit {
            .init(value: nil)
        }

        /// Creates a page limit with a specific value.
        /// - Parameter value: The maximum number of results to return.
        public init(_ value: Int) {
            self.value = value
        }

        /// Creates a page limit with an optional value.
        /// - Parameter value: The maximum number of results to return, or nil for no limit.
        public init(value: Int?) {
            self.value = value
        }
    }
}

extension FluentData.PageLimit: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: IntegerLiteralType) {
        self.value = value
    }
}

extension FluentData.PageLimit: Equatable {}

extension FluentData.PageLimit: CustomStringConvertible {
    public var description: String {
        if let value = value {
            return "PageLimit(\(value))"
        } else {
            return "PageLimit.noLimit"
        }
    }
}
