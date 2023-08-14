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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    
    @StateObject var viewRouter: ViewRouter
    @StateObject var classrooms: ClassroomAPI
    @StateObject var team = Team()
    
    @State var showAlert = false
    @State var alertType = AlertType.statusReport
    @State var firstTimeAlert = false
    @State var manualRefreshAlert = false
    @State private var chooseAssignments = false
    @State private var isCompleted = [false, false, false, false]
    @State private var items = [AssignmentType.inProgress, .missing, .noDateDue, .completed]
    @State private var showSignOutConfirmation = false
    
    @State private var missingListsCount = 0
    @State private var missingListsClassrooms: [Classroom] = []
    
    let store = EKEventStore()
    
    
    var body: some View {
        let user = GIDSignIn.sharedInstance.currentUser
        
        if let profile = user?.profile {
            NavigationView {
                Form {
                    Section {

                        Button("Add All Assignments to Reminders") {
                            
                            missingListsCount = 0
                            missingListsClassrooms = []
                            
                            for classroom in classrooms.getVisibleClassrooms() {
                                if(classroom.getIdentifier() == nil || store.calendars(for: .reminder).first(where: { $0.calendarIdentifier == classroom.getIdentifier()! }) == nil) {
                                    print("\(classroom.getName()) has no active list.")
                                    missingListsCount += 1
                                    missingListsClassrooms.append(classroom)
                                }
                            }
                            
                            if missingListsCount > 0 {
                                alertType = .noList
                                showAlert = true
                            } else {
                                chooseAssignments = true
                            }
                        }
                        .alert(isPresented: $showAlert) {
                            switch alertType {
                            case .noList:
                                return Alert(
                                    title: Text("Missing List"),
                                    message: Text("\(missingListsCount) \(missingListsCount == 1 ? "classroom has" : "classrooms have") no active Reminders list. Do you want them to be automatically generated?"),
                                    primaryButton: .default(Text("No, I'll create them manually")),
                                    secondaryButton: .default(Text("Yes, create them automatically"), action: {
                                        var successCount = 0
                                        for classroom in missingListsClassrooms {
                                            if let success = classroom.checkAndInitializeList(store: store, useListIfExisting: true), success {
                                                successCount += 1
                                            }
                                        }
                                        if successCount == missingListsCount {
                                            chooseAssignments = true
                                        } else {
                                            alertType = .error
                                            showAlert = true
                                        }
                                    })
                                    )
                            case .statusReport:
                                return Alert(
                                    title: Text("Success!"),
                                    message: Text("Added \(classrooms.addedAssignments) new assignments"),
                                    dismissButton: .default(Text("Cool!"), action: { classrooms.addedAssignments = 0 })
                                )
                            case .error:
                                return Alert(title: Text("Something went wrong. Please try again."))
                            default:
                                return Alert(title: Text("You discovered a secret!"), dismissButton: .default(Text("Cool!")))
                            }
                        }
                        .sheet(isPresented: $chooseAssignments, content: {
                            Form {
                                Section {
                                    Button(action: {
                                        Task {
                                            chooseAssignments = false
                                            await classrooms.addAllAssignments(store: store, isCompleted: isCompleted, chosenTypes: items)
                                            
                                            alertType = .statusReport
                                            showAlert = true
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
                        })
                        .disabled(classrooms.addedAssignments != 0 || classrooms.loadedClassroomCount != classrooms.totalClassroomCount)
                        
                        if classrooms.addedAssignments != 0 {
                            VStack {
                                Text("Added \(classrooms.addedAssignments) assignments so far...")
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                ProgressView(value: Double(1), total: Double(1))
                                    .progressViewStyle(LinearProgressViewStyle())
                                    .padding()
                            }

                        }
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
                        if classrooms.loadedClassroomCount != classrooms.totalClassroomCount {
                            VStack {
                                Text("Loaded \(classrooms.loadedClassroomCount) out of \(classrooms.totalClassroomCount) classrooms (incl. hidden)")
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                ProgressView(value: Double(classrooms.loadedClassroomCount), total: Double(classrooms.totalClassroomCount))
                                    .progressViewStyle(LinearProgressViewStyle())
                                    .padding()
                            }

                        }
                    }
                   
                    Section() {
                        NavigationLink(destination: TeamView(team: team)) {
                            Text("Your Team")
                        }
                    }
                    
                    Section {
                        NavigationLink(destination: HiddenClassroomView(classrooms: classrooms)) {
                            Text("Hidden Classrooms")
                        }.foregroundColor(Color.gray)
                        
                        NavigationLink(destination: SettingsView()) {
                            Text("Settings")
                        }
                        
                        NavigationLink(destination: HelpView(viewRouter: viewRouter, fromHome: true)) {
                            Text("Help")
                        }

                        Button(action: {
                            showSignOutConfirmation = true
                        }) {
                            Text("Sign Out")
                                .foregroundColor(.red)
                        }
                        .alert(isPresented: $showSignOutConfirmation) {
                            Alert(
                                title: Text("Sign Out"),
                                message: Text("Are you sure you want to sign out?"),
                                primaryButton: .destructive(Text("Sign Out"), action: {
                                    GIDSignIn.sharedInstance.signOut()
                                    classrooms.clear()
                                    team.clearLocalTeamData()
                                    UpdateValue.saveToLocal(key: "IS_FIRST_TIME", value: true)
                                    viewRouter.currentPage = .googleSignIn
                                }),
                                secondaryButton: .cancel()
                            )
                        }
                    }
                    
                    
                    Logo()
                
                }
                
                .navigationTitle("Hello, \(profile.name)")
                .navigationBarItems(trailing:
                    Button(action: {
                    classrooms.refresh()
                    manualRefreshAlert = true
                    team.refreshTeam()
                }) {
                    Image(systemName: "arrow.clockwise").foregroundColor(.blue)
                }.alert(isPresented: $manualRefreshAlert) {
                    Alert(
                        title: Text("Time Warning"),
                        message: Text("Manually refreshing the Classroom API might take a few minutes! If you just want to quickly refresh the API, simply reopen Linke.")
                        )
                }
                )
                
            }.navigationViewStyle(StackNavigationViewStyle())
            .onAppear {
                if let isFirstTime = UpdateValue.loadFromLocal(key: "IS_FIRST_TIME", type: "Bool") as? Bool {
                    if isFirstTime {
                        firstTimeAlert = true
                        UpdateValue.saveToLocal(key: "IS_FIRST_TIME", value: false)
                    }
                
                } else {
                    firstTimeAlert = true
                    UpdateValue.saveToLocal(key: "IS_FIRST_TIME", value: false)
                }
             }
            .alert(isPresented: $firstTimeAlert) {
                Alert(
                    title: Text("Welcome!"),
                    message: Text("The first time you open Linke, it might take a minute or two to load all your classrooms. This is normal, and will only happen on this initial load.")
                    )
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active && !classrooms.currentlyRefreshing {
                    classrooms.refresh(manualRefresh: false)
                    team.refreshTeam()
                }
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
