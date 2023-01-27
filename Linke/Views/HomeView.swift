//
//  HomeView.swift
//  Linker
//
//  Created by Hanyi Liu on 12/6/22.
//

import SwiftUI
import GoogleSignIn
import GoogleMobileAds
import EventKit

struct HomeView: View {
    @State public var update: Bool = false
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
    
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    
    let store = EKEventStore()
    
    var body: some View {
        let user = GIDSignIn.sharedInstance.currentUser
        
        if let profile = user?.profile {
            NavigationView {
                Form {
                    Section {
                        Button("Add All Assignments to Reminders") {
                            for classroom in classrooms.getVisibleClassrooms() {
                                guard (classroom.getIdentifier() != nil && store.calendars(for: .reminder).first(where: { $0.calendarIdentifier == classroom.getIdentifier()! }) != nil) else {
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
                                        Task {
                                            addedAssignments = await classrooms.addAllAssignments(store: store, isCompleted: isCompleted, chosenTypes: items)
                                            chooseAssignments = false
                                            showAfterDismiss = true
                                        }
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
                            }.presentationDetents([PresentationDetent.medium])
                        }
                        )
                    }
                    Section(header: Text("Your Classrooms")) {
                        ForEach(classrooms.getVisibleClassrooms()) { classroom in
                            NavigationLink(destination: ClassroomView(classroom: classroom, classrooms: classrooms)) {
                                Text(classroom.getName()) /*systemImage: classroom.statusImage).onAppear() {
                                    //print("CLassroom image changed: \(classroom.statusImage)")
                                }*/
                            }
                        }.onDelete { indexSet in
                            classrooms.getVisibleClassrooms()[indexSet.first!].setHiddenStatus(hidden: true)
                        }
                    }
                    Section {
                        NavigationLink(destination: HiddenClassroomView(classrooms: classrooms)) {
                            Text("Hidden Classrooms")
                        }.foregroundColor(Color.gray)
                        Button("Sign Out") {
                            GIDSignIn.sharedInstance.signOut()
                            classrooms.clear()
                            viewRouter.currentPage = .googleSignIn
                        }.foregroundColor(Color.red)
                    }
                    
                    
                    Logo()
                
                }
                
                .navigationTitle("Hello, \(profile.name)")
                .navigationBarItems(trailing: Button(action: {
                    classrooms.refresh()
                }) {
                    Image(systemName: "arrow.clockwise").foregroundColor(.blue)
                }
                )
                
            }.navigationViewStyle(StackNavigationViewStyle())
            Banner()
            
        } else {
            NavigationView {}.onAppear() {
                viewRouter.currentPage = .googleSignIn
            }
        }
    }
}

struct Logo: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    var body: some View {
        Section {
            HStack(alignment: .bottom) {
                VStack {
                    Image("GrayIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: UIScreen.main.bounds.size.width/4)
                    Text("Linke v1.0")
                        .foregroundColor(.gray)
                        .font(.system(size: 11.0))
                    Text("Ⓒ Hanyi Liu 2023")
                        .foregroundColor(.gray)
                        .font(.system(size: 11.0))
                }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .listRowInsets(EdgeInsets())
                .background(Color(.systemGroupedBackground))
        
    }
}
