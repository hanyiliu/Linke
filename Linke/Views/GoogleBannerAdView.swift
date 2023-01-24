//
//  GoogleBannerAdView.swift
//  Linke
//
//  Created by Hanyi Liu on 1/23/23.
//

import SwiftUI
import GoogleMobileAds
import UIKit

private struct BannerVC: UIViewControllerRepresentable  {

    func makeUIViewController(context: Context) -> UIViewController {
        let view = GADBannerView(adSize: GADAdSizeBanner)

        let viewController = UIViewController()
        view.adUnitID = "ca-app-pub-3940256099942544/2934735716" //CHANGE TO ACTUAL ID
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
