//
//  SettingsView.swift
//  Linke
//
//  Created by Hanyi Liu on 4/27/23.
//
import SwiftUI

struct SettingsView: View {
    //@StateObject var viewRouter: ViewRouter
    
    @State private var isTimerScheduled = false
    @State private var selectedHour = 7
    @State private var selectedMinute = 0
    @State private var amPM = 0
    
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Auto Refresh")) {
                    Toggle("Automatically Refresh Daily", isOn: $isTimerScheduled)
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
                            if let date = await BackgroundHandler.getTaskScheduleTime() {
                                let calendar = Calendar.current
                                let scheduledHour = calendar.component(.hour, from: date)
                                let scheduledMinute = calendar.component(.minute, from: date)
                                
                                if scheduledHour != (selectedHour + amPM*12) || scheduledMinute != selectedMinute {
                                    BackgroundHandler.cancelTask()
                                    print("Scheduling Background Refresh")
                                    BackgroundHandler.scheduleTimer(hour: selectedHour + amPM*12, minute: selectedMinute)
                                }
                            } else {
                                print("Scheduling Background Refresh")
                                BackgroundHandler.scheduleTimer(hour: selectedHour + amPM*12, minute: selectedMinute)
                            }
                        }
                    } else {
                        BackgroundHandler.cancelTask()
                    }

                    
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
