//
//  LinkerApp.swift
//  Linker
//
//  Created by Hanyi Liu on 12/6/22.
//

import SwiftUI
import GoogleSignIn
import EventKit
    

@main
struct LinkerApp: App {
    @StateObject var viewRouter = ViewRouter()
    
    var body: some Scene {
        WindowGroup {
            ContentView(viewRouter: viewRouter)
            
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
            
                .onAppear {

                    GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
                        if error != nil || user == nil {
                            // Show the app's signed-out state.
                            print("User not previously logged in")
                            viewRouter.currentPage = .googleSignIn
                        } else {
                            // Show the app's signed-in state.
                            
                            print("User previously logged in")
                            viewRouter.currentPage = .reminderAccess
                        }
                    }
                }
        }
    }
    

    
}

struct UpdateValue: Any {
    static func saveToLocal(key: String, value: Bool) {
        if let encoded = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    static func saveToLocal(key: String, value: String) {
        if let encoded = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    static func saveToLocal(key: String, value: AssignmentType) {
        if let encoded = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    
    static func loadFromLocal(key: String, type: String) -> Any? {
        if let data = UserDefaults.standard.data(forKey: key) {
            switch(type) {
            case "String":
                if let decoded = try? JSONDecoder().decode(String.self, from: data
                ) {
                    return decoded
                } else {
                    return nil
                }
            case "Bool":
                if let decoded = try? JSONDecoder().decode(Bool.self, from: data
                ) {
                    return decoded
                } else {
                    return nil
                }
            case "AssignmentType":
                if let decoded = try? JSONDecoder().decode(AssignmentType.self, from: data
                ) {
                    return decoded
                } else {
                    return nil
                }
            default:
                return nil
            
            }
        } else {
            
            
            return nil
        }
    }
    
    static func getCalendar(store: EKEventStore, identifier: String) -> EKCalendar? {
        for calendar in store.calendars(for: .reminder) {
            if calendar.calendarIdentifier == identifier {
                return calendar
            }
        }
        return nil
    }
}
