//
//  Assignment.swift
//  Linker
//
//  Created by Hanyi Liu on 12/8/22.
//

import Foundation
import EventKit
import SwiftyJSON

class Assignment: Identifiable {
    private var name: String
    private var dueDate: Date?
    private var classroom: Classroom
    var type: AssignmentType
    private var store: EKEventStore
    private var assignmentID: String
    private var hidden = false
    var reminderStatus = ReminderType.notAdded { //true: marked as completed, false: still in progress, nil: not added
        willSet { //before value is set
            if newValue == .notAdded {
                self.classroom.appendNotAddedAssignment(assignment: self)
            } else {
                self.classroom.removeNotAddedAssignment(assignment: self)
            }
        }
        
        didSet { //after value is set
            //print("Updated \(name) reminder status to \(reminderStatus)")
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
        
        UpdateValue.saveToLocal(key: "\(assignmentID)_TYPE", value: type)

        if let data = UpdateValue.loadFromLocal(key: "\(assignmentID)_IS_HIDDEN", type: "Bool") as? Bool {

            setHiddenStatus(hidden: data)
        }

        if let data = UpdateValue.loadFromLocal(key: "\(assignmentID)_REMINDER_STATUS", type: "ReminderType") as? ReminderType {

            reminderStatus = data
        } else {
            
        }

        if manualRefresh || reminderStatus == .notAdded || reminderStatus == .inProgress {

            await checkIfIsAdded()
        } else {
            self.classroom.incrementLoadedAssignmentCount()
        }
 
            
        
        
    }
    
    ///Get name of assignment.
    func getName() -> String {
        return name
    }
    
    ///Get due date of assignment.
    func getDueDate() -> Date? {
        return dueDate
    }
    
    /// Return dueDate in a readable String format.
    func formattedDueDate() -> String {
        guard let dueDate = dueDate else { return "No Due Date" }
        let dateFormatter = DateFormatter()
        
        let currentYear = Calendar.current.component(.year, from: Date())
        let dueYear = Calendar.current.component(.year, from: dueDate)
        
        if currentYear != dueYear {
            dateFormatter.dateFormat = "M/d/yy h:mm a"
        } else {
            dateFormatter.dateFormat = "M/d h:mm a"
        }
        
        return dateFormatter.string(from: dueDate)
    }
    
    ///Get ID of assignment.
    func getID() -> String {
        return assignmentID
    }
    
    ///Get type of assignment.
    func getType() -> AssignmentType {
        return type
    }
    
    ///Returns if assignment is added to Reminders.
    func isAdded() -> Bool {
        return !(reminderStatus == .notAdded)
    }
    
    ///Asyncronously check if the assignment is added to Reminders. Modifies reminderStatus accordingly.
    func checkIfIsAdded() async {

        if let identifier = classroom.getIdentifier() {

            if let calendar = store.calendars(for: .reminder).first(where: { $0.calendarIdentifier == identifier }) {

                let eventsPredicate = store.predicateForReminders(in: [calendar])

                let semaphore = DispatchSemaphore(value: 0)

                    store.fetchReminders(matching: eventsPredicate) { reminders in

                        var found = false
                        var foundReminder: EKReminder?
                        for reminder: EKReminder? in reminders ?? [EKReminder?]() {
                            if let reminder = reminder {
                                if (reminder.title == self.name){

                                    found = true
                                    foundReminder = reminder
                                }
                            }
                        }
                        if !found {

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

                //}
            } else {
                reminderStatus = .notAdded
                self.classroom.incrementLoadedAssignmentCount()
            }
            
        } else {
            reminderStatus = .notAdded
            self.classroom.incrementLoadedAssignmentCount()
        }

    }
    
    ///Asyncronously add assignment to Reminders.
    func addToReminders(store: EKEventStore) async -> Bool {
        store.requestAccess(to: .event) { (granted, error) in
            if let error = error {
                print("ASSIGNMENT: Error occurred while trying to add to Reminders:")
                print(error)
            }
        }

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
    
    ///Get Reminder's reminder that matches given values.
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
    
    ///Set hidden status of assignment.
    func setHiddenStatus(hidden: Bool) {
        UpdateValue.saveToLocal(key: "\(assignmentID)_IS_HIDDEN", value: hidden)
        self.hidden = hidden
    }
    
    ///Return hidden status of assignment.
    func getHiddenStatus() -> Bool {
        return hidden
    }
    
    static func fetchAssignmentType(accessToken: String, courseID: String, assignmentID: String, dueDate: Date) async -> AssignmentType {
        //print("Sending request to classroom API for assignment")
        guard let url = URL(string: "https://classroom.googleapis.com/v1/courses/\(courseID)/courseWork/\(assignmentID)/studentSubmissions") else{ //For every assignment. Queried once for every assignment.
            print("Invalid URL for assignment.")
            return .noDateDue
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        var data: Data
        do {
            (data,_) = try await URLSession.shared.data(for: request)
            
            let json = try? JSON(data: data)
            guard let json = json else {
                print("ASSIGNMENT: JSON file invalid")
                return .noDateDue
            }
            let submissionState = json["studentSubmissions"][0]["state"]
            switch submissionState {
            case "NEW", "CREATED", "RECLAIMED_BY_STUDENT":
                if (dueDate.compare(Date()) == .orderedAscending) {
                    return .missing
                } else {
                    return .inProgress
                }
            case "TURNED_IN", "RETURNED":
                return .completed
            default:
                return .completed
            }
        } catch {
            print("CLASSROOM: Invalid data")
            return .noDateDue
        }
    }
}

///Types: missing, inProgress, noDateDue, completed
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

///Types: notAdded, inProgress, completed
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

