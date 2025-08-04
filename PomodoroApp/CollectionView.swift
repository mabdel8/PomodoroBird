//
//  CollectionView.swift
//  PomodoroApp
//
//  Created by Claude Code on 7/31/25.
//

import SwiftUI
import SwiftData

struct CollectionView: View {
    @Query(sort: \CollectedBird.collectedAt, order: .reverse) private var collectedBirds: [CollectedBird]
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header stats
                    headerStats
                    
                    // Bird grid
                    birdGrid
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
            .navigationBarTitleDisplayMode(.large)
            .background(Color(UIColor.systemBackground))
        }
    }
    
    private var headerStats: some View {
        VStack(spacing: 16) {
            // Progress circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: collectionProgress)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: collectionProgress)
                
                VStack(spacing: 4) {
                    Text("\(Set(collectedBirds.compactMap { $0.birdType }).count)")
                        .font(.custom("Geist", size: 32))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("of \(BirdType.allCases.count)")
                        .font(.custom("Geist", size: 14))
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
            
            // Collection title
            Text("Birds Collected")
                .font(.custom("Geist", size: 18))
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 16)
    }
    
    private var collectionProgress: Double {
        guard !BirdType.allCases.isEmpty else { return 0 }
        let uniqueBirdTypes = Set(collectedBirds.compactMap { $0.birdType })
        return Double(uniqueBirdTypes.count) / Double(BirdType.allCases.count)
    }
    
    private var birdGrid: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(BirdType.allCases, id: \.self) { birdType in
                let isCollected = collectedBirds.contains { $0.birdType == birdType }
                CollectionBirdCard(birdType: birdType, isCollected: isCollected)
            }
        }
        .padding(.bottom, 32)
    }
}

struct CollectionBirdCard: View {
    let birdType: BirdType
    let isCollected: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Bird image container
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isCollected 
                            ? LinearGradient(
                                colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.gray.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .stroke(
                        isCollected ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2),
                        lineWidth: 1
                    )
                    .frame(width: 100, height: 100)
                
                if isCollected {
                    Image(birdType.birdImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 70, height: 70)
                        .scaleEffect(1.0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isCollected)
                } else {
                    ZStack {
                        Image(birdType.birdImageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 70, height: 70)
                            .grayscale(1.0)
                            .opacity(0.3)
                        
                        Image(systemName: "lock.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray.opacity(0.6))
                    }
                }
            }
            
            // Bird name
            Text(isCollected ? birdType.displayName : "???")
                .font(.custom("Geist", size: 13))
                .fontWeight(.medium)
                .foregroundColor(isCollected ? .primary : .secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 36) // Fixed height for consistent layout
        }
        .scaleEffect(isCollected ? 1.0 : 0.95)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isCollected)
    }
}

#Preview {
    CollectionView()
        .modelContainer(for: [CollectedBird.self, FocusTag.self, Task.self, FocusSession.self, AppTimerState.self], inMemory: true)
}