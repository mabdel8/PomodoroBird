//
//  AnimationComponents.swift
//  PomodoroApp
//
//  Created by Claude Code on 7/30/25.
//

import SwiftUI

struct HatchingAnimationView: View {
    let birdType: BirdType
    let onDismiss: () -> Void
    
    @State private var showEgg = true
    @State private var showCracks = false
    @State private var showFinalEgg = false
    @State private var eggScale: CGFloat = 1.0
    @State private var finalEggScale: CGFloat = 0.1
    @State private var sparkleOpacity: Double = 0.0
    
    // Animation to analytics tab
    @State private var showFlyingEgg = false
    @State private var flyingEggPosition = CGPoint(x: 0, y: 0)
    @State private var flyingEggScale: CGFloat = 1.0
    @State private var flyingEggOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // Animation content with card background
            VStack(spacing: 32) {
                Text("🎉 Egg Hatched! 🎉")
                    .font(.custom("Geist", size: 28))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .opacity(showFinalEgg ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.5).delay(1.5), value: showFinalEgg)
                
                ZStack {
                    // Egg with cracks
                    if showEgg {
                        Image("almost")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 200, height: 200)
                            .scaleEffect(eggScale)
                            .opacity(showFinalEgg ? 0.0 : 1.0)
                            .animation(.easeInOut(duration: 0.3), value: showFinalEgg)
                    }
                    
                    // Bird's egg (final state)
                    if showFinalEgg {
                        Image(birdType.eggImageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 180, height: 180)
                            .scaleEffect(finalEggScale)
                            .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(1.0), value: finalEggScale)
                    }
                    
                    // Sparkle effects
                    ForEach(0..<8, id: \.self) { index in
                        Image(systemName: "sparkle")
                            .font(.system(size: 20))
                            .foregroundColor(.yellow)
                            .opacity(sparkleOpacity)
                            .offset(
                                x: cos(Double(index) * .pi / 4) * 120,
                                y: sin(Double(index) * .pi / 4) * 120
                            )
                            .animation(.easeInOut(duration: 0.8).delay(Double(index) * 0.1 + 1.2), value: sparkleOpacity)
                    }
                }
                
                Text("You collected a \(birdType.displayName) Egg!")
                    .font(.custom("Geist", size: 20))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .opacity(showFinalEgg ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.5).delay(2.0), value: showFinalEgg)
                
                Button("Awesome!") {
                    startFlyingEggAnimation()
                }
                .font(.custom("Geist", size: 18))
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.green)
                )
                .opacity(showFinalEgg ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.5).delay(2.5), value: showFinalEgg)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 24)
            
            // Flying egg animation to analytics tab
            if showFlyingEgg {
                Image(birdType.eggImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .scaleEffect(flyingEggScale)
                    .opacity(flyingEggOpacity)
                    .position(flyingEggPosition)
            }
        }
        .onAppear {
            startHatchingAnimation()
        }
    }
    
    private func startHatchingAnimation() {
        // Stage 1: Shake the egg
        withAnimation(.easeInOut(duration: 0.1).repeatCount(6, autoreverses: true)) {
            eggScale = 1.1
        }
        
        // Stage 2: Show cracks (already showing "almost" image)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showCracks = true
        }
        
        // Stage 3: Show the bird's egg
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showFinalEgg = true
            finalEggScale = 1.0
            sparkleOpacity = 1.0
        }
        
        // Stage 4: Fade sparkles
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 1.0)) {
                sparkleOpacity = 0.0
            }
        }
    }
    
    private func startFlyingEggAnimation() {
        // Get screen dimensions
        let screenBounds = UIScreen.main.bounds
        let centerX = screenBounds.width / 2
        let centerY = screenBounds.height / 2
        let tabY = screenBounds.height - 100 // Approximate tab bar position
        let analyticsTabX = screenBounds.width * 0.625 // Analytics is 3rd tab (2/4 = 0.5, but offset for position)
        
        // Start the flying egg at center of screen
        flyingEggPosition = CGPoint(x: centerX, y: centerY)
        flyingEggScale = 1.0
        flyingEggOpacity = 1.0
        showFlyingEgg = true
        
        // Animate to analytics tab position
        withAnimation(.easeInOut(duration: 0.8)) {
            flyingEggPosition = CGPoint(x: analyticsTabX, y: tabY)
            flyingEggScale = 0.3
            flyingEggOpacity = 0.8
        }
        
        // Fade out and dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.4)) {
                flyingEggOpacity = 0.0
                flyingEggScale = 0.1
            }
        }
        
        // Complete the animation and dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showFlyingEgg = false
            onDismiss()
        }
    }
}

struct NoBirdAnimationView: View {
    let onDismiss: () -> Void
    let requiredDuration: TimeInterval // Duration needed to earn a bird
    
    @State private var showEgg = true
    @State private var showNoBird = false
    @State private var eggScale: CGFloat = 1.0
    @State private var noBirdScale: CGFloat = 0.1
    @State private var sparkleOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // Animation content with card background
            VStack(spacing: 32) {
                Text("🥚 Not Quite There! 🥚")
                    .font(.custom("Geist", size: 28))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .opacity(showNoBird ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.5).delay(1.5), value: showNoBird)
                
                ZStack {
                    // Egg with cracks
                    if showEgg {
                        Image("almost")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 200, height: 200)
                            .scaleEffect(eggScale)
                            .opacity(showNoBird ? 0.0 : 1.0)
                            .animation(.easeInOut(duration: 0.3), value: showNoBird)
                    }
                    
                    // No bird (ghost)
                    if showNoBird {
                        Image("nobird")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 180, height: 180)
                            .scaleEffect(noBirdScale)
                            .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(1.0), value: noBirdScale)
                    }
                    
                    // Dim sparkle effects (less exciting)
                    ForEach(0..<4, id: \.self) { index in
                        Image(systemName: "sparkle")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .opacity(sparkleOpacity * 0.6)
                            .offset(
                                x: cos(Double(index) * .pi / 2) * 100,
                                y: sin(Double(index) * .pi / 2) * 100
                            )
                            .animation(.easeInOut(duration: 0.8).delay(Double(index) * 0.1 + 1.2), value: sparkleOpacity)
                    }
                }
                
                Text("Focus for \(formattedDuration(requiredDuration)) to earn a bird!")
                    .font(.custom("Geist", size: 18))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .opacity(showNoBird ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.5).delay(2.0), value: showNoBird)
                
                Button("Keep Trying!") {
                    onDismiss()
                }
                .font(.custom("Geist", size: 18))
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.gray)
                )
                .opacity(showNoBird ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.5).delay(2.5), value: showNoBird)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 24)
        }
        .onAppear {
            startNoBirdAnimation()
        }
    }
    
    private func formattedDuration(_ duration: TimeInterval) -> String {
        if duration < 60 {
            return "\(Int(duration)) seconds"
        } else {
            let minutes = Int(duration / 60)
            return "\(minutes)+ minute\(minutes == 1 ? "" : "s")"
        }
    }
    
    private func startNoBirdAnimation() {
        // Stage 1: Shake the egg
        withAnimation(.easeInOut(duration: 0.1).repeatCount(4, autoreverses: true)) {
            eggScale = 1.05
        }
        
        // Stage 2: Show "nobird" (less dramatic than real hatching)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showNoBird = true
            noBirdScale = 1.0
            sparkleOpacity = 0.8
        }
        
        // Stage 3: Fade sparkles
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 1.0)) {
                sparkleOpacity = 0.0
            }
        }
    }
}