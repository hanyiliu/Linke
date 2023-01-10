//
//  Classroom.swift
//  Linker
//
//  Created by Hanyi Liu on 12/7/22.
//

import GoogleSignIn
import GoogleSignInSwift
import SwiftyJSON
import EventKit

class Classroom: Identifiable {
    private var name: String
    private var courseID: String
    private var assignments: [Assignment] = []
    private var calendarIdentifier: String?
    private var hidden = false
    private var store: EKEventStore
    
    init(name: String, courseID: String, placeholder: Bool = false, store: EKEventStore) {
        self.store = store
        self.name = name
        self.courseID = courseID
        print("Initializing class \(name)")
        
        if let savedCalendarIdentifier = UserDefaults.standard.data(forKey: "\(courseID)_CALENDAR_IDENTIFIER") {
            if let decoded = try? JSONDecoder().decode(String.self, from: savedCalendarIdentifier
            ) {
                calendarIdentifier = decoded
            }
        }
        
        if let savedHidden = UserDefaults.standard.data(forKey: "\(courseID)_IS_HIDDEN") {
            if let decoded = try? JSONDecoder().decode(Bool.self, from: savedHidden
            ) {
                hidden = decoded
            }
        }

        queryAssignments(courseID: courseID, callback: initializeAssignments)
        
        
    }
    
    func initializeList(store: EKEventStore) {
        
        var existingCalendar: EKCalendar?
        
        // Loop through all calendars to find the calendar with the specified name
        for calendar in store.calendars(for: .reminder) {
            if(calendar.title == name) {
                existingCalendar = calendar
                print("\(name)'s Reminders list already exists.")
                // Skip the remainder of the current iteration and move on to the next iteration
                continue
            }
        }
        
        // If the calendar with the specified name does not exist, create a new calendar
        if(existingCalendar == nil) {
            let classCalendar = EKCalendar(for: .reminder, eventStore: store)
            classCalendar.title = name
  
            classCalendar.source = store.defaultCalendarForNewReminders()?.source
            
            
            
            
            
            calendarIdentifier = classCalendar.calendarIdentifier
            
            do {
                try store.saveCalendar(classCalendar, commit: true)
            }  catch {
                print("Error while trying to save new Reminder List")
                print(error)
            }
        } else {
            calendarIdentifier = existingCalendar!.calendarIdentifier
        }
    }
    
    private func queryAssignments(courseID: String, callback: ((_: JSON, _: String) -> Void)?) {
        if let user = GIDSignIn.sharedInstance.currentUser {
            user.authentication.do { authentication, error in
                guard error == nil else { return }
                guard let authentication = authentication else { return }
                
                // Get the access token to attach it to a REST or gRPC request.
                let accessToken = authentication.accessToken
                
                guard let url = URL(string: "https://classroom.googleapis.com/v1/courses/\(courseID)/courseWork") else{
                    return
                }
                
                
                
                
                
                // create get request
                
                
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                
                let task = URLSession.shared.dataTask(with: request) { data, response, error in
                    guard let data = data, error == nil else {
                        print(error?.localizedDescription ?? "No data")
                        return
                    }
                    
                    let json = try? JSON(data: data)
                    guard let json = json else {
                        print("JSON file invalid")
                        return
                    }
                    
                    callback!(json, accessToken)
                    
                }
                task.resume()
            }
        }
    }
    
    func changeToSystemTimeZone(_ date: Date, from: TimeZone, to: TimeZone = TimeZone.current) -> Date {
        let sourceOffset = from.secondsFromGMT(for: date)
        let destinationOffset = to.secondsFromGMT(for: date)
        let timeInterval = TimeInterval(destinationOffset - sourceOffset)
        return Date(timeInterval: timeInterval, since: date)
    }
    
