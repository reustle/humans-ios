//
//  CirclesView.swift
//  Humans
//
//  Created by Shane Reustle on 2025-12-28.
//

import SwiftUI

struct CirclesView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "circle.grid.3x3")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
                Text("Circles")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Coming soon")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    CirclesView()
}

