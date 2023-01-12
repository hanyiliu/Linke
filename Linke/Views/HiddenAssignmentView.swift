//
//  HiddenAssignmentView.swift
//  Linker
//
//  Created by Hanyi Liu on 1/9/23.
//

import SwiftUI

struct HiddenAssignmentView: View {

    @StateObject var classrooms: ClassroomAPI
    @StateObject var classroom: Classroom
    
    
    var body: some View {
        Form {
            ForEach(classroom.getHiddenAssignments()) { assign in
                Text(assign.getName()).swipeActions(edge: .leading) {
                    Button{
                        assign.setHiddenStatus(hidden: false)
                        classrooms.update.toggle()
                        
                    } label: {Label("Add", systemImage: "plus.circle")}.tint(.green)
                    
                }
            }

        }.navigationTitle(Text("Hidden Assignments"))
        
    }
}
