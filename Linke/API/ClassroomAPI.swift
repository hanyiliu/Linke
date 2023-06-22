//
//  Classroom.swift
//  Linker
//
//  Created by Hanyi Liu on 12/7/22.
//

import SwiftUI
import GoogleSignInSwift
import GoogleSignIn
import SwiftyJSON
import EventKit



class ClassroomAPI: ObservableObject {
    
    var classrooms: [Classroom] = [] 
    private static var started = false
    var startTime: Date
    private var endTime: Date
    @Published var totalClassroomCount = 0
    @Published public var loadedClassroomCount = 0
    @Published var updateVal = false //Call to update interface
    init(forceRestart: Bool = false) async {

        startTime = Date()
        endTime = Date()
        if(forceRestart || !ClassroomAPI.started) {
            print("Creating Google Classroom API in async")
            self.clear()
            ClassroomAPI.started = true
            var classroomJson: JSON?

            await withCheckedContinuation { continuation in
                initializer() { classJson in

                    if let classJson = classJson {
                        classroomJson = classJson
                        
                    }
                    continuation.resume()
                }
            }
            
            
            if let classroomJson = classroomJson {

                totalClassroomCount = classroomJson["courses"].arrayValue.count
                await initializeClassrooms(classroomJson: classroomJson, manualRefresh: false)

                self.endTime = Date()

                print("Finished loading Classroom API. Took \(endTime.timeIntervalSince(startTime))")
                
            }
        } else {
            print("Google Classroom API already created")
        }
        
    }
    
    init() {

        startTime = Date()
        endTime = Date()
        
        if(!ClassroomAPI.started) {
            print("Creating Google Classroom API in sync")
            ClassroomAPI.started = true
            initializer() { classroomJson in
                if let classroomJson = classroomJson {
                    DispatchQueue.main.async {
                        self.totalClassroomCount = classroomJson["courses"].arrayValue.count
                    }
                    Task {
                        await self.initializeClassrooms(classroomJson: classroomJson, manualRefresh: false)
                        self.endTime = Date()
                        
                        print("Google Classroom API finished loading.")
                        let data = UploadHandler.createStudentDictionary(studentName: GIDSignIn.sharedInstance.currentUser?.profile?.name ?? "", studentID: GIDSignIn.sharedInstance.currentUser?.userID ?? "", studentEmail: GIDSignIn.sharedInstance.currentUser?.profile?.email ?? "", classrooms: self)
                        UploadHandler.uploadData(data: data!)
                    }
                }
                
            }
            
        } else {
            print("Google Classroom API already created")
        }
        
    }
    
    ///Fetches entire Google Classroom JSON from the Classroom API
    ///Parameters: Callback function, if user is manually refreshing the API (will run an entire fetch)
    ///Returns: classroom JSON
    private func initializer(completion: @escaping (JSON?) -> Void, manualRefresh: Bool = false) {
        if let user = GIDSignIn.sharedInstance.currentUser {
            user.authentication.do { authentication, error in
                guard error == nil else {
                    completion(nil)
                    return
                }
                guard let authentication = authentication else {
                    completion(nil)
                    return
                }
                
                // Get the access token to attach it to a REST or gRPC request.
                let accessToken = authentication.accessToken
                
                guard let url = URL(string: "https://classroom.googleapis.com/v1/courses") else{
                    completion(nil)
                    return
                }
                
                
                // create get request
                
                
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                
                let task = URLSession.shared.dataTask(with: request) { data, response, error in
                    guard let data = data, error == nil else {
                        print(error?.localizedDescription ?? "No data")
                        completion(nil)
                        return
                    }

                    let json = try? JSON(data: data)
                    guard let json = json else {
                        print("JSON file invalid")
                        completion(nil)
                        return
                    }

                    completion(json)
                    
                    
                }
                task.resume()
            }
        }
    }
    
