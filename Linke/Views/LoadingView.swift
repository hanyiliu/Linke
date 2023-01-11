//
//  LoadingView.swift
//  Linker
//
//  Created by Hanyi Liu on 1/9/23.
//

import SwiftUI
import GoogleSignIn

struct LoadingView: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    var body: some View {
        VStack {
            Image("Icon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: UIScreen.main.bounds.size.width/3)
        }
    }
}
