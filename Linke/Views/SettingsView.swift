//
//  SettingsView.swift
//  Linke
//
//  Created by Hanyi Liu on 4/27/23.
//
import SwiftUI

struct SettingsView: View {
    //@StateObject var viewRouter: ViewRouter
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var isTimerScheduled = false
    @State private var selectedHour = 7
    @State private var selectedMinute = 0
    @State private var amPM = 0
    
    @State var autoRefreshAlert = false
    
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Auto Refresh (BETA)")) {
                    Toggle("Automatically Refresh Daily", isOn: $isTimerScheduled).onChange(of: isTimerScheduled) { value in
                        if value {
                            autoRefreshAlert = true
                        }
                    }
                    if isTimerScheduled {
                        HStack {
                            Spacer()
                            Picker(selection: $selectedHour, label: Text("Hour")) {
                                ForEach(1..<13) { index in
                                    Text("\(index)")
                                }
                            }
                            .padding(.leading)
                            .pickerStyle(.wheel)
                            .frame(width: 100, height: UIScreen.main.bounds.size.height/10)
                            
                            Picker(selection: $selectedMinute, label: Text("Minute")) {
                                ForEach(0..<60) { index in
                                    Text("\(index)")
                                }
                            }
                            .padding(.trailing)
                            .pickerStyle(.wheel)
                            .frame(width: 100, height: UIScreen.main.bounds.size.height/10)
                            
                            Picker(selection: $amPM, label: Text("AM/PM")) {
                                Text("AM").tag(0)
                                Text("PM").tag(1)
                            }
                            .padding(.trailing)
                            .pickerStyle(.wheel)
                            .frame(width: 100, height: UIScreen.main.bounds.size.height/10)
                            Spacer()
                        }
                    }
                }.onDisappear() {
                    
                    if isTimerScheduled {
                        Task {
                            await BackgroundHandler.scheduleTimerWithOverride(hour: selectedHour + amPM*12, minute: selectedMinute)
                        }
                    } else {
                        BackgroundHandler.cancelTask()
                    }

                    
                }.onChange(of: scenePhase) { newPhase in
                    if newPhase == .inactive {
                        if isTimerScheduled {
                            Task {
                                await BackgroundHandler.scheduleTimerWithOverride(hour: selectedHour + amPM*12, minute: selectedMinute)
                            }
                        } else {
                            BackgroundHandler.cancelTask()
                        }
                    }
                }.alert(isPresented: $autoRefreshAlert) {
                    return Alert(
                        title: Text("Beta Testing"),
                        message: Text("Because of strict iOS restraints, Apple only allows this function to be triggered if your phone is being charged and connected to the internet. Thus, please set a time where those conditions are most often met.\nThank you!")
                        )
                }
                  
            }
        }.navigationTitle(Text("Settings"))
            .onAppear() {
                Task {
                    if let date = await BackgroundHandler.getTaskScheduleTime() {
                        isTimerScheduled = true
                        
                        let calendar = Calendar.current
                        
                        let hour = calendar.component(.hour, from: date)
                        if(hour / 12 == 1) {
                            selectedHour = hour % 12
                            amPM = 1
                        } else {
                            selectedHour = hour
                        }
                        selectedMinute = calendar.component(.minute, from: date)
                        
                    } else {
                        isTimerScheduled = false
                    }
                }
            }
        
        
    }

}