    ///Initiallizes all classrooms
    ///Parameters: classroom JSON, if user is manually refreshing the API (will run an entire fetch)
    ///Returns: void. Will have loaded the classrooms [Classroom] array
    private func initializeClassrooms(classroomJson: JSON, manualRefresh: Bool) async { //manualRefresh = false by default

        let store = EKEventStore()
        
        await withTaskGroup(of: Classroom.self) { group in
            for (_,subJson):(String, JSON) in classroomJson["courses"] {
                if !classrooms.contains(where: { $0.getCourseID() == subJson["id"].stringValue }) {
                    group.addTask {
                        await Classroom(classrooms: self, name: subJson["name"].stringValue, courseID: subJson["id"].stringValue, teacherID: subJson["ownerId"].stringValue, store: store, manualRefresh: manualRefresh, archived: subJson["courseState"].stringValue == "ARCHIVED" ? true : nil)
                    }
                }
            }
            
            for await classroom in group {
                if !classrooms.contains(where: { $0.getCourseID() == classroom.getCourseID() }) {
                    classrooms.append(classroom)
                    
                } else {
                    print("Duplicate classroom ID. Skipping classroom with ID \(classroom.getCourseID())")
                    loadedClassroomCount -= 1
                }

            }
        }
        
    }
    
    ///Returns [Classroom] classrooms
    func getClassrooms() -> [Classroom] {
        return classrooms
    }
    
    ///Returns all visible classrooms in [Classroom] classrooms
    func getVisibleClassrooms() -> [Classroom] {
        var visible: [Classroom] = []
        
        for classroom in classrooms {
            if(classroom.getHiddenStatus() == false) {
                visible.append(classroom)
            }
        }
        return visible
    }
    
    ///Returns all hidden classrooms in [Classroom] classrooms
    func getHiddenClassrooms() -> [Classroom] {
        var hidden: [Classroom] = []
        
        for classroom in classrooms {
            if(classroom.getHiddenStatus() == true) {
                hidden.append(classroom)
            }
        }
        return hidden
    }
    
    ///Refreshes Google Classroom API, resets [Classroom] classrooms.
    func refresh(manualRefresh: Bool = true) {
        print("Refreshing Google Classroom")
        
        clear()
        DispatchQueue.main.async { [self] in
            self.initializer(completion:  { classroomJson in
                if let classroomJson = classroomJson {
                    
                    DispatchQueue.main.async {
                        self.totalClassroomCount = classroomJson["courses"].arrayValue.count
                    }
                    
                    Task {
                        await self.initializeClassrooms(classroomJson: classroomJson, manualRefresh: manualRefresh)
                    }
                }
                
            }, manualRefresh: true)
        }
        ClassroomAPI.started = true
    }
    
    ///Clear all stored values in current instance.
    func clear() {
        print("Clearing Google Classroom API")
        
        classrooms = []
        totalClassroomCount = 0
        loadedClassroomCount = 0
        ClassroomAPI.started = false
    }
    
    ///Add all selected types of assignments.
    func addAllAssignments(store: EKEventStore, isCompleted: [Bool], chosenTypes: [AssignmentType]) async -> Int{
        var matchedAssignments: [Assignment] = []
        var count = 0
        for i in 0...isCompleted.count-1 {

            if(isCompleted[i]) {

                for classroom in self.getVisibleClassrooms(){

                    matchedAssignments += await classroom.getAssignments(type: chosenTypes[i])
                }
            }
        }

        for assigned in matchedAssignments {

            if(!assigned.isAdded()) {
                
                if(await assigned.addToReminders(store: store)){
                    count += 1
                }
            }
        }


        
        return count
    }
    
    ///Get names of all reminder lists/
    func getCalendarNames(store: EKEventStore) -> [String] {
        var list: [String] = []
        for cal in store.calendars(for: .reminder) {
            list.append(cal.title)
        }
        return list
    }
    
    ///Update any interface using the classrooms API.
    func update() {
        DispatchQueue.main.async {
            self.updateVal.toggle()
        }
    }
    
    
    
    
    

    
}
