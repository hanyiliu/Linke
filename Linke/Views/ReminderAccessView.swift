//
//  HomeView.swift
//  Linker
//
//  Created by Hanyi Liu on 12/6/22.
//

import SwiftUI
import EventKit



struct ReminderAccessView: View {
    
    @StateObject var viewRouter: ViewRouter
    
    
    var body: some View {
        
        VStack {
            
            Image("Icon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: UIScreen.main.bounds.size.width/3)
            
            Button("Allow Access to Reminders") {
                let store = EKEventStore();
                store.requestAccess(to: EKEntityType.reminder) { granted, error in
                    if(error != nil) {
                        print("Reminder access denied!")
                        print(error!)
                    } else {
                        viewRouter.currentPage = .home
                    }
                    
                    
                    
                }
            }
            .tint(.blue)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 5))
            .controlSize(.large)
            
        }.onAppear() {
            if(EKEventStore.authorizationStatus(for: EKEntityType.reminder) == .authorized) {
                viewRouter.currentPage = .home
            }
        }
        
       
    }
}

