//
//  OnboardingView.swift
//
//  Created by Adam Abdalla Abdelmagid on 7/31/2025.
//
//  adamlyttleapps.com
//  twitter.com/adamlyttleapps.com
//
//  Usage:
/*
OnboardingView(appName: "Real Estate Calculator", features: [
    Feature(title: "Mortgage Repayments", description: "Easily calculate weekly, monthly and yearly repayments ", icon: "house"),
    Feature(title: "Amortization", description: "Quickly view amortization for the life of the loan", icon: "chart.line.downtrend.xyaxis"),
    Feature(title: "Deposit Calculator", description: "Calculate deposit based on purchase price and savings", icon: "percent"),
    Feature(title: "Ad-Free Experience", description: "Thank you for downloading my app, I hope you enjoy it :-)", icon: "party.popper"),
], color: Color.blue)
*/

import SwiftUI

struct Feature: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String?
}

struct OnboardingView: View {
    @State var appName: String
    let features: [Feature]
    let color: Color?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Text("Welcome to \(appName)")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.vertical, 50)
                .multilineTextAlignment(.center)
            Spacer()
            VStack {
                ForEach(features) { feature in
                    VStack(alignment: .leading) {
                        HStack {
                            if let icon = feature.icon {
                                Image(systemName: icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 45, alignment: .center)
                                    .clipped()
                                    .foregroundColor(color ?? Color.blue)
                                    .padding(.trailing, 15)
                                    .padding(.vertical, 10)
                            }
                            VStack(alignment: .leading) {
                                Text(feature.title)
                                    .fontWeight(.bold)
                                    .font(.system(size: 16))
                                Text(feature.description)
                                    .font(.system(size: 15))
                            }
                            Spacer()
                        }
                    }
                    .padding(.horizontal,20)
                    .padding(.bottom, 20)
                }
            }
            .padding(.bottom, 30)
            Spacer()
            VStack {
                Button(action: {
                    dismiss()
                }) {
                    ZStack {
                        Rectangle()
                            .foregroundColor(color ?? Color.blue)
                            .cornerRadius(12)
                            .frame(height: 54)
                        Text("Continue")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.top, 15)
            .padding(.bottom, 50)
            .padding(.horizontal,15)
        }
        .padding()
    }
}
