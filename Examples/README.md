# Examples

This directory holds many case studies and applications to demonstrate solving various problems 
with [SharingGRDB](http://github.com/pointfreeco/sharing-grdb). Open the 
`SharingGRDB.xcworkspace` at the root of the repo to see all example projects in one single 
workspace, or you can open each example application individually.

* **Case Studies**
  <br> Demonstrates how to solve some common application problems in an isolated environment, in 
  both SwiftUI and UIKit. Things like animations, dynamic queries, database transactions, and more.

* **Reminders**
  <br> A rebuild of Apple's [Reminders][reminders-app-store] app that uses a SQLite database to 
    model the reminders, lists and tags. It features many advanced queries, such as searching, 
    stats aggregation, and multi-table joins.

* **SyncUps**
  <br> This application is a faithful reconstruction of one of Apple's more interesting sample 
  projects, called [Scrumdinger][scrumdinger], and uses SQLite to persist the data for meetings.

[scrumdinger]: https://developer.apple.com/tutorials/app-dev-training/getting-started-with-scrumdinger
[reminders-app-store]: https://apps.apple.com/us/app/reminders/id1108187841
