import SharingGRDB
import StructuredQueriesGRDB
import SwiftUI

@Table
struct SyncUp: Codable, Hashable, Identifiable {
  @Column("id", primaryKey: true) let id: Int
  @Column("seconds") var seconds: Int = 60 * 5
  @Column("theme") var theme: Theme = .bubblegum
  @Column("title") var title = ""
}

extension Int {
  var duration: Duration {
    get { .seconds(self) }
    set { self = Int(newValue.components.seconds) }
  }
}

@Table
struct Attendee: Codable, Hashable, Identifiable {
  let id: Int
  var name = ""
  var syncUpID: SyncUp.ID
}

@Table
struct Meeting: Codable, Hashable, Identifiable {
  let id: Int
  @Column(as: Date.ISO8601Representation.self)
  var date: Date
  var syncUpID: SyncUp.ID
  var transcript: String
}

enum Theme: String, CaseIterable, Codable, Hashable, Identifiable, QueryBindable {
  case appIndigo
  case appMagenta
  case appOrange
  case appPurple
  case appTeal
  case appYellow
  case bubblegum
  case buttercup
  case lavender
  case navy
  case oxblood
  case periwinkle
  case poppy
  case seafoam
  case sky
  case tan

  var id: Self { self }

  var accentColor: Color {
    switch self {
    case .appOrange, .appTeal, .appYellow, .bubblegum, .buttercup, .lavender, .periwinkle, .poppy,
      .seafoam, .sky, .tan:
      return .black
    case .appIndigo, .appMagenta, .appPurple, .navy, .oxblood:
      return .white
    }
  }

  var mainColor: Color { Color(rawValue) }

  var name: String {
    switch self {
    case .appIndigo, .appMagenta, .appOrange, .appPurple, .appTeal, .appYellow:
      rawValue.dropFirst(3).capitalized
    case .bubblegum, .buttercup, .lavender, .navy, .oxblood, .periwinkle, .poppy, .seafoam, .sky,
      .tan:
      rawValue.capitalized
    }
  }
}

func appDatabase(inMemory: Bool = false) throws -> any DatabaseWriter {
  let database: any DatabaseWriter
  var configuration = Configuration()
  configuration.foreignKeysEnabled = true
  configuration.prepareDatabase { db in
    #if DEBUG
      db.trace(options: .profile) {
        print($0.expandedDescription)
      }
    #endif
  }
  if inMemory {
    database = try DatabaseQueue(configuration: configuration)
  } else {
    let path = URL.documentsDirectory.appending(component: "db.sqlite").path()
    print("open", path)
    database = try DatabasePool(path: path, configuration: configuration)
  }
  var migrator = DatabaseMigrator()
  #if DEBUG
    migrator.eraseDatabaseOnSchemaChange = true
  #endif
  migrator.registerMigration("Create sync-ups table") { db in
    try db.create(table: SyncUp.tableName) { table in
      table.autoIncrementedPrimaryKey("id")
      table.column("seconds", .integer).defaults(to: 5 * 60).notNull()
      table.column("theme", .text).notNull().defaults(to: Theme.bubblegum.rawValue)
      table.column("title", .text).notNull()
    }
  }
  migrator.registerMigration("Create attendees table") { db in
    try db.create(table: Attendee.tableName) { table in
      table.autoIncrementedPrimaryKey("id")
      table.column("name", .text).notNull()
      table.column("syncUpID", .integer)
        .references(SyncUp.tableName, column: "id", onDelete: .cascade)
        .notNull()
    }
  }
  migrator.registerMigration("Create meetings table") { db in
    try db.create(table: Meeting.tableName) { table in
      table.autoIncrementedPrimaryKey("id")
      table.column("date", .datetime).notNull().unique().defaults(sql: "CURRENT_TIMESTAMP")
      table.column("syncUpID", .integer)
        .references(SyncUp.tableName, column: "id", onDelete: .cascade)
        .notNull()
      table.column("transcript", .text).notNull()
    }
  }
  #if DEBUG
    migrator.registerMigration("Insert sample data") { db in
      try db.insertSampleData()
    }
  #endif

  try migrator.migrate(database)

  return database
}

#if DEBUG
  extension Database {
    func insertSampleData() throws {
      let design = try SyncUp
        .insert(SyncUp.Draft(seconds: 60, theme: .appOrange, title: "Design"))
        .returning(\.self)
        .fetchOne(self)!

      for name in ["Blob", "Blob Jr", "Blob Sr", "Blob Esq", "Blob III", "Blob I"] {
        try Attendee
          .insert(Attendee.Draft(name: name, syncUpID: design.id))
          .execute(self)
      }
      try Meeting
        .insert(
          Meeting.Draft(
            date: Date().addingTimeInterval(-60 * 60 * 24 * 7),
            syncUpID: design.id,
            transcript: """
          Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor \
          incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud \
          exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure \
          dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. \
          Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt \
          mollit anim id est laborum.
          """
          )
        )
        .execute(self)

      let engineering = try SyncUp
        .insert(SyncUp.Draft(seconds: 60 * 10, theme: .periwinkle, title: "Engineering"))
        .returning(\.self)
        .fetchOne(self)!
      for name in ["Blob", "Blob Jr"] {
        try Attendee
          .insert(Attendee.Draft(name: name, syncUpID: engineering.id))
          .execute(self)
      }

      let product = try SyncUp
        .insert(SyncUp.Draft(seconds: 60 * 30, theme: .poppy, title: "Product"))
        .returning(\.self)
        .fetchOne(self)!
      for name in ["Blob Sr", "Blob Jr"] {
        try Attendee
          .insert(Attendee.Draft(name: name, syncUpID: product.id))
          .execute(self)
      }
    }
  }
#endif
