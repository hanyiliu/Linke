//
//  HomeView.swift
//  Linker
//
//  Created by Hanyi Liu on 12/6/22.
//

import SwiftUI
import GoogleSignIn
import EventKit


struct HomeView: View {
    
    @StateObject var viewRouter: ViewRouter
    @StateObject var classrooms: ClassroomAPI
    @State var showAlert = false
    @State var addedAssignments = 0
    @State var alertType = AlertType.statusReport
    @State private var missingListForClassroom = ""
    
    @State private var chooseAssignments = false
    @State private var showAfterDismiss = false
    @State private var isCompleted = [false, false, false, false]
    @State private var items = [AssignmentType.inProgress, .missing, .noDateDue, .completed]
    let store = EKEventStore()
    
    var body: some View {
        let user = GIDSignIn.sharedInstance.currentUser
        
        if let profile = user?.profile {
            NavigationView {
                Form {
                    Section {
                        Button("Add All Assignments to Reminders") {
                            
                            for classroom in classrooms.getVisibleClassrooms() {
                                guard (classroom.getIdentifier() != nil && store.calendar(withIdentifier: classroom.getIdentifier()!) != nil) else {
                                    print("\(classroom.getName()) has no active list.")
                                    missingListForClassroom = classroom.getName()
                                    alertType = .noList
                                    showAlert = true
                                    
                                    return
                                }
                            }
                            
                            chooseAssignments = true

                        }.alert(isPresented: $showAlert) {
                            switch alertType {
                            case .noList:
                                return Alert(
                                    title: Text(""),
                                    message: Text("\(missingListForClassroom) has no active list. Please select a list, then try again.")
                                    )
                                
                            case .statusReport:
                                return Alert(
                                    title: Text(""),
                                    message: Text("Finished adding assignments. \n Added \(addedAssignments) new assignments"),
                                    dismissButton: .default(Text("Cool!"))
                                
                                )
                            default:
                                return Alert(title: Text("You discovered a secret!"), dismissButton: .default(Text("Cool!")))
                            }
                        }.sheet(isPresented: $chooseAssignments, onDismiss: {
                            if(showAfterDismiss) {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    alertType = .statusReport
                                    showAlert = true
                                    showAfterDismiss = false
                                    isCompleted = [false, false, false, false]
                                }
                                
                            }
                        }, content: {
                            
                            Form {
                                Section {
                                    Button(action: {
                                        addedAssignments = 0
                                        var matchedAssignments: [Assignment] = []
                                        
                                        for i in 0...isCompleted.count-1 {
                                            for classroom in classrooms.getVisibleClassrooms(){
                                                if(isCompleted[i]) {
                                                    matchedAssignments += classroom.getAssignments(type: items[i])
                                                }
                                            }
                                        }
                                        
                                        for assigned in matchedAssignments {
                                            if(!assigned.isAdded()) {
                                                assigned.addToReminders(store: store)
                                                addedAssignments += 1
                                                
                                            }
                                        }
                                        
                                        chooseAssignments = false
                                        showAfterDismiss = true
                                        
                                    }) {
                                        Text("Add Assignments")
                                    }
                                }
                                List {
                                    ForEach(0 ..< items.count, id: \.self) { index in
                                        HStack {
                                            Toggle(isOn: $isCompleted[index]) {
                                                Text(items[index].description)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        )
                    }
                    Section(header: Text("Your Classrooms")) {
                        ForEach(classrooms.getVisibleClassrooms()) { classroom in
                            NavigationLink(destination: ClassroomView(classroom: classroom, classrooms: classrooms)) {
                                Text(classroom.getName())
                                
                                
                            }
                        }.onDelete { indexSet in
                            classrooms.getVisibleClassrooms()[indexSet.first!].setHiddenStatus(hidden: true)
                        }
                    }
                    Section {
                        Button("Sign Out") {
                            GIDSignIn.sharedInstance.signOut()
                            viewRouter.currentPage = .googleSignIn
                            
                            
                        }.foregroundColor(Color.red)
                        
                    }
                    
                    
                }
                .navigationTitle("Hello, \(profile.name)")
                .navigationBarItems(trailing: Button(action: {
                    classrooms.update.toggle()
                }) {
                    Image(systemName: "arrow.clockwise").foregroundColor(.blue)
                }
                )

            }.onAppear() {
                viewRouter.scheduleAppRefresh()
            }
            
        } else {
            NavigationView {}.onAppear() {
                viewRouter.currentPage = .googleSignIn
            }
        }
        
    }
    

    

}
