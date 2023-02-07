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
    @State var deniedAccess = false
    
    var body: some View {
        
        VStack {
            
            Image("Icon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: UIScreen.main.bounds.size.width/3)
            
            Button("Allow Access to Reminders") {
                let store = EKEventStore();
                store.requestAccess(to: EKEntityType.reminder) { granted, error in
                    if !granted {
                        deniedAccess = true
                    } else {
                        if(error != nil) {
                            print("Reminder access denied!")
                            print(error!)
                        } else {
                            if let data = UpdateValue.loadFromLocal(key: "SHOW_HELP", type: "Bool") as? Bool {
                                if(data) {
                                    viewRouter.currentPage = .help
                                } else {
                                    viewRouter.currentPage = .home
                                }
                            } else {
                                viewRouter.currentPage = .help
                            }
                        }
                    }
                }
            }
            .tint(.blue)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 5))
            .controlSize(.large)
            .alert(isPresented: $deniedAccess) {
              Alert(
                title: Text("Allow Access"),
                message: Text("Please go to Settings and turn on Reminders access. Otherwise, Linke cannot function."),
                primaryButton: .cancel(Text("Cancel")),
                secondaryButton: .default(Text("Settings"), action: {
                  if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                  }
                }))
            }
            
        }.onAppear() {
            if(EKEventStore.authorizationStatus(for: EKEntityType.reminder) == .authorized) {
                if let data = UpdateValue.loadFromLocal(key: "SHOW_HELP", type: "Bool") as? Bool {
                    if(data) {
                        viewRouter.currentPage = .help
                    } else {
                        viewRouter.currentPage = .home
                    }
                } else {
                    viewRouter.currentPage = .help
                }
            }
        }
        
       
    }
}

