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
    private var added: Bool
    private var store: EKEventStore
    private var assignmentID: String
    private var hidden = false
    
    
    init(name: String, id: String, dueDate: Date?, classroom: Classroom, type: AssignmentType, store: EKEventStore) async {
        self.store = store
        self.name = name
        self.dueDate = dueDate
        self.classroom = classroom
        self.type = type
        self.added = false
        self.assignmentID = id
        
        UpdateValue.saveToLocal(key: "\(assignmentID)_TYPE", value: type)
        
        if let identifier = classroom.getIdentifier() {
            if let calendar = store.calendars(for: .reminder).first(where: { $0.calendarIdentifier == identifier }) {
                let eventsPredicate = store.predicateForReminders(in: [calendar])
                store.fetchReminders(matching: eventsPredicate, completion: {(_ reminders: [Any]?) -> Void in
                    for reminder: EKReminder? in reminders as? [EKReminder?] ?? [EKReminder?]() {
                        if let reminder = reminder {
                            if (reminder.title == self.name){
                                print("Assignment \"\(self.name)\" exists in Reminder.")
                                self.added = true
                                
                                
                                return
                            }
                        }
                    }
                })
            }
            
        }
        
        if let data = UpdateValue.loadFromLocal(key: "\(assignmentID)_IS_HIDDEN", type: "Bool") as? Bool {
            hidden = data
        }

                             
            
        
        
    }
    
    func getName() -> String {
        return name
    }
    
    func getDueDate() -> Date? {
        return dueDate
    }
    
    func getType() -> AssignmentType {
        return type
    }
    
    func isAdded() -> Bool {
        return added
    }
    
    func addToReminders(store: EKEventStore){
        
        store.requestAccess(to: .event) { (granted, error) in
            // handle the response here
        }
//        if classroom.getIdentifier() == nil {
//            classroom.initializeList(store: store)
//        }
        var classCalendar: EKCalendar
        if let calendar = store.calendars(for: .reminder).first(where: { $0.calendarIdentifier == classroom.getIdentifier()! }) {
            classCalendar = calendar
        } else {
            print("Invalid calendar identifier while trying to add reminder \(name) from classroom \(classroom.getName())")
            return
        }
        let eventsPredicate = store.predicateForReminders(in: [classCalendar])
        store.fetchReminders(matching: eventsPredicate, completion: {(_ reminders: [Any]?) -> Void in
            for reminder: EKReminder? in reminders as? [EKReminder?] ?? [EKReminder?]() {
                if let reminder = reminder {
                    if (reminder.title == self.name){
                        print("Assignment \"\(self.name)\" already exists in Reminder.")
                        self.added = true
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
                print("Assignment \"\(self.name)\" has no due date.")
            }
            
            reminder.calendar = classCalendar
            
            do {
                try store.save(reminder, commit: true)
            } catch {
                print("Cannot save reminder")
                print(error)
                return
            }
            print("Reminder for assignment \"\(self.name)\" created")
            
            self.added = true
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
