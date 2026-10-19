//
//  TasquelApp.swift
//  Tasquel
//
//  Created by John Fentner on 2/8/26.
//

import SwiftUI

@main
struct TasquelApp: App {
    // One store for every window (an iPad can open several), so windows never save
    // over each other's changes.
    @State private var store = ChecklistStore.makeDefault()
    @State private var calendarService = CalendarService.makeDefault()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store, calendarService: calendarService)
        }
    }
}
