//
//  LinkerApp.swift
//  Linker
//
//  Created by Hanyi Liu on 12/6/22.
//

import SwiftUI
import GoogleSignIn
import EventKit
    

@main
struct LinkerApp: App {
    @StateObject var viewRouter = ViewRouter()
    
    var body: some Scene {
        WindowGroup {
            ContentView(viewRouter: viewRouter)
            
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
            
                .onAppear {
                    GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
                        
                        print("User previously logged in")
                        
                        viewRouter.currentPage = .reminderAccess
                        // Check if `user` exists; otherwise, do something with `error`
                    }
                }
        }
    }
    

    
}

