//
//  Assignment.swift
//  Linker
//
//  Created by Hanyi Liu on 12/8/22.
//

import Foundation
import EventKit

class Assignment: Identifiable {
    private var name: String
    private var dueDate: Date?
    private var classroom: Classroom
    private var type: AssignmentType
    private var store: EKEventStore
    private var assignmentID: String
    private var hidden = false
    private var reminderStatus = ReminderType.notAdded { //true: marked as completed, false: still in progress, nil: not added
        willSet { //before value is set
            if newValue == .notAdded {
                self.classroom.appendNotAddedAssignment(assignment: self)
            } else {
                self.classroom.removeNotAddedAssignment(assignment: self)
            }
        }
        
        didSet { //after value is set
            //print("Setting value of reminderStatus for assignment \(name) to \(reminderStatus)")
            UpdateValue.saveToLocal(key: "\(assignmentID)_REMINDER_STATUS", value: reminderStatus)
        }
    }
    
    
    init(name: String, id: String, dueDate: Date?, classroom: Classroom, type: AssignmentType, store: EKEventStore, manualRefresh: Bool = false) async {
        self.store = store
        self.name = name
        self.dueDate = dueDate
        self.classroom = classroom
        self.type = type
        self.assignmentID = id
        
        
        
        //print("CHECKPOINT 3.1.3.0.4.3.1 (\(self.name): \(Double(round(100 * Date().timeIntervalSince(self.classroom.classrooms.startTime))/100))")
        //self.classroom.classrooms.//startTime = Date()
        
        UpdateValue.saveToLocal(key: "\(assignmentID)_TYPE", value: type)
        
        ////print("CHECKPOINT 7.2")
        if let data = UpdateValue.loadFromLocal(key: "\(assignmentID)_IS_HIDDEN", type: "Bool") as? Bool {

            setHiddenStatus(hidden: data)
        }

        if let data = UpdateValue.loadFromLocal(key: "\(assignmentID)_REMINDER_STATUS", type: "ReminderType") as? ReminderType {
            //print("Found reminder status for assignment \(name). status is \(data)")
            reminderStatus = data
        } else {
            
        }
        //print("CHECKPOINT 3.1.3.0.4.3.2 (\(self.name): \(Double(round(100 * Date().timeIntervalSince(self.classroom.classrooms.startTime))/100))")
        //self.classroom.classrooms.//startTime = Date()
        if manualRefresh || reminderStatus == .notAdded || reminderStatus == .inProgress {
            
            //print("Checking if is added 1 for assignment \(name). reminderStatus: \(reminderStatus)")
            await checkIfIsAdded()
        } else {
            self.classroom.incrementLoadedAssignmentCount()
        }
        //print("CHECKPOINT 3.1.3.0.4.3.3 (\(self.name): \(Double(round(100 * Date().timeIntervalSince(self.classroom.classrooms.startTime))/100))")
        //self.classroom.classrooms.//startTime = Date()
        ////print("CHECKPOINT 7.6")
        //print("ADDED STATUS FOR \(name): \(added)")
            
        
        
    }

    
    func getName() -> String {
        return name
    }
    
    func getDueDate() -> Date? {
        return dueDate
    }
    
    func getID() -> String {
        return assignmentID
    }
    
    func getType() -> AssignmentType {
        return type
    }
    
    func isAdded() -> Bool {
        return !(reminderStatus == .notAdded)
    }
    
    func checkIfIsAdded() async {
        ////print("CHECKPOINT 7.3")
        if let identifier = classroom.getIdentifier() {
            ////print("CHECKPOINT 7.3.0.1")
            if let calendar = store.calendars(for: .reminder).first(where: { $0.calendarIdentifier == identifier }) {
                ////print("CHECKPOINT 7.3.0.2")
                let eventsPredicate = store.predicateForReminders(in: [calendar])
                ////print("CHECKPOINT 7.3.0.3")
                let semaphore = DispatchSemaphore(value: 0)
                //await withCheckedContinuation { continuation in
                    store.fetchReminders(matching: eventsPredicate) { reminders in
                        ////print("CHECKPOINT 7.3.1")
                        var found = false
                        var foundReminder: EKReminder?
                        for reminder: EKReminder? in reminders ?? [EKReminder?]() {
                            if let reminder = reminder {
                                if (reminder.title == self.name){
                                    ////print("CHECKPOINT 7.4")
                                    //print("ASSIGNMENT: Assignment \"\(self.name)\" exists in Reminder.")
                                    found = true
                                    foundReminder = reminder
                                }
                            }
                        }
                        if !found {
                            ////print("CHECKPOINT 7.IDK ANYMORE")
                            self.reminderStatus = .notAdded
                        } else {
                            if let foundReminder = foundReminder {
                                //print("Found reminder. isCompleted: \(foundReminder.isCompleted)")
                                if(foundReminder.isCompleted) {
                                    self.reminderStatus = .completed
                                } else {
                                    self.reminderStatus = .inProgress
                                }
                            }
                        }
                        self.classroom.incrementLoadedAssignmentCount()
                        semaphore.signal()
                    }
                    semaphore.wait()
                    //continuation.resume()
                //}
            } else {
                reminderStatus = .notAdded
                self.classroom.incrementLoadedAssignmentCount()
            }
            
        } else {
            reminderStatus = .notAdded
            self.classroom.incrementLoadedAssignmentCount()
        }
        ////print("CHECKPOINT 7.5")
    }
    
