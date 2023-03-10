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
    
    @Published var updateVal = false
    init() {
        
        if(!ClassroomAPI.started) {
            print("Creating Google Classroom API")
            ClassroomAPI.started = true
            initializer(callback: initializeClassrooms)
        } else {
            print("Google Classroom API already created")
            
        }
        
    }
    
    private func initializer(callback: ((_: JSON, _: Bool) -> Void)?, manualRefresh: Bool = false) {
        if let user = GIDSignIn.sharedInstance.currentUser {
            user.authentication.do { authentication, error in
                guard error == nil else { return }
                guard let authentication = authentication else { return }
                
                // Get the access token to attach it to a REST or gRPC request.
                let accessToken = authentication.accessToken
                
                guard let url = URL(string: "https://classroom.googleapis.com/v1/courses") else{
                    return
                }
                
                
                // create post request
                
                
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                
                let task = URLSession.shared.dataTask(with: request) { data, response, error in
                    guard let data = data, error == nil else {
                        print(error?.localizedDescription ?? "No data")
                        return
                    }
                    //print("data")
                    //print(data)
                    let json = try? JSON(data: data)
                    guard let json = json else {
                        print("JSON file invalid")
                        return
                    }
                    //print("json")
                    //print(json)
                    if manualRefresh {
                        callback!(json, true)
                    } else {
                        callback!(json, false)
                    }
                    
                }
                task.resume()
            }
        }
    }
    
    private func initializeClassrooms(classroomJson: JSON, manualRefresh: Bool) { //manualRefresh = false by default
        let store = EKEventStore()
        for (_,subJson):(String, JSON) in classroomJson["courses"] {
//            print("JSON FILE:")
//            print(subJson)
            if manualRefresh {
                classrooms.append(Classroom(classrooms: self, name: subJson["name"].stringValue, courseID: subJson["id"].stringValue, store: store, manualRefresh: true, archived: subJson["courseState"].stringValue == "ARCHIVED" ? true : nil))
            } else {
                classrooms.append(Classroom(classrooms: self, name: subJson["name"].stringValue, courseID: subJson["id"].stringValue, store: store, archived: subJson["courseState"].stringValue == "ARCHIVED" ? true : nil))
            }
        }
        
        print("ClassroomAPI finished loading")
        
        print("Classrooms count: \(classrooms.count)")
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
        initializer(callback: initializeClassrooms, manualRefresh: true)
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
            if(isCompleted[i]) {
                for classroom in self.getVisibleClassrooms(){
                    print(classroom.getName())
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
        print("addedAssignments: \(count)")

        
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
