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
                        if error != nil || user == nil {
                            // Show the app's signed-out state.
                            print("User not previously logged in")
                            viewRouter.currentPage = .googleSignIn
                        } else {
                            // Show the app's signed-in state.
                            
                            print("User previously logged in")
                            viewRouter.currentPage = .reminderAccess
                        }
                    }
                }
        }
    }
    

    
}
