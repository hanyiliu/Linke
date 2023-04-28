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
        case .loading:
            LoadingView()
        case .googleSignIn:
            GoogleSignInView(viewRouter: viewRouter)
        case .reminderAccess:
            ReminderAccessView(viewRouter: viewRouter)
        case .help:
            HelpView(viewRouter: viewRouter, fromHome: false)
        case .home:
            let classrooms = ClassroomAPI()
            HomeView(viewRouter: viewRouter, classrooms: classrooms)
                
        }
    }

            
        
}

enum Page {
    case loading
    case googleSignIn
    case reminderAccess
    case help
    case home
}