    func addToReminders(store: EKEventStore) async -> Bool {
        store.requestAccess(to: .event) { (granted, error) in
            if let error = error {
                print("ASSIGNMENT: Error occurred while trying to add to Reminders:")
                print(error)
            }
        }
//        if classroom.getIdentifier() == nil {
//            classroom.initializeList(store: store)
//        }
        var classCalendar: EKCalendar
        if let calendar = store.calendars(for: .reminder).first(where: { $0.calendarIdentifier == classroom.getIdentifier()! }) {
            classCalendar = calendar
        } else {
            print("ASSIGNMENT: Invalid calendar identifier while trying to add reminder \(name) from classroom \(classroom.getName())")
            return false
        }
        let eventsPredicate = store.predicateForReminders(in: [classCalendar])
        return await withCheckedContinuation { continuation in
            fetch(classCalendar: classCalendar, eventsPredicate: eventsPredicate, store: store) { success in
                continuation.resume(returning: success)
            }
        }
            
    
        
    }
    
    func fetch(classCalendar: EKCalendar, eventsPredicate: NSPredicate, store: EKEventStore, completion: @escaping (Bool) -> Void) {
        store.fetchReminders(matching: eventsPredicate, completion: {(_ reminders: [Any]?) -> Void in
            
            print("Fetching")
            for reminder: EKReminder? in reminders as? [EKReminder?] ?? [EKReminder?]() {
                if let reminder = reminder {
                    if (reminder.title == self.name){
                        print("ASSIGNMENT: Assignment \"\(self.name)\" already exists in Reminder.")
                        if(reminder.isCompleted) {
                            self.reminderStatus = .completed
                        } else {
                            self.reminderStatus = .inProgress
                        }
                        
                        completion(false)
                        return
                    }
                }
            }
            
            let reminder:EKReminder = EKReminder(eventStore: store)
            reminder.title = self.getName()
            
            if(!(self.getDueDate() == nil)) {
                
                let alarmTime = self.getDueDate()!
                let alarm = EKAlarm(absoluteDate: alarmTime)
                reminder.addAlarm(alarm)
            } else {
                print("ASSIGNMENT: Assignment \"\(self.name)\" has no due date.")
            }
            
            reminder.calendar = classCalendar

            if(self.type == .completed) {
                print("ASSIGNMENT: Assignment \(self.name) is marked as complete.")
                reminder.isCompleted = true
            }
            
            
            do {
                try store.save(reminder, commit: true)
            } catch {
                print("Cannot save reminder")
                print(error)
                completion(false)
                return
            }

            
            print("ASSIGNMENT: Reminder for assignment \"\(self.name)\" created")
            
            if(reminder.isCompleted) {
                self.reminderStatus = .completed
            } else {
                self.reminderStatus = .inProgress
            }
            completion(true)
            return
            
            
        })
    }
    
    
    
    
    func setHiddenStatus(hidden: Bool) {
        UpdateValue.saveToLocal(key: "\(assignmentID)_IS_HIDDEN", value: hidden)
        self.hidden = hidden
    }
    
    func getHiddenStatus() -> Bool {
        return hidden
    }


    
}

enum AssignmentType : CustomStringConvertible, Identifiable, Encodable, Decodable {
    case missing
    case inProgress
    case noDateDue
    case completed
    
    var count: Int {
        return 4
    }
    
    var description : String {
        switch self {
        // Use Internationalization, as appropriate.
        case .missing: return "Missing"
        case .inProgress: return "In Progress"
        case .noDateDue: return "No Due Date"
        case .completed: return "Completed"
            
        }
    }
    var id: String {
            switch self {
            case .missing: return "missing"
            case .inProgress: return "inProgress"
            case .noDateDue: return "noDateDue"
            case .completed: return "completed"
            }
        }
}

enum ReminderType : CustomStringConvertible, Identifiable, Encodable, Decodable {
    case notAdded
    case inProgress
    case completed
    
    var count: Int {
        return 3
    }
    
    var description : String {
        switch self {
        // Use Internationalization, as appropriate.
        case .notAdded: return "Not Added"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
            
        }
    }
    var id: String {
            switch self {
            case .notAdded: return "notAdded"
            case .inProgress: return "inProgress"
            case .completed: return "completed"
            }
        }
}

