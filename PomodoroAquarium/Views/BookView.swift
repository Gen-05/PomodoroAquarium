//
//  BookView.swift
//  PomodoroAquarium
//
//  Created by 阿部弦生 on 2026/07/31.
//

import SwiftUI

struct BookView: View {
    var body: some View {
        List(sampleFish) { fish in
            HStack {
                Image(systemName: "fish")
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text(fish.name)
                        .font(.headline)
                    
                    Text(fish.rarity.rawValue)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }
        }
    }
}

#Preview {
    BookView()
}
