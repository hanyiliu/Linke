//
//  GoogleBannerAdView.swift
//  Linke
//
//  Created by Hanyi Liu on 1/23/23.
//  Code taken from: https://medium.com/@michaelbarneyjr/how-to-integrate-admob-ads-in-swiftui-fbfd3d774c50
//

import SwiftUI
import GoogleMobileAds
import UIKit

private struct BannerVC: UIViewControllerRepresentable  {

    func makeUIViewController(context: Context) -> UIViewController {
        let view = GADBannerView(adSize: GADAdSizeBanner)

        let viewController = UIViewController()
        view.adUnitID = "ca-app-pub-6517381768603549/5708589260" //ca-app-pub-6517381768603549/5708589260
        view.rootViewController = viewController
        viewController.view.addSubview(view)
        viewController.view.frame = CGRect(origin: .zero, size: GADAdSizeBanner.size)
        view.load(GADRequest())

        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

struct Banner: View{
    var body: some View{
        HStack{
            Spacer()
            BannerVC().frame(width: 320, height: 50, alignment: .center)
            Spacer()
        }
    }
}
