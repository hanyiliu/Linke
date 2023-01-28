//
//  HiddenClassroomView.swift
//  Linker
//
//  Created by Hanyi Liu on 1/9/23.
//

import SwiftUI

struct HiddenClassroomView: View {

    @StateObject var classrooms: ClassroomAPI
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    var body: some View {
        Form {
            ForEach(classrooms.getHiddenClassrooms()) { classroom in
                HStack {
                    Button(classroom.getName()) {
                        classroom.setHiddenStatus(hidden: false)
                        classrooms.update.toggle()
                    }.foregroundColor((colorScheme == .light) ? Color.black : Color.white)
                    Spacer()
                    Image(uiImage: .add).renderingMode(.template).foregroundColor(.green)
                }
            }

        }.navigationTitle(Text("Hidden Classrooms"))
        
        
        
    }
}
