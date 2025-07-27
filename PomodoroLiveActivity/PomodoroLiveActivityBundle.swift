//
//  PomodoroLiveActivityBundle.swift
//  PomodoroLiveActivity
//
//  Created by Mohamed Abdelmagid on 7/26/25.
//

import WidgetKit
import SwiftUI

@main
struct PomodoroLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        PomodoroLiveActivity()
        PomodoroLiveActivityControl()
        PomodoroTimerLiveActivity()
    }
}
