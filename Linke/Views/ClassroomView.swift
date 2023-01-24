//
//  AssignmentView.swift
//  Linker
//
//  Created by Hanyi Liu on 12/9/22.
//

import SwiftUI
import EventKit

struct ClassroomView: View {
    @State private var chooseAssignments = false
    @State private var setList = false

    @State private var showAlert = false
    @State private var statusReport = false

    @State private var alertType = AlertType.noList

    @State private var classroomListName = "None"
    @State private var addedAssignments = 0
    @State private var showAfterDismiss = false

    @State private var isCompleted = [false, false, false, false]
    @State private var items = [AssignmentType.inProgress, .missing, .noDateDue, .completed]

    @State private var cont = false
    @StateObject var classroom: Classroom
    var classrooms: ClassroomAPI
    var store = EKEventStore()
    var body: some View {
        Form {
            Section {
                Button("Add Assignments to Reminders") {
                    if(classroom.getIdentifier() == nil || store.calendars(for: .reminder).first(where: { $0.calendarIdentifier == classroom.getIdentifier()! }) == nil) {
                        print("No list found")
                        alertType = .noList
                        showAlert = true
                        cont = false
                    } else {
                        chooseAssignments = true
                    }
                }
                .alert(isPresented: $showAlert) {
                    switch alertType {
                    case .noList:
                        return Alert(
                            title: Text(""),
                            message: Text("There is no chosen list. Please select a list, then try again.")
                            )
                    case .statusReport:
                        return Alert(
                            title: Text(""),
                            message: Text("Finished adding assignments. \n Added \(addedAssignments) new assignments out of \(classroom.getAssignments().count) assignments"),
                            dismissButton: .default(Text("Cool!"), action: {
                                statusReport.toggle()
                            })
                        )
                    default:
                        return Alert(title: Text("You found a secret!"))
                    }
                }
                .sheet(isPresented: $chooseAssignments, onDismiss: {
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
                                addedAssignments = classroom.addAssignments(isCompleted: isCompleted, items: items)
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
                    }.presentationDetents([PresentationDetent.medium])
                }
                )
                HStack {
                    Text("Reminder List")
                    Spacer()
                    NavigationLink(destination: ChooseListView(classroomListName: classroomListName, classroom: classroom)) {
                        Text(classroomListName)
                    }.foregroundColor(Color.gray)
                    .onAppear() {
                        if let listIdentiifer = classroom.getIdentifier() {
                            //if let calendar = store.calendar(withIdentifier: listIdentiifer) {
                            if let calendar = store.calendars(for: .reminder).first(where: { $0.calendarIdentifier == listIdentiifer }){
                                classroomListName = calendar.title
                            } else {
                                print("Invalid calendar identifier")
                            }
                        }
                    }
                }
            }
            Section(header: Text("In Progress")){
                ForEach(classroom.getVisibleAssignments(type: .inProgress)) { assigned in
                    Text(assigned.getName())
                }.onDelete { indexSet in
                    print("hiding assignment \(classroom.getVisibleAssignments(type: .inProgress)[indexSet.first!].getName())")
                    classroom.getVisibleAssignments(type: .inProgress)[indexSet.first!].setHiddenStatus(hidden: true)
                }
            }
            Section(header: Text("Missing")){
                ForEach(classroom.getVisibleAssignments(type: .missing)) { assigned in
                    Text(assigned.getName())
                }.onDelete { indexSet in
                    print("hiding assignment \(classroom.getVisibleAssignments(type: .missing)[indexSet.first!].getName())")
                    classroom.getVisibleAssignments(type: .missing)[indexSet.first!].setHiddenStatus(hidden: true)
                }
            }
            Section(header: Text("In Progress & No Due Date")){
                ForEach(classroom.getVisibleAssignments(type: .noDateDue)) { assigned in
                    Text(assigned.getName())
                }.onDelete { indexSet in
                    print("hiding assignment \(classroom.getVisibleAssignments(type: .noDateDue)[indexSet.first!].getName())")
                    classroom.getVisibleAssignments(type: .noDateDue)[indexSet.first!].setHiddenStatus(hidden: true)
                }
            }
            Section(header: Text("Completed")){
                ForEach(classroom.getVisibleAssignments(type: .completed)) { assigned in
                    Text(assigned.getName())
                }.onDelete { indexSet in
                    print("hiding assignment \(classroom.getVisibleAssignments(type: .completed)[indexSet.first!].getName())")
                    classroom.getVisibleAssignments(type: .completed)[indexSet.first!].setHiddenStatus(hidden: true)
                }
            }
            Section {
                NavigationLink(destination: HiddenAssignmentView(classrooms: classrooms, classroom: classroom)) {
                    Text("Hidden Assignments")
                }.foregroundColor(Color.gray)
            }
            Logo()
        }.navigationTitle(classroom.getName())
        .onAppear() {
            if(classroom.getAssignments().count == 0) {
                Task {
                    await classroom.setAssignments(assignments: classroom.queryAssignments())
                }
            }
        }
        .navigationBarItems(trailing: Button(action: {
            print(classroom.getAssignments().count)
            print("running")
            classroom.toggleUpdate()
        }) {
            Image(systemName: "arrow.clockwise").foregroundColor(.blue)
        }
        )
    }
}

enum AlertType {
    case noList, statusReport, success, failure
}

struct ChooseListView: View {
    @Environment(\.presentationMode) var mode: Binding<PresentationMode>
    @State var classroomListName: String
    @State var showAlert = false
    @State var alertType = AlertType.failure
    @State private var refresh = false

    var classroom: Classroom
    var store = EKEventStore()
    var body: some View {
        Form {
            Section {
                ForEach(store.calendars(for: .reminder), id: \.self) { list in
                    Button(list.title) {
                        classroom.setIdentifier(calendarIdentifier: list.calendarIdentifier)
                        classroomListName = list.title
                        self.mode.wrappedValue.dismiss()

                    }
                }
            }
            Section {
                Button("Create New List Under Current Classroom Name") {
                    if (classroom.getIdentifier() != nil &&
                        store.calendars(for: .reminder).first(where: { $0.calendarIdentifier == classroom.getIdentifier()! }) != nil &&
                        store.calendars(for: .reminder).first(where: { $0.calendarIdentifier == classroom.getIdentifier()! })?.title == classroom.getName()) {
                        alertType = .failure
                        showAlert = true
                        print("There already is an existing list under this classroom's name.")
                    } else {
                        classroom.initializeList(store: store)
                        if let listIdentiifer = classroom.getIdentifier() {
                            if let calendar = store.calendars(for: .reminder).first(where: { $0.calendarIdentifier == listIdentiifer }) {
                                classroomListName = calendar.title
                                alertType = .success
                                showAlert = true
                            } else {
                                print("Invalid calendar identifier")
                            }
                        }
                    }
                }.alert(isPresented: $showAlert) {
                    switch alertType {
                    case .failure:
                        return Alert(title: Text(""),
                                     message: Text("There already is an existing list under this classroom's name."))
                    case .success:
                        return Alert(title: Text(""),
                                     message: Text("Successfully created new list named \(classroomListName)."))
                    default:
                        return Alert(title: Text("You found a secret!"))
                    }
                }
            }
            Logo()
        }.navigationTitle(Text("Select List"))
    }
}
