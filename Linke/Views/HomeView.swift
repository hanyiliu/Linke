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
                        }
                        .alert(isPresented: $showAlert) {
                            switch alertType {
                            case .noList:
                                return Alert(
                                    title: Text("Missing List"),
                                    message: Text("\(missingListForClassroom) has no active Reminders list. Please select a list, then try again.")
                                    )
                            case .statusReport:
                                return Alert(
                                    title: Text("Success!"),
                                    message: Text("Added \(addedAssignments) new assignments"),
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
                                    }.disabled(isCompleted.allSatisfy({!$0}) ? true : false)
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
                                HStack {
                                    
                                    if(classroom.isReady()) {
                                        if(classroom.getIdentifier() == nil) {
                                            Image(systemName: "questionmark.circle.fill").foregroundColor(.red)
                                        } else {
                                            if(classroom.notAdded.count == 0) {
                                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                            } else {
                                                Image(systemName: "exclamationmark.circle.fill").foregroundColor(.orange)
                                            }
                                        }
                                    } else {
                                        Image(systemName: "minus.circle.fill").foregroundColor(.gray)
                                    }
                                    Text(classroom.getName())
                                }
                            }
                        }.onDelete { indexSet in
                            classrooms.getVisibleClassrooms()[indexSet.first!].setHiddenStatus(hidden: true)
                            classrooms.update()
                        }
                    }
                    Section {
                        NavigationLink(destination: HiddenClassroomView(classrooms: classrooms)) {
                            Text("Hidden Classrooms")
                        }.foregroundColor(Color.gray)
                        NavigationLink(destination: HelpView(viewRouter: viewRouter, fromHome: true)) {
                            Text("Help").onTapGesture {
                                viewRouter.currentPage = .help
                            }
                            
                        }
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
            .onAppear() {
                print("Appearing :)")
            }
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
                    Text("Linke v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String)")
                        .foregroundColor(.gray)
                        .font(.system(size: 11.0))
                    Text("??? Hanyi Liu 2023")
                        .foregroundColor(.gray)
                        .font(.system(size: 11.0))
                }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .listRowInsets(EdgeInsets())
                .background(Color(.systemGroupedBackground))
        
    }
}
