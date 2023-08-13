//
//  HelpView.swift
//  Linke
//
//  Created by Hanyi Liu on 1/28/23.
//

import SwiftUI


struct HelpView: View {
    @StateObject var viewRouter: ViewRouter
    
    @State var fromHome: Bool
    
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    
    private let dotAppearance = UIPageControl.appearance()
    var body: some View {
        
        
        TabView {
            Help1(mode: colorScheme, fromHome: fromHome)
            Help2(fromHome: fromHome)
            Help3(mode: colorScheme, fromHome: fromHome)
            Help4(mode: colorScheme, fromHome: fromHome)
            Help5(mode: colorScheme, fromHome: fromHome)
            Help6(mode: colorScheme, fromHome: fromHome)
            Help7(viewRouter: viewRouter, fromHome: fromHome)
            
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .onAppear {
            dotAppearance.currentPageIndicatorTintColor = .black
            dotAppearance.pageIndicatorTintColor = .gray
        }
    }
}

struct Help1: View {
    @State var mode: ColorScheme
    @State var fromHome: Bool
    var body: some View {
        
        VStack {
            if !fromHome {
                Spacer()
                    .frame(height: UIScreen.main.bounds.size.height/6)
            }
            Text("Once you enter the app, it'll look similar to this...")
                .font(.largeTitle)
                .fontWeight(.medium)
                .padding(.horizontal, UIScreen.main.bounds.size.width/20)
            Image(mode == .light ? "Help1" : "Help1-dark")
                .resizable()
                .scaledToFit()
                .padding()
                .cornerRadius(30)
                .background(.gray.opacity(0.10))
                .cornerRadius(10)
                .padding()
                .frame(width: UIScreen.main.bounds.size.width/1.25)
            Spacer()
        }
        
    }
}

struct Help2: View {
    @State var fromHome: Bool
    var body: some View {
        VStack {
            if !fromHome {
                Spacer()
                    .frame(height: UIScreen.main.bounds.size.height/6)
            }
            Text("On the home screen, classrooms will have four possible symbols next to them: ")
                .font(.largeTitle)
                .fontWeight(.medium)
                .padding(.horizontal, UIScreen.main.bounds.size.width/20)
            Spacer()
                .frame(height: UIScreen.main.bounds.size.height/10)
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: "minus.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.gray)
                        .frame(width: UIScreen.main.bounds.size.width/12, alignment: .leading)
                    Spacer().frame(width: UIScreen.main.bounds.size.width/15, alignment: .leading)
                    Text("Is currently loading")
                        .multilineTextAlignment(.leading)
                }
                HStack {
                    Image(systemName: "questionmark.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.red)
                        .frame(width: UIScreen.main.bounds.size.width/12, alignment: .leading)
                    Spacer().frame(width: UIScreen.main.bounds.size.width/15, alignment: .leading)
                    Text("Does not have a chosen Reminder list")
                        .multilineTextAlignment(.leading)
                }
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.orange)
                        .frame(width: UIScreen.main.bounds.size.width/12, alignment: .leading)
                    Spacer().frame(width: UIScreen.main.bounds.size.width/15, alignment: .leading)
                    Text("Have assignments not updated to Reminders")
                        .multilineTextAlignment(.leading)
                }
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.green)
                        .frame(width: UIScreen.main.bounds.size.width/12, alignment: .leading)
                    Spacer().frame(width: UIScreen.main.bounds.size.width/15, alignment: .leading)
                    Text("Is up to date")
                        .multilineTextAlignment(.leading)
                }
                
            }
            .padding(.horizontal, UIScreen.main.bounds.size.width/15)
            Spacer()
        }.padding()
    }
}

struct Help3: View {
    @State var mode: ColorScheme
    @State var fromHome: Bool
    var body: some View {
        VStack {
            if !fromHome {
                Spacer()
                    .frame(height: UIScreen.main.bounds.size.height/6)
            }
            Text("You can choose a classroom's Reminders list by going to its page and selecting \"Reminder List\":")
                .font(.largeTitle)
                .fontWeight(.medium)
                .padding(.horizontal, UIScreen.main.bounds.size.width/20)
            Image(mode == .light ? "Help3" : "Help3-dark")
                .resizable()
                .scaledToFit()
                .padding()
                .cornerRadius(30)
                .background(.gray.opacity(0.10))
                .cornerRadius(10)
                .padding()
                .frame(width: UIScreen.main.bounds.size.width/1.25)
            Text("Alternatively, after clicking \"Add All Assignments\" on the home page, you can automatically create lists accordingly.")
                .font(.largeTitle)
                .fontWeight(.medium)
                .padding(.horizontal, UIScreen.main.bounds.size.width/20)
            Spacer()
                .frame(height: UIScreen.main.bounds.size.height/20)

            Text("You can then add its assignments to Reminders!")
            Spacer()
        }
    }
}

