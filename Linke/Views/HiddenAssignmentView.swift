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
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    
    var body: some View {
        Form {
            ForEach(classroom.getHiddenAssignments()) { assign in
                HStack {
                    Button(assign.getName()) {
                        assign.setHiddenStatus(hidden: false)
                        classrooms.update.toggle()
                    }.foregroundColor((colorScheme == .light) ? Color.black : Color.white)
                    Spacer()
                    Image(uiImage: .add).renderingMode(.template).foregroundColor(.green)
                }
            }

        }.navigationTitle(Text("Hidden Assignments"))
        
    }
}
