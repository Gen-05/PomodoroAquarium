//
//  AquariumFloor.swift
//  PomodoroAquarium
//

import SwiftUI

struct AquariumFloor: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack(alignment: .top) {
                LinearGradient(
                    colors: [
                        Color(red: 0.78, green: 0.70, blue: 0.49),
                        Color(red: 0.50, green: 0.42, blue: 0.28)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Ellipse()
                    .fill(Color(red: 0.85, green: 0.78, blue: 0.58))
                    .frame(height: 42)
                    .offset(x: -90, y: -17)

                Ellipse()
                    .fill(Color(red: 0.72, green: 0.63, blue: 0.43))
                    .frame(height: 34)
                    .offset(x: 120, y: -10)
            }
            .frame(height: 145)
            .shadow(color: .black.opacity(0.16), radius: 18, y: -5)
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    ZStack {
        Color.blue
        AquariumFloor()
    }
}
