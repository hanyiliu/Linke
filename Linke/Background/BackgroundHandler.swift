//
//  BackgroundHandler.swift
//  Linke
//
//  Created by Hanyi Liu on 4/27/23.
//

import BackgroundTasks
import UserNotifications

struct BackgroundHandler: Any {
    static let backgroundIdentifier = "com.linke.updatereminders"
    
    //Schedule a new task while removing any previously scheduled tasks. If there is no previous tasks, a task is simply scheduled.
    static func scheduleTimerWithOverride(hour: Int, minute: Int) async {
        if let date = await getTaskScheduleTime() {
            let calendar = Calendar.current
            let scheduledHour = calendar.component(.hour, from: date)
            let scheduledMinute = calendar.component(.minute, from: date)
            
            if scheduledHour != (hour) || scheduledMinute != minute {
                cancelTask()
                print("Scheduling Background Refresh")
                scheduleTimer(hour: hour, minute: minute)
            }
        } else {
            print("Scheduling Background Refresh")
            scheduleTimer(hour: hour, minute: minute)
        }
    }
    
    //Schedule a new task at the specified time. It will always be scheduled in the future.
    static func scheduleTimer(hour: Int, minute: Int) {
        //Request notification access if not already granted
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                // Handle error
                print("Error requesting authorization for local notifications: \(error)")
                return
            }
            
            if granted {
                // User granted authorization
                print("Authorization granted for local notifications")
            } else {
                // User denied authorization
                print("Authorization denied for local notifications")
            }
        }
        /////
        var date = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
        if date <= Date() {
            date = Calendar.current.date(byAdding: .day, value: 1, to: date)!
        }

        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        
        // Schedule the background task
        let request = BGProcessingTaskRequest(identifier: backgroundIdentifier)
        request.earliestBeginDate = trigger.nextTriggerDate() ?? Date(timeIntervalSinceNow: 60)
        
        request.requiresNetworkConnectivity = true
        
        
        print("Trying to schedule task at \(dateComponents)")
        do {
            try BGTaskScheduler.shared.submit(request)
            
            
        } catch {
            print("Error scheduling background task: \(error)")
        }
    }
    
    //Cancel the current task with backgroundIndentifier.
    static func cancelTask() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: "com.linke.updatereminders")
        print("Background task cancelled")
    }
    
    //Return time at which the current task is scheduled for.
    static func getTaskScheduleTime() async -> Date? {
        
        let taskRequest = await BGTaskScheduler.shared.pendingTaskRequests()
        for request in taskRequest {
            if request.identifier == backgroundIdentifier {
                return request.earliestBeginDate
            }
        }
        
        return nil
    }
}
