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
    private var added: Bool = true
    private var store: EKEventStore
    private var assignmentID: String
    private var hidden = false
    
    
    init(name: String, id: String, dueDate: Date?, classroom: Classroom, type: AssignmentType, store: EKEventStore) async {
        self.store = store
        self.name = name
        self.dueDate = dueDate
        self.classroom = classroom
        self.type = type
        self.assignmentID = id
        
        UpdateValue.saveToLocal(key: "\(assignmentID)_TYPE", value: type)
        
        
        if let data = UpdateValue.loadFromLocal(key: "\(assignmentID)_IS_HIDDEN", type: "Bool") as? Bool {
            setHiddenStatus(hidden: data)
        }

        
        checkIfIsAdded()
                             
            
        
        
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
        return added
    }
    
    func checkIfIsAdded() {
        if let identifier = classroom.getIdentifier() {
            if let calendar = store.calendars(for: .reminder).first(where: { $0.calendarIdentifier == identifier }) {
                let eventsPredicate = store.predicateForReminders(in: [calendar])
                store.fetchReminders(matching: eventsPredicate, completion: {(_ reminders: [Any]?) -> Void in
                    var found = false
                    for reminder: EKReminder? in reminders as? [EKReminder?] ?? [EKReminder?]() {
                        if let reminder = reminder {
                            if (reminder.title == self.name){
                                //print("ASSIGNMENT: Assignment \"\(self.name)\" exists in Reminder.")
                                found = true
                            }
                        }
                    }
                    if !found {
                        self.setAddedStatus(added: false)
                    } else {
                        self.setAddedStatus(added: true)
                    }
                    self.classroom.incrementLoadedAssignmentCount()
                })
            } else {
                self.setAddedStatus(added: false)
                self.classroom.incrementLoadedAssignmentCount()
            }
            
        } else {
            self.setAddedStatus(added: false)
            self.classroom.incrementLoadedAssignmentCount()
        }
    }
    
    func setAddedStatus(added: Bool) {
        self.added = added
        if !added {
            self.classroom.appendNotAddedAssignment(assignment: self)
        } else {
            self.classroom.removeNotAddedAssignment(assignment: self)
        }
        //self.classroom.classrooms.update.toggle()
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
                        self.setAddedStatus(added: true)
                        
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
            
            self.setAddedStatus(added: true)
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
