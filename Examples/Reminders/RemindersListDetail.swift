import Sharing
import SharingGRDB
import StructuredQueriesGRDB
import SwiftUI

extension OrderingBuilder {
  public static func buildBlock(_ component: [OrderingTerm]...) -> [OrderingTerm] {
    component.flatMap { $0 }
  }
}

struct RemindersListDetailView: View {
  @State.SharedReader private var remindersState: [Reminders.Record]
  @Shared private var ordering: Ordering
  @Shared private var showCompleted: Bool
  private let remindersList: RemindersList

  @State var isNewReminderSheetPresented = false

  @Dependency(\.defaultDatabase) private var database

  enum Ordering: String, CaseIterable {
    case dueDate = "Due Date"
    case priority = "Priority"
    case title = "Title"
    var icon: Image {
      switch self {
      case .dueDate:  Image(systemName: "calendar")
      case .priority: Image(systemName: "chart.bar.fill")
      case .title:    Image(systemName: "textformat.characters")
      }
    }
  }

  init(remindersList: RemindersList) {
    self.remindersList = remindersList
    _remindersState = State.SharedReader(value: [])
    _ordering = Shared(wrappedValue: .dueDate, .appStorage("ordering_list_\(remindersList.id)"))
    _showCompleted = Shared(
      wrappedValue: false, .appStorage("show_completed_list_\(remindersList.id)")
    )
    $remindersState = SharedReader(
      .fetch(
        Reminders(
          listID: remindersList.id,
          ordering: ordering,
          showCompleted: showCompleted
        ),
        animation: .default
      )
    )
  }

  var body: some View {
    List {
      ForEach(remindersState, id: \.reminder.id) { reminderState in
        ReminderRow(
          isPastDue: reminderState.isPastDue,
          reminder: reminderState.reminder,
          remindersList: remindersList,
          tags: reminderState.tags
        )
      }
    }
    .task(id: [ordering, showCompleted] as [AnyHashable]) {
      await withErrorReporting {
        try await updateQuery()
      }
    }
    .navigationTitle(Text(remindersList.name))
    .navigationBarTitleDisplayMode(.large)
    .sheet(isPresented: $isNewReminderSheetPresented) {
      NavigationStack {
        ReminderFormView(remindersList: remindersList)
      }
    }
    .toolbar {
      ToolbarItem(placement: .bottomBar) {
        HStack {
          Button {
            isNewReminderSheetPresented = true
          } label: {
            HStack {
              Image(systemName: "plus.circle.fill")
              Text("New reminder")
            }
            .bold()
            .font(.title3)
          }
          Spacer()
        }
      }
      ToolbarItem(placement: .primaryAction) {
        Menu {
          Menu {
            ForEach(Ordering.allCases, id: \.self) { ordering in
              Button {
                $ordering.withLock { $0 = ordering }
              } label: {
                Text(ordering.rawValue)
                ordering.icon
              }
            }
          } label: {
            Text("Sort By")
            Text(ordering.rawValue)
            Image(systemName: "arrow.up.arrow.down")
          }
          Button {
            $showCompleted.withLock { $0.toggle() }
          } label: {
            Text(showCompleted ? "Hide Completed" : "Show Completed")
            Image(systemName: showCompleted ? "eye.slash.fill" : "eye")
          }
        } label: {
          Image(systemName: "ellipsis.circle")
        }
      }
    }
  }

  private func updateQuery() async throws {
    try await $remindersState.load(
      .fetch(
        Reminders(listID: remindersList.id, ordering: ordering, showCompleted: showCompleted),
        animation: .default
      )
    )
  }

  private struct Reminders: FetchKeyRequest {
    let listID: Int64
    let ordering: Ordering
    let showCompleted: Bool
    func fetch(_ db: Database) throws -> [Record] {
      return try Reminder
        .where { $0.listID == listID }
      // TODO: Should `where` return `any Expression<Bool>` as `@_disfavoredOverload`?
      //        .where { showCompleted ? true : !$0.isCompleted }
        .where { showCompleted || !$0.isCompleted }
        .group(by: \.id)
        .order {
          // TODO: Do we want to support this `buildBlock`
          $0.isCompleted

          switch ordering {
          case .dueDate:
            $0.date
          case .priority:
            ($0.priority.descending(), $0.isFlagged.descending())
          case .title:
            $0.title
          }
        }
        .leftJoin(ReminderTag.all()) { $0.id == $1.reminderID }
      // TODO: Overload to fix
        .leftJoin(Tag.all()) { $0.1.tagID == $1.id }
        .select {
          (
            $0.0,
            $0.0.isCompleted
            && .raw("coalesce(\(bind: $0.0.date), date('now')) < date('now')", as: Bool.self),
            $1.name.groupConcat(separator: ",")
            // TODO: Ambiguous '??'
            //            !$0.0.isCompleted /* && ($0.0.date ?? .raw("date('now')")) < .raw("date('now')") */
          )
        }
        .fetchAll(db)
        .map(Record.init)
    }
    struct Record: Decodable, FetchableRecord {
      var reminder: Reminder
      var isPastDue: Bool
      var commaSeparatedTags: String?
      var tags: [String] {
        (commaSeparatedTags ?? "").split(separator: ",").map(String.init)
      }
    }
  }
}

#Preview {
  let remindersList = try! prepareDependencies {
    $0.defaultDatabase = try Reminders.appDatabase(inMemory: true)
    return try $0.defaultDatabase.read { db in
      try RemindersList.fetchOne(db)! as RemindersList
    }
  }
  NavigationStack {
    RemindersListDetailView(remindersList: remindersList)
  }
}
