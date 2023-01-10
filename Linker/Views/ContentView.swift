//
//  ContentView.swift
//  Linker
//
//  Created by Hanyi Liu on 12/6/22.
//

import SwiftUI
import GoogleSignIn
import GoogleSignInSwift


struct ContentView: View {
    
    @StateObject var viewRouter: ViewRouter
    
    var body: some View {
        switch viewRouter.currentPage {
        case .googleSignIn:
            GoogleSignInView(viewRouter: viewRouter)
        case .reminderAccess:
            ReminderAccessView(viewRouter: viewRouter)
        case .home:
            let classrooms = ClassroomAPI()
            HomeView(viewRouter: viewRouter, classrooms: classrooms)
        }
    }
}

enum Page {
    case googleSignIn
    case reminderAccess
    case home
}
