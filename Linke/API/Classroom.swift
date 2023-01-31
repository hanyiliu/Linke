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
import UserNotifications

class Classroom: Identifiable, ObservableObject {
    
    @Published var update = false
    //@Published var statusImage: String
    private var name: String
    private var courseID: String
    private var assignments: [Assignment] = []
    private var calendarIdentifier: String?
    private var hidden = false
    private var store: EKEventStore
    private var ready = false
    private var classrooms: ClassroomAPI
    
    init(classrooms: ClassroomAPI, name: String, courseID: String, placeholder: Bool = false, store: EKEventStore, manualRefresh: Bool = false, archived: Bool?) {
        self.store = store
        self.name = name
        self.courseID = courseID
        self.classrooms = classrooms
        //self.statusImage = "minus.circle.fill"
        print("CLASSROOM: Initializing class \(name)")

        
        calendarIdentifier = UpdateValue.loadFromLocal(key: "\(courseID)_CALENDAR_IDENTIFIER", type: "String") as? String
        print("CLASSROOM: Classroom \(name) courseID is \(courseID)")
        if let status = UpdateValue.loadFromLocal(key: "\(courseID)_IS_HIDDEN", type: "Bool") as? Bool {
            
            print("CLASSROOM: hidden status is \(status)")
            hidden = status
        } else if let a = archived {
            hidden = a
        } else {
            print("CLASSROOM: something went wrong")
        }

        if(!hidden) {
            Task {
                print("CLASSROOM: Starting to loading assignments for class \(name)")
                if manualRefresh {
                    assignments = await queryAssignments(manualRefresh: true)
                } else {
                    assignments = await queryAssignments()
                }
            }
        }
        
        
    }
    
    func initializeList(store: EKEventStore) {
        
        var existingCalendar: EKCalendar?
        
        // Loop through all calendars to find the calendar with the specified name
        for calendar in store.calendars(for: .reminder) {
            if(calendar.title == name) {
                existingCalendar = calendar
                print("CLASSROOM: \(name)'s Reminders list already exists.")
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
                print("CLASSROOM: Error while trying to save new Reminder List")
                print(error)
            }
        } else {
            calendarIdentifier = existingCalendar!.calendarIdentifier
        }
    }
    
    func queryAssignments(manualRefresh: Bool = false) async -> [Assignment] {
        await withCheckedContinuation { continuation in
            initializeAssignments(manualRefresh: manualRefresh) { assignments in
                continuation.resume(returning: assignments)
                DispatchQueue.main.async {
                    self.toggleUpdate()
                }
                //self.setStatusImage(statusImage: "checkmark.circle.fill")
                
                
                self.ready = true
                self.classrooms.update.toggle()
                print("CLASSROOM: Finished loading for \(self.name)")
                
            }
           
        }
        
    }
    
    func changeToSystemTimeZone(_ date: Date, from: TimeZone, to: TimeZone = TimeZone.current) -> Date {
        let sourceOffset = from.secondsFromGMT(for: date)
        let destinationOffset = to.secondsFromGMT(for: date)
        let timeInterval = TimeInterval(destinationOffset - sourceOffset)
        return Date(timeInterval: timeInterval, since: date)
    }
    
