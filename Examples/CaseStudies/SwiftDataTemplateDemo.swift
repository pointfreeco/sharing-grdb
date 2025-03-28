import SharingGRDB
import StructuredQueriesGRDB
import SwiftUI

struct SwiftDataTemplateView: SwiftUICaseStudy {
  let readMe = """
    This case study recreates the default SwiftData app that is used when creating a brand new
    Xcode SwiftData project.
    """
  let caseStudyTitle = "SwiftData Template"

  @Dependency(\.defaultDatabase) private var database
  @SharedReader(.fetchAll(Item.all(), animation: .default)) private var items

  var body: some View {
    NavigationStack {
      List {
        ForEach(items) { item in
          NavigationLink {
            Text(
              "Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))"
            )
          } label: {
            Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
          }
        }
        .onDelete(perform: deleteItems)
      }
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          EditButton()
        }
        ToolbarItem {
          Button(action: addItem) {
            Label("Add Item", systemImage: "plus")
          }
        }
      }
    }
  }

  private func addItem() {
    withErrorReporting {
      try database.write { db in
        try Item.insert().execute(db)
      }
    }
  }

  private func deleteItems(offsets: IndexSet) {
    withErrorReporting {
      try database.write { db in
        try Item.where { $0.id.in(offsets.map { items[$0].id }) }.delete().execute(db)
      }
    }
  }
}

@Table
private struct Item: Identifiable {
  let id: Int
  @Column(as: Date.ISO8601Representation.self)
  var timestamp: Date
}

extension DatabaseWriter where Self == DatabaseQueue {
  static var swiftDataTemplateDatabase: Self {
    let databaseQueue = try! DatabaseQueue()
    var migrator = DatabaseMigrator()
    migrator.registerMigration("Create items table") { db in
      try db.create(table: Item.tableName) { table in
        table.autoIncrementedPrimaryKey("id")
        table.column("timestamp", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
      }
    }
    try! migrator.migrate(databaseQueue)
    return databaseQueue
  }
}

#Preview {
  let _ = prepareDependencies {
    $0.defaultDatabase = .swiftDataTemplateDatabase
  }
  CaseStudyView {
    SwiftDataTemplateView()
  }
}
