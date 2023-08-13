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
    private var archived = false
    private var store: EKEventStore
    
    var teacherName = ""
    var teacherID: String

    var classrooms: ClassroomAPI
    
    var notAdded: [String] = []
    var loadedAssignments = 0
    
    init(classrooms: ClassroomAPI, name: String, courseID: String, placeholder: Bool = false, teacherID: String, store: EKEventStore, manualRefresh: Bool = false, archived: Bool?) async {

        self.store = store
        self.name = name
        self.courseID = courseID
        self.classrooms = classrooms
        
        self.teacherID = teacherID
        self.teacherName = await getTeacherName()
        print("Teacher name of class \(name) is \(teacherName)")
        calendarIdentifier = UpdateValue.loadFromLocal(key: "\(courseID)_CALENDAR_IDENTIFIER", type: "String") as? String
        if let id = calendarIdentifier {
            if(store.calendars(for: .reminder).first(where: { $0.calendarIdentifier == id }) == nil) {
                calendarIdentifier = nil
            }
        }

        if let a = archived {
            setArchiveStatus(archived: a)
        }
        
        if let status = UpdateValue.loadFromLocal(key: "\(courseID)_IS_HIDDEN", type: "Bool") as? Bool {
            hidden = status
        }
        

        if(!self.archived) {

            assignments = await queryAssignments(manualRefresh: manualRefresh)


        }
        
        DispatchQueue.main.async {
            print("Finished loading classroom \(self.name)")
            classrooms.loadedClassroomCount += 1
            classrooms.update()
        }
        
        
    }
    
    ///Create Reminders list under classroom name.
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
    
    ///Automatically create new Reminders list. Differs from initializeList in that it first checks for if there is an existing list under the classroom's name and matches it's list identifier.
    func checkAndInitializeList(store: EKEventStore, useListIfExisting: Bool = false) -> Bool? {
        if (getIdentifier() != nil &&
            store.calendars(for: .reminder).first(where: { $0.calendarIdentifier == getIdentifier()! }) != nil &&
            store.calendars(for: .reminder).first(where: { $0.calendarIdentifier == getIdentifier()! })?.title == getName()) {
            print("There already is an existing list under this classroom's name.")
            if useListIfExisting {
                setIdentifier(calendarIdentifier: getIdentifier()!)
            }
            return false
        } else {
            initializeList(store: store)
            if let listIdentiifer = getIdentifier() {
                if store.calendars(for: .reminder).first(where: { $0.calendarIdentifier == listIdentiifer }) != nil {
                    return true
                } else {
                    print("Invalid calendar identifier")
                    removeIdentifier()
                }
            }
            return nil
        }
    }
    
    ///Call to initialize [Assignment] assignments.
    func queryAssignments(manualRefresh: Bool = false) async -> [Assignment] {
        
        await withCheckedContinuation { continuation in
            initializeAssignments(manualRefresh: manualRefresh) { assignments in

                continuation.resume(returning: assignments)


                self.classrooms.update()

            }
        }
        
    }
    
    ///Convert given time to current timezone's time.
    func changeToSystemTimeZone(_ date: Date, from: TimeZone, to: TimeZone = TimeZone.current) -> Date {
        let sourceOffset = from.secondsFromGMT(for: date)
        let destinationOffset = to.secondsFromGMT(for: date)
        let timeInterval = TimeInterval(destinationOffset - sourceOffset)
        return Date(timeInterval: timeInterval, since: date)
    }
    
    ///Initialize [Assignment] assignments
    func initializeAssignments(manualRefresh: Bool = false, completion: @escaping ([Assignment]) -> Void) {
        if let user = GIDSignIn.sharedInstance.currentUser {
            user.authentication.do { authentication, error in
                Task {
                    guard error == nil else { return }
                    guard let authentication = authentication else { return }
                    let accessToken = authentication.accessToken
                    guard let url = URL(string: "https://classroom.googleapis.com/v1/courses/\(self.courseID)/courseWork") else { //For entire classroom. Queried once for every classroom.
                        return
                    }
                                
                    var request = URLRequest(url: url)
                    request.httpMethod = "GET"
                    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                    var data: Data

                    do {
                        (data,_) = try await URLSession.shared.data(for: request) //take 1-2 seconds
                        let json = try? JSON(data: data)

                        guard let json = json else {
                            print("CLASSROOM: JSON file invalid")
                            completion([])
                            return
                        }
                        
                        let assignmentsJSON = json
                        var assignments: [Assignment] = []
                        for (_,courseWork):(String, JSON) in assignmentsJSON["courseWork"] {

                            if let hidden = UpdateValue.loadFromLocal(key: "\(courseWork["id"])_IS_HIDDEN", type: "Bool") as? Bool {
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
                                date = self.getDateFromJSON(timeJSON: timeJSON, dateJSON: dateJSON)
                            }
                            var assignmentType: AssignmentType

                            if !manualRefresh, let data = UpdateValue.loadFromLocal(key: "\(courseWork["id"])_TYPE", type: "AssignmentType") as? AssignmentType {
                                assignmentType = data
                            } else if let d = date {
                                assignmentType = await Assignment.fetchAssignmentType(accessToken: accessToken, courseID: self.courseID, assignmentID: courseWork["id"].stringValue, dueDate: d)
                            } else {
                                assignmentType = .noDateDue
                            }

                            assignments.append(await Assignment(name: courseWork["title"].stringValue, id: courseWork["id"].stringValue, dueDate: date, classroom: self, type: assignmentType, store: self.store, manualRefresh: manualRefresh))
                        }
                        completion(assignments)
                    } catch {
                        print("CLASSROOM: Interesting")
                        completion([])
                    }
                }
            }
        }
    }
    
    func getDateFromJSON(timeJSON: [String: JSON], dateJSON: [String: JSON]) -> Date {
        var date: Date
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
            let sourceOffset = TimeZone(abbreviation: "UTC")!.secondsFromGMT(for: date)
            let destinationOffset = TimeZone.current.secondsFromGMT(for: date)
            let timeInterval = TimeInterval(destinationOffset - sourceOffset)
            date = Date(timeInterval: timeInterval, since: date)
        }
        
        return date
    }
    
    ///Return name of classroom
    func getName() -> String {
        return name
    }
    
    ///Asyncronously return [Assignment] assignments.  Will call queryAssignments if it's not initialized.
    func getAssignments() async -> [Assignment] {
        if(assignments.count == 0) {
            assignments = await queryAssignments()
            
        }
        return assignments
    }
    
    ///Syncronously return [Assignment] assignments. Will call queryAssignments if it's not initialized.
    func getAssignments() -> [Assignment] {

        return assignments
    }

    ///Asyncronously return [Assignment] assignments. matching given type  Will call queryAssignments if it's not initialized.
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

        return matches
    }
    
    ///Syncronously return visible [Assignment] assignments. Will NOT call queryAssignments if it's not initialized.
    func getVisibleAssignments(type: AssignmentType) -> [Assignment] {
        var visible: [Assignment] = []
        
        for assignment in assignments {
            if(assignment.getHiddenStatus() == false && assignment.getType() == type) {

                visible.append(assignment)
            }
        }
        return visible
    }
    
    ///Syncronously return visible [Assignment] assignments. Will NOT call queryAssignments if it's not initialized.
    func getHiddenAssignments() -> [Assignment] {
        var hidden: [Assignment] = []
        
        for assignment in assignments {
            if(assignment.getHiddenStatus()) {
                hidden.append(assignment)
            }
        }
        return hidden
    }
    
    ///Return classroom's assigned Reminder list's identifier. Return null if no list assigned.
    func getIdentifier() -> String? {
        return calendarIdentifier
    }
    
    ///Set classroom's assigned Reminder lists' identifier.
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
    
    ///Unlinks classroom's assigned Reminder list.
    func removeIdentifier() {
        self.calendarIdentifier = nil
        self.classrooms.update()
    }
    
    ///Set classroom's hidden status.
    func setHiddenStatus(hidden: Bool) {

        UpdateValue.saveToLocal(key: "\(courseID)_IS_HIDDEN", value: hidden)
        
        self.hidden = hidden
    }
    
    ///Returns classroom's hidden status.
    func getHiddenStatus() -> Bool {
        return hidden
    }
    
    ///Set classroom's hidden status.
    func setArchiveStatus(archived: Bool) {
        setHiddenStatus(hidden: archived)
        self.archived = archived
    }
    
    ///Returns classroom's hidden status.
    func getArchiveStatus() -> Bool {
        return archived
    }
    
    ///Returns classroom's course ID.
    func getCourseID() -> String {
        return courseID
    }
    
    ///Set [Assignment] assignments to given value.
    func setAssignments(assignments: [Assignment]) {
        self.assignments = assignments
    }
    
    ///Update any interface using current classroom.
    func toggleUpdate() {
        update.toggle()
    }
    
    ///Asyncronously dd all assignments matching stated type to Reminders.
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
    
    ///Returns if current classroom is finished loading.
    func isReady() -> Bool {
        if(loadedAssignments == assignments.count) {
            return true
        }
        return false
    }
    
    ///Increment count of loaded assignments.
    func incrementLoadedAssignmentCount() {
        loadedAssignments += 1
        if(loadedAssignments == assignments.count) {
            self.classrooms.update()
        }

    }
    
    ///Add given assignment to the not added list.
    func appendNotAddedAssignment(assignment: Assignment) {
        notAdded.append(assignment.getID())
        self.classrooms.update()
    }
    
    ///Remove given assignment from the not added list. If it isn't in there, nothing happens.
    func removeNotAddedAssignment(assignment: Assignment) {
        if let j = notAdded.firstIndex(of: assignment.getID()) {
            notAdded.remove(at: j)
        }
        self.classrooms.update()
    }
    
    func getTeacherName() async -> String {
        await withCheckedContinuation { continuation in
            fetchTeacherName() { name in
                continuation.resume(returning: name)
                self.classrooms.update()
            }
        }
    }
    ///Fetch name of the course's teacher. Do not call directly.
    func fetchTeacherName(completion: @escaping (String) -> Void) {
        if let user = GIDSignIn.sharedInstance.currentUser {
            user.authentication.do { authentication, error in
                Task {
                    guard error == nil else {
                        return
                    }
                    guard let authentication = authentication else {
                        return
                    }
                    
                    // Get the access token to attach it to a REST or gRPC request.
                    let accessToken = authentication.accessToken
                    let urlString = "https://classroom.googleapis.com/v1/courses/\(self.courseID)/teachers/\(self.teacherID)"
                    if let url = URL(string: urlString) {
                        var request = URLRequest(url: url)
                        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                        
                        do {
                            let (data, _) = try await URLSession.shared.data(for: request)

                            if let json = try? JSON(data: data) {
                                let profile = json["profile"].dictionaryValue
                                let nameDict = profile["name"]!.dictionaryValue
                                completion(nameDict["fullName"]!.stringValue)
                            } else {
                                print("Error trying to fetch teacher name: cannot serialize JSON.")
                            }
                        } catch {
                            print("Error trying to fetch teacher name: \(error)")
                        }
                    } else {
                        print("Error trying to fetch teacher name: Invalid URL")
                              
                    }
                }
            }
        }
    }
    
    
}
