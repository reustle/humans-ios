//
//  GradientInitialsAvatar.swift
//  Humans
//
//  Created by Shane Reustle on 2025-12-28.
//

import SwiftUI

/// A view that displays initials on a raised gradient background, matching iOS 26's design
/// Uses a consistent blue-grey gradient for all contacts, matching the native iOS design
struct GradientInitialsAvatar: View {
    let initials: String
    let size: CGFloat
    
    init(initials: String, size: CGFloat = 40) {
        self.initials = initials
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Gradient background with raised effect
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: gradientColors),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
            
            // Initials text
            Text(initials)
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }
    
    /// Calculates font size based on avatar size
    private var fontSize: CGFloat {
        size * 0.4 // 40% of the avatar size
    }
    
    /// Returns the blue-grey gradient colors matching iOS 26's native design
    /// Lighter blue-grey at top-left, darker blue-grey at bottom-right
    private var gradientColors: [Color] {
        // Subtle blue-grey gradient matching iOS 26's contact avatar design
        // Top-left: lighter blue-grey (RGB approximately 0.55, 0.65, 0.75)
        // Bottom-right: darker blue-grey (RGB approximately 0.45, 0.55, 0.65)
        return [
            Color(red: 0.55, green: 0.65, blue: 0.75), // Lighter blue-grey
            Color(red: 0.45, green: 0.55, blue: 0.65)  // Darker blue-grey
        ]
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 16) {
            GradientInitialsAvatar(initials: "DT", size: 40)
            GradientInitialsAvatar(initials: "HZ", size: 40)
            GradientInitialsAvatar(initials: "AB", size: 40)
            GradientInitialsAvatar(initials: "MC", size: 40)
        }
        
        HStack(spacing: 16) {
            GradientInitialsAvatar(initials: "JD", size: 80)
            GradientInitialsAvatar(initials: "JS", size: 80)
        }
    }
    .padding()
}

