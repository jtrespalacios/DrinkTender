//
//  DrinkTenderApp.swift
//  DrinkTender Watch App
//
//  Created by Jeff Trespalacios on 6/28/25.
//

import SwiftUI

@main
struct DrinkTimerApp: App {
    @StateObject private var drinkTimer = DrinkTimerModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(drinkTimer)
        }
    }
}