struct Help4: View {
    @State var mode: ColorScheme
    @State var fromHome: Bool
    var body: some View {
        VStack {
            if !fromHome {
                Spacer()
                    .frame(height: UIScreen.main.bounds.size.height/6)
            }
            Text("To add all assignments for all active classrooms, click the button on the home screen:")
                .font(.largeTitle)
                .fontWeight(.medium)
                .padding(.horizontal, UIScreen.main.bounds.size.width/20)
            Image(mode == .light ? "Help4" : "Help4-dark")
                .resizable()
                .scaledToFit()
                .padding()
                .cornerRadius(30)
                .background(.gray.opacity(0.10))
                .cornerRadius(10)
                .padding()
                .frame(width: UIScreen.main.bounds.size.width/1.25)
            Spacer()
        }
    }
}

struct Help5: View {
    @State var mode: ColorScheme
    @State var fromHome: Bool
    var body: some View {
        VStack {
            if !fromHome {
                Spacer()
                    .frame(height: UIScreen.main.bounds.size.height/6)
            }
            Text("To hide a classroom, swipe left on it:")
                .font(.largeTitle)
                .fontWeight(.medium)
                .padding(.horizontal, UIScreen.main.bounds.size.width/20)
            Image(mode == .light ? "Help5-1" : "Help5-1-dark")
                .resizable()
                .scaledToFit()
                .padding()
                .cornerRadius(30)
                .background(.gray.opacity(0.10))
                .cornerRadius(10)
                .padding()
                .frame(width: UIScreen.main.bounds.size.width/1.25)
            Text("To hide an assignment, do the same:")
                .font(.largeTitle)
                .fontWeight(.medium)
                .padding(.horizontal, UIScreen.main.bounds.size.width/20)
            Image(mode == .light ? "Help5-2" : "Help5-2-dark")
                .resizable()
                .scaledToFit()
                .padding()
                .cornerRadius(30)
                .background(.gray.opacity(0.10))
                .cornerRadius(10)
                .padding()
                .frame(width: UIScreen.main.bounds.size.width/1.25)
            Spacer()
        }
    }
}

struct Help6: View {
    @State var mode: ColorScheme
    @State var fromHome: Bool
    var body: some View {
        VStack {
            if !fromHome {
                Spacer()
                    .frame(height: UIScreen.main.bounds.size.height/6)
            }
            Text("If something doesn't seem right, try refreshing the app:")
                .font(.largeTitle)
                .fontWeight(.medium)
                .padding(.horizontal, UIScreen.main.bounds.size.width/20)
            Image(mode == .light ? "Help6" : "Help6-dark")
                .resizable()
                .scaledToFit()
                .padding()
                .cornerRadius(30)
                .background(.gray.opacity(0.10))
                .cornerRadius(10)
                .padding()
                .frame(width: UIScreen.main.bounds.size.width/1.25)
            Spacer()
        }
    }
}

struct Help7: View {
    @StateObject var viewRouter: ViewRouter
    @State var fromHome: Bool
    @Environment(\.presentationMode) var presentationMode
    @State var checked = false
    var body: some View {
        VStack {
            if !fromHome {
                Spacer()
                    .frame(height: UIScreen.main.bounds.size.height/3)
            }
            Text("You're all set! Here's to never forgetting another assignment!")
                .font(.largeTitle)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, UIScreen.main.bounds.size.width/20)
            Spacer()
            if(fromHome) {
                Button("Continue") {
                    self.presentationMode.wrappedValue.dismiss()
                }
                .tint(.blue)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
            } else {
                Button("Continue") {
                    viewRouter.currentPage = .home
                    if(checked) {
                        UpdateValue.saveToLocal(key: "SHOW_HELP", value: false)
                    } else {
                        UpdateValue.saveToLocal(key: "SHOW_HELP", value: true)
                    }
                }
                .tint(.blue)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                
                Toggle(isOn: $checked) {
                    Text("Don't show this again")
                }
                .toggleStyle(CheckboxStyle())
            }
            Spacer()
        }
    }
}


struct CheckboxStyle: ToggleStyle {

    func makeBody(configuration: Self.Configuration) -> some View {

        return HStack {
            Image(systemName: configuration.isOn ? "checkmark.circle" : "circle")
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundColor(configuration.isOn ? .blue : .gray)
                .font(.system(size: 20, weight: .regular, design: .default))
                configuration.label
        }
        .onTapGesture { configuration.isOn.toggle() }

    }
}
