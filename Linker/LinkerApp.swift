//
//  LinkerApp.swift
//  Linker
//
//  Created by Hanyi Liu on 12/6/22.
//

import SwiftUI
import GoogleSignIn
import EventKit
    

@main
struct LinkerApp: App {
    @StateObject var viewRouter = ViewRouter()
    
    var body: some Scene {
        WindowGroup {
            ContentView(viewRouter: viewRouter)
            
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
            
                .onAppear {
                    GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
                        
                        print("User previously logged in")
                        
                        viewRouter.currentPage = .reminderAccess
                        // Check if `user` exists; otherwise, do something with `error`
                    }
                }
        }.backgroundTask(.appRefresh("com.hanyiliu.Linker.refreshAssignments")) {
            await viewRouter.scheduleAppRefresh()
            
            let classrooms = ClassroomAPI()
            let store = EKEventStore()
            for classroom in classrooms.getVisibleClassrooms() {
                guard (classroom.getIdentifier() != nil && store.calendar(withIdentifier: classroom.getIdentifier()!) != nil) else {
                    print("\(classroom.getName()) has no active list.")
                    
                    return
                }
            }
            
            print("RUNNING BACKGROUND TASK")
            
//            let addedAssignments = 0
//            var matchedAssignments: [Assignment] = []
//
//            for i in 0...isCompleted.count-1 {
//                for classroom in classrooms.getVisibleClassrooms(){
//                    if(isCompleted[i]) {
//                        matchedAssignments += classroom.getAssignments(type: items[i])
//                    }
//                }
//            }
//
//            for assigned in matchedAssignments {
//                if(!assigned.isAdded()) {
//                    assigned.addToReminders(store: store)
//                    addedAssignments += 1
//
//                }
//            }
        } 
    }
    

    
}

