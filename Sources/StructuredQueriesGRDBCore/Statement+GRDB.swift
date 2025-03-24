import GRDB
import SQLite3
import StructuredQueriesCore

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension StructuredQueriesCore.Statement {
  public func execute(_ db: Database) throws where QueryValue == () {
    try fetchCursor(db).next()
  }

  public func fetchAll<each Value: QueryRepresentable>(
    _ db: Database
  ) throws -> [(repeat (each Value).QueryOutput)]
  where QueryValue == (repeat each Value) {
    let cursor = try fetchCursor(db)
    return try Array(cursor)
  }

  public func fetchAll(_ db: Database) throws -> [QueryValue.QueryOutput]
  where QueryValue: QueryRepresentable {
    try Array(fetchCursor(db))
  }

  public func fetchOne<each Value: QueryRepresentable>(
    _ db: Database
  ) throws -> (repeat (each Value).QueryOutput)?
  where QueryValue == (repeat each Value) {
    let cursor = try fetchCursor(db)
    return try cursor.next()
  }

  public func fetchOne(_ db: Database) throws -> QueryValue.QueryOutput?
  where QueryValue: QueryRepresentable {
    try fetchCursor(db).next()
  }

  public func fetchCursor<each Value: QueryRepresentable>(
    _ db: Database
  ) throws -> QueryCursor<repeat each Value>
  where QueryValue == (repeat each Value) {
    try QueryCursor(db: db, query: self)
  }

  public func fetchCursor(_ db: Database) throws -> QueryCursor<QueryValue>
  where QueryValue: QueryRepresentable {
    try QueryCursor(db: db, query: self)
  }
}

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension SelectStatement where QueryValue == () {
  public func fetchAll<each J: StructuredQueriesCore.Table>(
    _ db: Database
  ) throws -> [(From.QueryOutput, repeat (each J).QueryOutput)]
  where Joins == (repeat each J) {
    try selectStar().fetchAll(db)
  }

  public func fetchOne<each J: StructuredQueriesCore.Table>(
    _ db: Database
  ) throws -> (From.QueryOutput, repeat (each J).QueryOutput)?
  where Joins == (repeat each J) {
    try selectStar().fetchOne(db)
  }
}
