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
    
    var classrooms: ClassroomAPI
    
    var notAdded: [String] = []
    var loadedAssignments = 0
    
    init(classrooms: ClassroomAPI, name: String, courseID: String, placeholder: Bool = false, store: EKEventStore, manualRefresh: Bool = false, archived: Bool?) async {
        ////print("CHECKPOINT 4")
        //print("CHECKPOINT 3.1.1 (\(name)): \(Double(round(100 * Date().timeIntervalSince(classrooms.startTime))/100))")
        //classrooms.//startTime = Date()
        self.store = store
        self.name = name
        self.courseID = courseID
        self.classrooms = classrooms
        //self.statusImage = "minus.circle.fill"
        //print("CLASSROOM: Initializing class \(name)")

        
        calendarIdentifier = UpdateValue.loadFromLocal(key: "\(courseID)_CALENDAR_IDENTIFIER", type: "String") as? String
        if let id = calendarIdentifier {
            if(store.calendars(for: .reminder).first(where: { $0.calendarIdentifier == id }) == nil) {
                calendarIdentifier = nil
            }
        }
        //print("CHECKPOINT 3.1.2 (\(name): \(Double(round(100 * Date().timeIntervalSince(classrooms.startTime))/100))")
        //classrooms.//startTime = Date()
        //print("CLASSROOM: Classroom \(name) courseID is \(courseID)")
        if let status = UpdateValue.loadFromLocal(key: "\(courseID)_IS_HIDDEN", type: "Bool") as? Bool {
            
            //print("CLASSROOM: hidden status is \(status)")
            hidden = status
        } else if let a = archived {
            hidden = a
        } else {
            print("CLASSROOM: something went wrong")
        }
        //print("CHECKPOINT 3.1.3 (\(name): \(Double(round(100 * Date().timeIntervalSince(classrooms.startTime))/100))")
        //classrooms.//startTime = Date()
        if(!hidden) {
            //Task {
                ////print("CHECKPOINT 5")
                //print("CLASSROOM: Starting to loading assignments for class \(name)")
                assignments = await queryAssignments(manualRefresh: manualRefresh)
            //print("CHECKPOINT 3.1.4 (\(name): \(Double(round(100 * Date().timeIntervalSince(classrooms.startTime))/100))")
            //classrooms.//startTime = Date()
            //}
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
            
            
            
            
            
            setIdentifier(calendarIdentifier: classCalendar.calendarIdentifier)
            
            do {
                try store.saveCalendar(classCalendar, commit: true)
            }  catch {
                print("CLASSROOM: Error while trying to save new Reminder List")
                print(error)
            }
        } else {
            setIdentifier(calendarIdentifier: existingCalendar!.calendarIdentifier)
        }
    }
    
    func queryAssignments(manualRefresh: Bool = false) async -> [Assignment] {
        
        await withCheckedContinuation { continuation in
            initializeAssignments(manualRefresh: manualRefresh) { assignments in
                ////print("CHECKPOINT 9")
                //print("CHECKPOINT 3.1.3.1 (\(self.name): \(Date().timeIntervalSince(self.classrooms.startTime))")
                //self.classrooms.//startTime = Date()
                continuation.resume(returning: assignments)

                //self.setStatusImage(statusImage: "checkmark.circle.fill")
                
                self.classrooms.update()
                ////print("CHECKPOINT 10")
                //print("CLASSROOM: Finished loading for \(self.name)")
                
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
        //print("CHECKPOINT 3.1.3.0.1 (\(self.name): \(Double(round(100 * Date().timeIntervalSince(self.classrooms.startTime))/100))")
        //self.classrooms.//startTime = Date()
        ////print("CHECKPOINT 6")
        if let user = GIDSignIn.sharedInstance.currentUser {
            user.authentication.do { authentication, error in
                Task {
                    ////print("CHECKPOINT 7")
                    //print("CHECKPOINT 3.1.3.0.2 (\(self.name): \(Double(round(100 * Date().timeIntervalSince(self.classrooms.startTime))/100))")
                    //self.classrooms.//startTime = Date()
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
                    //print("CHECKPOINT 3.1.3.0.3 (\(self.name): \(Double(round(100 * Date().timeIntervalSince(self.classrooms.startTime))/100))")
                    //self.classrooms.//startTime = Date()
                    do {
                        (data,_) = try await URLSession.shared.data(for: request) //take 1-2 seconds
                        let json = try? JSON(data: data)
                        //print("CHECKPOINT 3.1.3.0.4 (\(self.name): \(Double(round(100 * Date().timeIntervalSince(self.classrooms.startTime))/100))")
                        //self.classrooms.//startTime = Date()
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
                            //print("CHECKPOINT 3.1.3.0.4.1 (\(self.name): \(Double(round(100 * Date().timeIntervalSince(self.classrooms.startTime))/100))")
                            //self.classrooms.//startTime = Date()
                            if let hidden = UpdateValue.loadFromLocal(key: "\(courseWork["id"])_IS_HIDDEN", type: "Bool") as? Bool {
//                                print("name: \(courseWork["title"].stringValue)")
//                                print("hidden: \(hidden)")
                                if(hidden) {
                                    continue
                                }
                            }
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
                            //print("CHECKPOINT 3.1.3.0.4.2 (\(self.name): \(Double(round(100 * Date().timeIntervalSince(self.classrooms.startTime))/100))")
                            //self.classrooms.//startTime = Date()
                            //TODO: Add check for if type is already stored
                            if !manualRefresh, let data = UpdateValue.loadFromLocal(key: "\(courseWork["id"])_TYPE", type: "AssignmentType") as? AssignmentType {
                                //print("CLASSROOM: Assignment \"\(courseWork["title"].stringValue)\" from classroom \(self.name) already has a stored type")
                                assignmentType = data
                            } else if let d = date {
                                print("Sending request to classroom API for assignment")
                                guard let url = URL(string: "https://classroom.googleapis.com/v1/courses/\(self.courseID)/courseWork/\(courseWork["id"].stringValue)/studentSubmissions") else{ //For every assignment. Queried once for every assignment.
                                    completion([])
                                    return
                                }
                                var request = URLRequest(url: url)
                                request.httpMethod = "GET"
                                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                                var data: Data
                                do {
                                    //print("CLASSROOM: Querying request for assignment \"\(courseWork["title"].stringValue)\" from classroom \(self.name)")
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
                            ////print("CHECKPOINT 7.1")
                            //print("CHECKPOINT 3.1.3.0.4.3 (\(self.name): \(Double(round(100 * Date().timeIntervalSince(self.classrooms.startTime))/100))")
                            //self.classrooms.//startTime = Date()

                            assignments.append(await Assignment(name: courseWork["title"].stringValue, id: courseWork["id"].stringValue, dueDate: date, classroom: self, type: assignmentType, store: self.store, manualRefresh: manualRefresh))
                            //print("CHECKPOINT 3.1.3.0.4.4 (\(self.name): \(Double(round(100 * Date().timeIntervalSince(self.classrooms.startTime))/100))")
                            //self.classrooms.//startTime = Date()

                        }
                        //print("CHECKPOINT 3.1.3.0.5 (\(self.name): \(Double(round(100 * Date().timeIntervalSince(self.classrooms.startTime))/100))")
                        //self.classrooms.//startTime = Date()
                        //end of old initializeAssignments
                        ////print("CHECKPOINT 8")
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
        //print("CLASSROOM: Matches size:")
        //print(matches.count)
        return matches
    }
    
    func getVisibleAssignments(type: AssignmentType) -> [Assignment] {
        var visible: [Assignment] = []
        
        for assignment in assignments {
            if(assignment.getHiddenStatus() == false && assignment.getType() == type) {
                
                //print("assignment: \(assignment.getName())")
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
        
        self.notAdded = []
        self.loadedAssignments = 0
        for assign in assignments {
            Task {
                await assign.checkIfIsAdded()
            }
        }
        
        self.classrooms.update()
    }
    
    func removeIdentifier() {
        self.calendarIdentifier = nil
        self.classrooms.update()
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
        if(loadedAssignments == assignments.count) {
            return true
        }
        return false
    }
    
    func incrementLoadedAssignmentCount() {
        loadedAssignments += 1
        if(loadedAssignments == assignments.count) {
            self.classrooms.update()
        }
//        if(loadedAssignments > assignments.count) {
//            self
//            print("wtf")
//        }
    }

    
    func appendNotAddedAssignment(assignment: Assignment) {
        notAdded.append(assignment.getID())
        self.classrooms.update()
    }
    
    func removeNotAddedAssignment(assignment: Assignment) {
        if let j = notAdded.firstIndex(of: assignment.getID()) {
            notAdded.remove(at: j)
        }
        self.classrooms.update()
    }
    
    

    
    
}
