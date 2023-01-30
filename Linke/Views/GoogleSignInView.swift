//
//  GoogleSignInView.swift
//  Linker
//
//  Created by Hanyi Liu on 12/6/22.
//

import SwiftUI
import GoogleSignIn
import GoogleSignInSwift


struct GoogleSignInView: View {
    
    @StateObject var viewRouter: ViewRouter
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    
    let clientID = "102247840613-h0icqnch0ugvb4efp7vjob0d5ljkg90s.apps.googleusercontent.com"
    let requestedScopes = ["https://www.googleapis.com/auth/classroom.courses.readonly",
                           "https://www.googleapis.com/auth/classroom.coursework.me.readonly",
                           "https://www.googleapis.com/auth/classroom.student-submissions.me.readonly"]
    var body: some View {
        
        
        VStack {
            Spacer()
            Image("Icon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: UIScreen.main.bounds.size.width/3)
            Spacer().frame(height: UIScreen.main.bounds.size.height/10)
            Text("Welcome to Linke!").font(.title)
            Text("Please sign in with your school account:")
            if(colorScheme == .light) {
                GoogleSignInButton(viewModel: GoogleSignInButtonViewModel(scheme: .light, style: .standard, state: .normal), action: prepareSignIn)
                    .cornerRadius(25)
            } else {
                GoogleSignInButton(viewModel: GoogleSignInButtonViewModel(scheme: .dark, style: .standard, state: .normal), action: prepareSignIn)
                    .cornerRadius(25)
            }
            Spacer()
        }
        .padding()
    }
    
    
    func prepareSignIn(){
        let signInConfig = GIDConfiguration(clientID: clientID)
        guard let rootViewController = UIApplication.shared.windows.first?.rootViewController else {
            print("There is no root view controller!")
            return
        }
        GIDSignIn.sharedInstance.signIn(with: signInConfig, presenting: rootViewController) {
            user, error in
            
            let grantedScopes = user?.grantedScopes
            if grantedScopes == nil || !grantedScopes!.contains(requestedScopes[0]) {
                GIDSignIn.sharedInstance.addScopes(requestedScopes, presenting: rootViewController) { user, error in

                }
            } else {
                viewRouter.currentPage = .reminderAccess
            }
        }
    }
}

