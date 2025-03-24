import Foundation
import GRDB
import SQLite3
import StructuredQueriesCore

public final class QueryValueCursor<
  QueryValue: QueryRepresentable
>: QueryCursor<QueryValue.QueryOutput>, DatabaseCursor {
  public typealias Element = QueryValue.QueryOutput

  public func _element(sqliteStatement _: SQLiteStatement) throws -> Element {
    let element = try decoder.decodeColumns(QueryValue.self)
    decoder.next()
    return element
  }
}

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
public final class QueryPackCursor<
  each QueryValue: QueryRepresentable
>: QueryCursor<(repeat (each QueryValue).QueryOutput)>, DatabaseCursor {
  public typealias Element = (repeat (each QueryValue).QueryOutput)

  public func _element(sqliteStatement _: SQLiteStatement) throws -> Element {
    let element = try decoder.decodeColumns((repeat each QueryValue).self)
    decoder.next()
    return element
  }
}

final class QueryVoidCursor: QueryCursor<Void>, DatabaseCursor {
  typealias Element = ()

  func _element(sqliteStatement _: SQLiteStatement) throws {
    try decoder.decodeColumns(Void.self)
    decoder.next()
  }
}

public class QueryCursor<Element> {
  public var _isDone = false
  public let _statement: GRDB.Statement

  fileprivate var decoder: SQLiteQueryDecoder

  init(db: Database, query: QueryFragment) throws {
    (_statement, decoder) = try db.prepare(query: query)
  }

  deinit {
    sqlite3_reset(_statement.sqliteStatement)
  }
}

private struct EmptyQuery: Error {}

extension Database {
  fileprivate func prepare(query: QueryFragment) throws -> (GRDB.Statement, SQLiteQueryDecoder) {
    guard !query.isEmpty else { throw EmptyQuery() }
    let statement = try makeStatement(sql: query.string)
    statement.arguments = StatementArguments(query.bindings.map(\.databaseValue))
    return (
      statement,
      SQLiteQueryDecoder(database: sqliteConnection, statement: statement.sqliteStatement)
    )
  }
}

extension QueryBinding {
  fileprivate var databaseValue: DatabaseValue {
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
    }
  }
}
