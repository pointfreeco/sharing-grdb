import Foundation
import GRDB
import IssueReporting
import SQLite3
import StructuredQueriesCore

struct Database {
  private let db: GRDB.Database
  private let handle: OpaquePointer

  init(_ handle: OpaquePointer, db: GRDB.Database) {
    self.db = db
    self.handle = handle
  }

  public func execute(
    _ sql: String
  ) throws {
    guard sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK
    else {
      throw SQLiteError(handle)
    }
  }

  @available(iOS 17.0.0, *)
  public func execute(_ query: some StructuredQueriesCore.Statement<()>) throws {
    let c = try cursor(query)
    _ = try Array(c, minimumCapacity: 0)
  }

  @available(iOS 17.0.0, *)
  fileprivate func cursor<each QueryValue: QueryRepresentable>(
    _ query: some StructuredQueriesCore.Statement<(repeat each QueryValue)>
  ) throws -> QueryCursor<repeat each QueryValue> {
    try QueryCursor(database: db, query: query)
  }

  @available(iOS 17.0.0, *)
  fileprivate func cursor<QueryValue: QueryRepresentable>(
    _ query: some StructuredQueriesCore.Statement<QueryValue>
  ) throws -> QueryCursor<QueryValue> {
    try QueryCursor(database: db, query: query)
  }

  @available(iOS 17.0.0, *)
  public func execute<QueryValue: QueryRepresentable>(
    _ query: some StructuredQueriesCore.Statement<QueryValue>
  ) throws -> [QueryValue.QueryOutput] {
    try Array(try cursor(query), minimumCapacity: 0)
  }

  @available(iOS 17.0.0, *)
  public func execute<each QueryValue: QueryRepresentable>(
    _ query: some StructuredQueriesCore.Statement<(repeat each QueryValue)>
  ) throws -> [(repeat (each QueryValue).QueryOutput)] {
    let c = try cursor(query)
    return try Array(c, minimumCapacity: 0)
  }

  public func execute<S: SelectStatement, each J: StructuredQueriesCore.Table>(
    _ query: S
  ) throws -> [(S.From.QueryOutput, repeat (each J).QueryOutput)]
  where S.QueryValue == (), S.Joins == (repeat each J) {
    let query = query.query
    guard !query.isEmpty else {
      reportIssue("Can't fetch from empty query")
      return []
    }
    return try withStatement(query) { statement in
      var results: [(S.From.QueryOutput, repeat (each J).QueryOutput)] = []
      let decoder = SQLiteQueryDecoder(database: handle, statement: statement)
      loop: while true {
        let code = sqlite3_step(statement)
        switch code {
        case SQLITE_ROW:
          try results.append(
            (
              decoder.decodeColumns(S.From.self).queryOutput,
              repeat decoder.decodeColumns((each J).self).queryOutput
            )
          )
          decoder.next()
        case SQLITE_DONE:
          break loop
        default:
          throw SQLiteError(handle)
        }
      }
      return results
    }
  }

  private func withStatement<R>(
    _ query: QueryFragment, body: (OpaquePointer) throws -> R
  ) throws -> R {
    let statement = try db.makeStatement(sql: query.string)
    print("!!!!", statement.databaseRegion, query.string)
    try db.registerAccess(to: statement.databaseRegion)
    for (index, binding) in zip(Int32(1)..., query.bindings) {
      let result =
        switch binding {
        case let .blob(blob):
          sqlite3_bind_blob(
            statement.sqliteStatement, index, Array(blob), Int32(blob.count), SQLITE_TRANSIENT
          )
        case let .double(double):
          sqlite3_bind_double(statement.sqliteStatement, index, double)
        case let .int(int):
          sqlite3_bind_int64(statement.sqliteStatement, index, Int64(int))
        case .null:
          sqlite3_bind_null(statement.sqliteStatement, index)
        case let .text(text):
          sqlite3_bind_text(statement.sqliteStatement, index, text, -1, SQLITE_TRANSIENT)
        }
      guard result == SQLITE_OK else { throw SQLiteError(handle) }
    }
    let results = try body(statement.sqliteStatement)
    try db.notifyChanges(in: statement.databaseRegion)
    return results
  }
}

@available(iOS 17.0.0, *)
private final class QueryCursor<each QueryValue: QueryRepresentable>: DatabaseCursor {
  typealias Element = (repeat (each QueryValue).QueryOutput)

  let decoder: SQLiteQueryDecoder
  var _isDone: Bool
  let _statement: GRDB.Statement

  struct EmptyQuery: Error {}

  init(
    database: GRDB.Database,
    query: some StructuredQueriesCore.Statement<(repeat each QueryValue)>
  ) throws {
    let query = query.query
    guard !query.isEmpty else {
      //reportIssue("Can't fetch from empty query")
      throw EmptyQuery()
    }

    let statement = try database.makeStatement(sql: query.string)
    decoder = SQLiteQueryDecoder(
      database: database.sqliteConnection,
      statement: statement.sqliteStatement
    )
    _isDone = false
    _statement = statement

    for (index, binding) in zip(Int32(1)..., query.bindings) {
      let result =
      switch binding {
      case let .blob(blob):
        sqlite3_bind_blob(
          statement.sqliteStatement, index, Array(blob), Int32(blob.count), SQLITE_TRANSIENT
        )
      case let .double(double):
        sqlite3_bind_double(statement.sqliteStatement, index, double)
      case let .int(int):
        sqlite3_bind_int64(statement.sqliteStatement, index, Int64(int))
      case .null:
        sqlite3_bind_null(statement.sqliteStatement, index)
      case let .text(text):
        sqlite3_bind_text(statement.sqliteStatement, index, text, -1, SQLITE_TRANSIENT)
      }
      guard result == SQLITE_OK else { throw SQLiteError(database.sqliteConnection) }
    }
  }
  func _element(sqliteStatement: GRDB.SQLiteStatement) throws -> (repeat (each QueryValue).QueryOutput) {
    defer { decoder.next() }
    return try (repeat (each QueryValue)(decoder: decoder).queryOutput)
  }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct SQLiteError: Error {
  let message: String

  init(_ handle: OpaquePointer?) {
    self.message = String(cString: sqlite3_errmsg(handle))
  }
}
