//
//  CustomIcons.swift
//  PomodoroApp
//
//  Created by Claude Code on 7/30/25.
//

import SwiftUI

// Custom SVG-inspired icons
struct CustomPlayIcon: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 5.25, y: 5.653))
            path.addCurve(
                to: CGPoint(x: 6.917, y: 4.667),
                control1: CGPoint(x: 5.25, y: 4.797),
                control2: CGPoint(x: 6.167, y: 4.255)
            )
            path.addLine(to: CGPoint(x: 18.457, y: 11.014))
            path.addCurve(
                to: CGPoint(x: 18.457, y: 12.986),
                control1: CGPoint(x: 19.082, y: 11.389),
                control2: CGPoint(x: 19.082, y: 12.611)
            )
            path.addLine(to: CGPoint(x: 6.917, y: 19.333))
            path.addCurve(
                to: CGPoint(x: 5.25, y: 18.347),
                control1: CGPoint(x: 6.167, y: 19.745),
                control2: CGPoint(x: 5.25, y: 19.203)
            )
            path.addLine(to: CGPoint(x: 5.25, y: 5.653))
            path.closeSubpath()
        }
        .stroke(Color.primary, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        .frame(width: 24, height: 24)
    }
}

struct CustomTimerIcon: View {
    var body: some View {
        Path { path in
            // Clock face (circle)
            path.addEllipse(in: CGRect(x: 3, y: 3, width: 18, height: 18))
            
            // Hour hand (12 to 6)
            path.move(to: CGPoint(x: 12, y: 6))
            path.addLine(to: CGPoint(x: 12, y: 12))
            
            // Minute hand (12 to 4.5)
            path.move(to: CGPoint(x: 12, y: 12))
            path.addLine(to: CGPoint(x: 16.5, y: 12))
        }
        .stroke(Color.primary, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        .frame(width: 24, height: 24)
    }
}

struct CustomTaskIcon: View {
    var body: some View {
        Path { path in
            // Clipboard outline
            path.move(to: CGPoint(x: 6, y: 6.878))
            path.addLine(to: CGPoint(x: 6, y: 6))
            path.addCurve(
                to: CGPoint(x: 8.25, y: 3.75),
                control1: CGPoint(x: 6, y: 4.756),
                control2: CGPoint(x: 7.006, y: 3.75)
            )
            path.addLine(to: CGPoint(x: 15.75, y: 3.75))
            path.addCurve(
                to: CGPoint(x: 18, y: 6),
                control1: CGPoint(x: 16.994, y: 3.75),
                control2: CGPoint(x: 18, y: 4.756)
            )
            path.addLine(to: CGPoint(x: 18, y: 6.878))
            
            // Inner rectangle
            path.move(to: CGPoint(x: 4.5, y: 9))
            path.addLine(to: CGPoint(x: 4.5, y: 18))
            path.addCurve(
                to: CGPoint(x: 6.75, y: 20.25),
                control1: CGPoint(x: 4.5, y: 19.244),
                control2: CGPoint(x: 5.506, y: 20.25)
            )
            path.addLine(to: CGPoint(x: 17.25, y: 20.25))
            path.addCurve(
                to: CGPoint(x: 19.5, y: 18),
                control1: CGPoint(x: 18.494, y: 20.25),
                control2: CGPoint(x: 19.5, y: 19.244)
            )
            path.addLine(to: CGPoint(x: 19.5, y: 9))
            path.addCurve(
                to: CGPoint(x: 18, y: 6.878),
                control1: CGPoint(x: 19.5, y: 8.02),
                control2: CGPoint(x: 18.874, y: 7.191)
            )
        }
        .stroke(Color.primary, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        .frame(width: 24, height: 24)
    }
}