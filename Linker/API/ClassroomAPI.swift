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
    
    @Published var update = false
    init() {
        
        if(!ClassroomAPI.started) {
            print("Creating Google Classroom API")
            ClassroomAPI.started = true
            initializer(callback: initializeClassrooms)
        } else {
            print("Google Classroom API already created")
            
        }
        
    }
    
    private func initializer(callback: ((_: JSON) -> Void)?) {
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
                    
                    let json = try? JSON(data: data)
                    guard let json = json else {
                        print("JSON file invalid")
                        return
                    }
                    
                    callback!(json)
                    
                }
                task.resume()
            }
        }
    }
    
    private func initializeClassrooms(classroomJson: JSON) {
        let store = EKEventStore()
        for (_,subJson):(String, JSON) in classroomJson["courses"] {
            classrooms.append(Classroom(name: subJson["name"].stringValue, courseID: subJson["id"].stringValue, store: store))
        }
        
        print("ClassroomAPI finished loading")
        self.update = .random()
        //print("please tell me this is synced")
        
        //print(classrooms.count)
        
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
    

    
}
