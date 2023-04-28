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
    
    private var classrooms: [Classroom] = []
    private static var started = false;
    var startTime: Date
    private var endTime: Date
    
    @Published var updateVal = false
    init(forceRestart: Bool = false) async {
        startTime = Date()
        endTime = Date()
        if(forceRestart || !ClassroomAPI.started) {
            print("Creating Google Classroom API in async")
            self.clear()
            ClassroomAPI.started = true
            var classroomJson: JSON?
            //print("CHECKPOINT 1: \(Double(round(100 * Date().timeIntervalSince(startTime))/100))")
            //startTime = Date()
            await withCheckedContinuation { continuation in
                initializer() { classJson in
                    //print("CHECKPOINT 2: \(Double(round(100 * Date().timeIntervalSince(self.startTime))/100))")
                    //self.//startTime = Date()
                    if let classJson = classJson {
                        classroomJson = classJson
                        
                    }
                    continuation.resume()
                }
            } //self.initializeClassrooms(classroomJson: classroomJson, manualRefresh: false)
            //print("CHECKPOINT 3: \(Double(round(100 * Date().timeIntervalSince(self.startTime))/100))")
            //startTime = Date()
            if let classroomJson = classroomJson {
                ////print("CHECKPOINT 1")
                await initializeClassrooms(classroomJson: classroomJson, manualRefresh: false)
                //print("Finished running initalizeClassrooms()")
                //print("CHECKPOINT 4: \(Double(round(100 * Date().timeIntervalSince(self.startTime))/100))")
                //startTime = Date()
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
                    Task {
                        await self.initializeClassrooms(classroomJson: classroomJson, manualRefresh: false)
                        self.endTime = Date()
                    }
                }
                
            }
            
        } else {
            print("Google Classroom API already created")
        }
        
    }
    /*
     completion(nil)
     return
     */
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
                    //print("data")
                    //print(data)
                    let json = try? JSON(data: data)
                    guard let json = json else {
                        print("JSON file invalid")
                        completion(nil)
                        return
                    }
                    //print("json")
                    //print(json)
                    completion(json)
                    
                    
                }
                task.resume()
            }
        }
    }
    
    private func initializeClassrooms(classroomJson: JSON, manualRefresh: Bool) async { //manualRefresh = false by default
        ////print("CHECKPOINT 2")
        let store = EKEventStore()
        for (_,subJson):(String, JSON) in classroomJson["courses"] {
//            print("JSON FILE:")
//            print(subJson)
            ////print("CHECKPOINT 3")
            //print("CHECKPOINT 3.1 (\(subJson["name"])): \(Double(round(100 * Date().timeIntervalSince(self.startTime))/100))")
            //startTime = Date()
            await classrooms.append(Classroom(classrooms: self, name: subJson["name"].stringValue, courseID: subJson["id"].stringValue, store: store, manualRefresh: manualRefresh, archived: subJson["courseState"].stringValue == "ARCHIVED" ? true : nil))
            //print("CHECKPOINT 3.2 (\(subJson["name"])): \(Double(round(100 * Date().timeIntervalSince(self.startTime))/100))")
            //startTime = Date()
        }
        
        //print("ClassroomAPI finished loading")
        
        //print("Classrooms count: \(classrooms.count)")
        //print("please tell me this is synced")
        self.update()
        
    }
    
    func getClassrooms() -> [Classroom] {
        return classrooms
    }
    
    func getVisibleClassrooms() -> [Classroom] {
        var visible: [Classroom] = []
        
        for classroom in classrooms {
            if(classroom.getHiddenStatus() == false) {
                visible.append(classroom)
            }
        }
        return visible
    }
    
    func getHiddenClassrooms() -> [Classroom] {
        var hidden: [Classroom] = []
        
        for classroom in classrooms {
            if(classroom.getHiddenStatus() == true) {
                hidden.append(classroom)
            }
        }
        return hidden
    }
    
    func refresh() {
        print("Recalling Google Classroom")
        
        classrooms = []
        DispatchQueue.main.async { [self] in
            self.initializer(completion:  { classroomJson in
                if let classroomJson = classroomJson {
                    Task {
                        await self.initializeClassrooms(classroomJson: classroomJson, manualRefresh: true)
                    }
                }
                
            }, manualRefresh: true)
        }
    }
    
    func clear() {
        print("Clearing Google Classroom API")
        
        classrooms = []
        ClassroomAPI.started = false
    }
    
    func addAllAssignments(store: EKEventStore, isCompleted: [Bool], chosenTypes: [AssignmentType]) async -> Int{
        var matchedAssignments: [Assignment] = []
        var count = 0
        for i in 0...isCompleted.count-1 {
            //print("i value \(i)")
            if(isCompleted[i]) {
                //print("isCompleted \(isCompleted[i])")
                for classroom in self.getVisibleClassrooms(){
                    //print(classroom.getName())
                    //print("ADDALLASSIGNMENTS: classroom not added count for \(classroom.getName()): \(classroom.notAdded.count)")
                    matchedAssignments += await classroom.getAssignments(type: chosenTypes[i])
                }
            }
        }
        //print("matchedAssignments count \(matchedAssignments.count)")
        for assigned in matchedAssignments {
            //print("isAdded? \(assigned.getName()) is \(assigned.isAdded())")
            if(!assigned.isAdded()) {
                
                if(await assigned.addToReminders(store: store)){
                    count += 1
                }
            }
        }
        //print("addedAssignments: \(count)")

        
        return count
    }
    
    func getCalendarNames(store: EKEventStore) -> [String] {
        var list: [String] = []
        for cal in store.calendars(for: .reminder) {
            list.append(cal.title)
        }
        return list
    }
    
    func update() {
        DispatchQueue.main.async {
            self.updateVal.toggle()
        }
    }
    
    
    
    
    

    
}
