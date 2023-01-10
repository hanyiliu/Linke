//
//  ViewRouter.swift
//  Linker
//
//  Created by Hanyi Liu on 12/6/22.
//

import SwiftUI
import BackgroundTasks


class ViewRouter: ObservableObject {
    
    @Published var currentPage: Page = .googleSignIn
    
    func scheduleAppRefresh() {
        print("Scheduling Refresh")
        let date = Date() + 10 //10 seconds
        let request = BGAppRefreshTaskRequest(identifier: "com.hanyiliu.Linker.refreshAssignments")
        request.earliestBeginDate = date
        try? BGTaskScheduler.shared.submit(request)
    }
}