    private func initializeAssignments(assignmentsJSON: JSON, accessToken: String) {

        
        for (_,courseWork):(String, JSON) in assignmentsJSON["courseWork"] {
//            print("COURSEWORK")
//            print(courseWork)
            let dateJSON = courseWork["dueDate"].dictionaryValue
            let timeJSON = courseWork["dueTime"].dictionaryValue
            var date: Date?
            if(dateJSON.count == 0) {
                date = nil
            } else {
                let calendar = Calendar.current
                if(timeJSON.count == 0) {
                    let dateComponents = DateComponents(year: dateJSON["year"]?.intValue,
                                                        month: dateJSON["month"]?.intValue,
                                                        day: dateJSON["day"]?.intValue
                    )
                    date = calendar.date(from: dateComponents)!
                } else {
                    let dateComponents = DateComponents(year: dateJSON["year"]?.intValue,
                                                        month: dateJSON["month"]?.intValue,
                                                        day: dateJSON["day"]?.intValue,
                                                        hour: timeJSON["hours"]?.intValue,
                                                        minute: timeJSON["minutes"]?.intValue
                    )
                    date = calendar.date(from: dateComponents)!


                    let sourceOffset = TimeZone(abbreviation: "UTC")!.secondsFromGMT(for: date!)
                    let destinationOffset = TimeZone.current.secondsFromGMT(for: date!)
                    let timeInterval = TimeInterval(destinationOffset - sourceOffset)

                    date = Date(timeInterval: timeInterval, since: date!)
//
//                    print("Final date:")

                }
                

            }
            
            
            
            
            
            guard let url = URL(string: "https://classroom.googleapis.com/v1/courses/\(courseID)/courseWork/\(courseWork["id"].stringValue)/studentSubmissions") else{
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                var assignmentType: AssignmentType
                if let d = date {
                    guard let data = data, error == nil else {
                        print(error?.localizedDescription ?? "No data")
                        return
                    }
                    
                    let json = try? JSON(data: data)
                    guard let json = json else {
                        print("JSON file invalid")
                        return
                    }

                    
                    let submissionState = json["studentSubmissions"][0]["state"]
                    
                    
                    switch submissionState {
                    case "NEW", "CREATED", "RECLAIMED_BY_STUDENT":
                        assignmentType = .inProgress
                        break
                    case "TURNED_IN", "RETURNED":
                        assignmentType = .completed
                        break
                    default:
                        assignmentType = .completed
                    }
                    
                    if (assignmentType == .inProgress && d.compare(Date()) == .orderedAscending) {
                        assignmentType = .missing
                    }
                } else {
                    assignmentType = .noDateDue
                }
                
                self.assignments.append(Assignment(name: courseWork["title"].stringValue, id: courseWork["id"].stringValue, dueDate: date, classroom: self, type: assignmentType, store: self.store))
                
                
            }
            task.resume()
            
            

            
            
            
        }
        
    }
    
    
    func getName() -> String {
        return name
    }
    
    func getAssignments() -> [Assignment] {
        return assignments
    }
    
    func getAssignments(type: AssignmentType) -> [Assignment]{
        var matches: [Assignment] = []
        for assigned in assignments {
            if(assigned.getType() == type) {
                matches.append(assigned)
            }
        }
        return matches
    }
    
    func getVisibleAssignments(type: AssignmentType) -> [Assignment] {
        var visible: [Assignment] = []
        
        for assignment in assignments {
            if(assignment.getHiddenStatus() == false && assignment.getType() == type) {
                visible.append(assignment)
            }
        }
        return visible
    }
    
    func getVisibleAssignments() -> [Assignment] {
        var visible: [Assignment] = []
        
        for assignment in assignments {
            if(assignment.getHiddenStatus()) {
                visible.append(assignment)
            }
        }
        return visible
    }
    
    
    func getIdentifier() -> String? {
        return calendarIdentifier
    }
    
    func setIdentifier(calendarIdentifier: String) {
        
        if let encoded = try? JSONEncoder().encode(calendarIdentifier) {
            UserDefaults.standard.set(encoded, forKey: "\(courseID)_CALENDAR_IDENTIFIER")
        }
        
        self.calendarIdentifier = calendarIdentifier
    }
    
    func setHiddenStatus(hidden: Bool) {

        if let encoded = try? JSONEncoder().encode(hidden) {

            UserDefaults.standard.set(encoded, forKey: "\(courseID)_IS_HIDDEN")
        }
        
        self.hidden = hidden
    }
    
    func getHiddenStatus() -> Bool {
        return hidden
    }
    
    
    
}
