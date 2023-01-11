//
//  HiddenClassroomView.swift
//  Linker
//
//  Created by Hanyi Liu on 1/9/23.
//

import SwiftUI

struct HiddenClassroomView: View {

    @StateObject var classrooms: ClassroomAPI
    
    var body: some View {
        Form {
            ForEach(classrooms.getHiddenClassrooms()) { classroom in
                Text(classroom.getName()).swipeActions(edge: .leading) {
                    Button{
                        classroom.setHiddenStatus(hidden: false)
                        classrooms.update.toggle()
                        
                    } label: {Label("Add", systemImage: "plus.circle")}.tint(.green)
                    
                }
            }
        }.navigationTitle(Text("Hidden Classrooms"))
        
    }
}
