//
//  LinkeApp.swift
//  Linke
//
//  Created by Hanyi Liu on 12/6/22.
//

import SwiftUI
import GoogleSignIn
import GoogleMobileAds
import EventKit
import BackgroundTasks


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
                    //Check Google authentication.
                    GADMobileAds.sharedInstance().start {_ in
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
                    
                    ///Register the launch handler for background tasks.
                    BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.linke.updatereminders", using: nil) { task in

                        task.expirationHandler = {
                            print("Task timed out!")
                            task.setTaskCompleted(success: false)
                        }
                        
                        
                        Task {
                            // *** Schedule next task for in the future ***
                            if let date = await BackgroundHandler.getTaskScheduleTime() {
                                let calendar = Calendar.current
                                let scheduledHour = calendar.component(.hour, from: date)
                                let scheduledMinute = calendar.component(.minute, from: date)
                                
                                BackgroundHandler.scheduleTimer(hour: scheduledHour, minute: scheduledMinute)
                            }
                            // ********************
                            
                            // *** Process classroom assignments ***
                            let classrooms = await ClassroomAPI(forceRestart: true)

                            let addedAssignments = await classrooms.addAllAssignments(store: EKEventStore(), isCompleted: [true, true, true, true], chosenTypes: [AssignmentType.inProgress, .missing, .noDateDue, .completed])
                            // ********************
                            
                            // *** Send notifiaction ***
                            // Create a local notification content
                            let content = UNMutableNotificationContent()
                            content.title = "Success!"
                            content.body = "\(addedAssignments) new assignments added to Reminders."
                            content.sound = UNNotificationSound.default
                            
                            // Create a trigger to display the notification immediately
                            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
                            
                            // Create a notification request
                            let request = UNNotificationRequest(identifier: "backgroundTaskCompleted", content: content, trigger: trigger)
                            
                            // Add the notification request to the notification center
                            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
                            // ********************
                            
                            task.setTaskCompleted(success: true)
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
    
    static func saveToLocal(key: String, value: Bool?) {
        if let encoded = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    static func saveToLocal(key: String, value: String) {
        if let encoded = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    static func saveToLocal(key: String, value: Int) {
        if let encoded = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    static func saveToLocal(key: String, value: AssignmentType) {
        if let encoded = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    static func saveToLocal(key: String, value: ReminderType) {
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
            case "Int":
                if let decoded = try? JSONDecoder().decode(Int.self, from: data
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
            case "ReminderType":
                if let decoded = try? JSONDecoder().decode(ReminderType.self, from: data
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