    func initializeAssignments(manualRefresh: Bool = false, completion: @escaping ([Assignment]) -> Void) {
        if let user = GIDSignIn.sharedInstance.currentUser {
            user.authentication.do { authentication, error in
                Task {
                    guard error == nil else { return }
                    guard let authentication = authentication else { return }
                    // Get the access token to attach it to a REST or gRPC request.
                    let accessToken = authentication.accessToken
                    guard let url = URL(string: "https://classroom.googleapis.com/v1/courses/\(self.courseID)/courseWork") else{ //For entire classroom. Queried once for every classroom.
                        return
                    }
                    
                    
                                       
                    var request = URLRequest(url: url)
                    request.httpMethod = "GET"
                    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                    var data: Data
                    
                    do {
                        (data,_) = try await URLSession.shared.data(for: request)
                        let json = try? JSON(data: data)
                        guard let json = json else {
                            print("CLASSROOM: JSON file invalid")
                            completion([])
                            return
                        }
                        //start of old initializeAssignemnts
                        let assignmentsJSON = json
                        var assignments: [Assignment] = []
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
                                }
                            }
                            var assignmentType: AssignmentType
                            
                            //TODO: Add check for if type is already stored
                            if !manualRefresh, let data = UpdateValue.loadFromLocal(key: "\(courseWork["id"])_TYPE", type: "AssignmentType") as? AssignmentType {
                                print("CLASSROOM: Assignment \"\(courseWork["title"].stringValue)\" from classroom \(self.name) already has a stored type")
                                assignmentType = data
                            } else if let d = date {
                                guard let url = URL(string: "https://classroom.googleapis.com/v1/courses/\(self.courseID)/courseWork/\(courseWork["id"].stringValue)/studentSubmissions") else{ //For every assignment. Queried once for every assignment.
                                    completion([])
                                    return
                                }
                                var request = URLRequest(url: url)
                                request.httpMethod = "GET"
                                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                                var data: Data
                                do {
                                    print("CLASSROOM: Querying request for assignment \"\(courseWork["title"].stringValue)\" from classroom \(self.name)")
                                    (data,_) = try await URLSession.shared.data(for: request)
                                    
                                    let json = try? JSON(data: data)
                                    guard let json = json else {
                                        print("CLASSROOM: JSON file invalid")
                                        completion([])
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
                                } catch {
                                    print("CLASSROOM: Invalid data")
                                    assignmentType = .noDateDue
                                }
                            } else {
                                assignmentType = .noDateDue
                            }
                            assignments.append(await Assignment(name: courseWork["title"].stringValue, id: courseWork["id"].stringValue, dueDate: date, classroom: self, type: assignmentType, store: self.store))
                        }
                        
                        //end of old initializeAssignments
                        completion(assignments)
                    } catch {
                        print("CLASSROOM: Interesting")
                        completion([])
                    }
                }
            }
        }
    }
    
    
    func getName() -> String {
        return name
    }
    
    func getAssignments() async -> [Assignment] {
        if(assignments.count == 0) {
            assignments = await queryAssignments()
            
        }
        return assignments
    }
    
    func getAssignments() -> [Assignment] {

        return assignments
    }

    func getAssignments(type: AssignmentType) async -> [Assignment]{
        if(assignments.count == 0) {
            assignments = await queryAssignments()
        }
        var matches: [Assignment] = []
        for assigned in assignments {
            if(assigned.getType() == type) {
                matches.append(assigned)
            }
        }
        print("CLASSROOM: Matches size:")
        print(matches.count)
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
    
    func getHiddenAssignments() -> [Assignment] {
        var hidden: [Assignment] = []
        
        for assignment in assignments {
            if(assignment.getHiddenStatus()) {
                hidden.append(assignment)
            }
        }
        return hidden
    }
    
    func getIdentifier() -> String? {
        return calendarIdentifier
    }
    
    func setIdentifier(calendarIdentifier: String) {

        UpdateValue.saveToLocal(key: "\(courseID)_CALENDAR_IDENTIFIER", value: calendarIdentifier)
        
        self.calendarIdentifier = calendarIdentifier
        self.classrooms.update.toggle()
    }
    
    func setHiddenStatus(hidden: Bool) {

        UpdateValue.saveToLocal(key: "\(courseID)_IS_HIDDEN", value: hidden)
        
        self.hidden = hidden
    }
    
    func getHiddenStatus() -> Bool {
        return hidden
    }

    
    func getCourseID() -> String {
        return courseID
    }
    
    func setAssignments(assignments: [Assignment]) {
        self.assignments = assignments
    }
    
    func toggleUpdate() {
        update.toggle()
    }
    
    func addAssignments(isCompleted: [Bool], items: [AssignmentType]) async -> Int {
        var count = 0
        var matchedAssignments: [Assignment] = []
        for i in 0...isCompleted.count-1 {
            if(isCompleted[i]) {
                matchedAssignments += self.getVisibleAssignments(type: items[i])
            }
        }
        for assigned in matchedAssignments {
            if(!assigned.isAdded()) {
                if(await assigned.addToReminders(store: store)) {
                    count += 1
                }
            }
        }
        return count
    }
    
    func isReady() -> Bool {
        return self.ready
    }
//    func setStatusImage(statusImage: String) {
//        print("Status image changed to \(statusImage)")
//        self.statusImage = statusImage
//        //HomeView.update.toggle()
//    }
    
    
}
