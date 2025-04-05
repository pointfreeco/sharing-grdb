import Foundation
import GRDB
import SQLite3
import StructuredQueriesCore

public class QueryCursor<Element>: DatabaseCursor {
  public var _isDone = false
  public let _statement: GRDB.Statement

  @usableFromInline
  var decoder: SQLiteQueryDecoder

  @usableFromInline
  init(db: Database, query: QueryFragment) throws {
    (_statement, decoder) = try db.prepare(query: query)
  }

  deinit {
    sqlite3_reset(_statement.sqliteStatement)
  }

  public func _element(sqliteStatement _: SQLiteStatement) throws -> Element {
    fatalError("Abstract method should be overridden in subclass")
  }
}

@usableFromInline
final class QueryValueCursor<QueryValue: QueryRepresentable>: QueryCursor<QueryValue.QueryOutput> {
  public typealias Element = QueryValue.QueryOutput

  @inlinable
  public override func _element(sqliteStatement _: SQLiteStatement) throws -> Element {
    let element = try QueryValue(decoder: &decoder).queryOutput
    decoder.next()
    return element
  }
}

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
@usableFromInline
final class QueryPackCursor<
  each QueryValue: QueryRepresentable
>: QueryCursor<(repeat (each QueryValue).QueryOutput)> {
  public typealias Element = (repeat (each QueryValue).QueryOutput)

  @inlinable
  public override func _element(sqliteStatement _: SQLiteStatement) throws -> Element {
    let element = try decoder.decodeColumns((repeat each QueryValue).self)
    decoder.next()
    return element
  }
}

@usableFromInline
final class QueryVoidCursor: QueryCursor<Void> {
  typealias Element = ()

  @inlinable
  override func _element(sqliteStatement _: SQLiteStatement) throws {
    try decoder.decodeColumns(Void.self)
    decoder.next()
  }
}

@usableFromInline
struct EmptyQuery: Error {
  @usableFromInline
  init() {}
}

extension Database {
  @inlinable
  func prepare(query: QueryFragment) throws -> (GRDB.Statement, SQLiteQueryDecoder) {
    guard !query.isEmpty else { throw EmptyQuery() }
    let statement = try makeStatement(sql: query.string)
    statement.arguments = try StatementArguments(query.bindings.map { try $0.databaseValue })
    return (
      statement,
      SQLiteQueryDecoder(database: sqliteConnection, statement: statement.sqliteStatement)
    )
  }
}

extension QueryBinding {
  @inlinable
  var databaseValue: DatabaseValue {
    get throws {
      switch self {
      case let .blob(blob):
        return Data(blob).databaseValue
      case let .double(double):
        return double.databaseValue
      case let .int(int):
        return int.databaseValue
      case .null:
        return .null
      case let .text(text):
        return text.databaseValue
      case let ._invalid(error):
        throw error
      }
    }
  }
}
