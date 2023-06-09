//
//  TeamView.swift
//  Linke
//
//  Created by Hanyi Liu on 6/6/23.
//

import Foundation
import SwiftUI

struct TeamView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var team: Team
    @State private var teamCode: String = ""
    
    @State private var showAlert = false //For entering tema code to join
    @State private var enteredCode = "" //---
    
    @State private var showConfirmation = false //For leaving team
    
    var body: some View {
        
        if(team.teamDictionary == nil) {
            Form {
                Section() {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                showAlert = true
                                
                            }) {
                                HStack {
                                    Spacer()
                                    ZStack {
                                        Circle()
                                            .foregroundColor(.blue)
                                            .frame(width: UIScreen.main.bounds.size.width/15, height: UIScreen.main.bounds.size.width/15) // Adjust the size of the circle
                                        
                                        Image(systemName: "arrow.right")
                                            .foregroundColor(.white)
                                            .frame(width: UIScreen.main.bounds.size.width/20, height: UIScreen.main.bounds.size.width/20) // Adjust the size of the circle
                                    }
                                    
                                    
                                    Text("Join a Team")
                                        .foregroundColor(.blue)
                                        .font(.headline)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                    Spacer()
                                }
                            }.alert("Enter Team Code", isPresented: $showAlert) {
                                TextField("Enter Team Code", text: $enteredCode)
                                Button("Join") {
                                    team.teamCode = enteredCode
                                }
                            }
                            Spacer()
                        }
                        .padding(.all)
                        Spacer()
                    }
                }
            }
        } else {
            
            Form {
                
                HStack {
                    Spacer()
                    Text("Your admins can now see your assignments!")
                        .foregroundColor(Color.gray)
                        .multilineTextAlignment(.center)
                        
                    Spacer()
                }
                
                Section(header: Text("Team Info")) {
                    HStack {
                        Text("Code")
                        Spacer()
                        Text(team.teamCode).foregroundColor(Color.gray)
                    }
                    HStack {
                        Text("Founder")
                        Spacer()
                        Text(team.founderName).foregroundColor(Color.gray)
                    }
                    .task {
                        await team.fetchFounderName()
                    }
                }
                
                Section() {
                    Button(action: {
                        showConfirmation = true
                    }) {
                        Text("Leave Team")
                            .foregroundColor(.red)
                    }
                    .alert(isPresented: $showConfirmation) {
                        Alert(
                            title: Text("Leave Team"),
                            message: Text("Are you sure you want to leave the team?"),
                            primaryButton: .destructive(Text("Leave"), action: {
                                team.leaveTeam()
                                
                            }),
                            secondaryButton: .cancel()
                        )
                    }
                }
                
                Logo()
            }.navigationTitle("Your Team")
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        team.refreshTeam()
                    }
                }
            
        }
    }


}
