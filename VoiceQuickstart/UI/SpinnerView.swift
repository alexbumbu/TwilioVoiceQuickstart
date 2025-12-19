//
//  SpinnerView.swift
//  VoiceQuickstart
//
//  Created by Alex Bumbu on 17.11.2025.
//


import SwiftUI
import Combine

struct SpinnerView<Content: View>: View {
    @Binding var isSpinning: Bool
    
    private var content: () -> Content
    private let duration: TimeInterval = 1
    private let angle: Double = 360
    
    @State private var step = 0
    @State private var timer: AnyPublisher<Date, Never> = Empty().eraseToAnyPublisher()
    
    public init(isSpinning: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) {
        self._isSpinning = isSpinning
        self.content = content
    }
    
    var body: some View {
        content()
            .rotationEffect(.degrees(Double(step) * angle))
            .animation(.linear(duration: duration), value: step)
            .onReceive(timer) { _ in
                step += 1
            }
            .onChange(of: isSpinning) { _, newValue in
                if newValue {
                    timer = Timer.publish(every: duration, on: .main, in: .common)
                        .autoconnect()
                        .eraseToAnyPublisher()
                } else {
                    timer = Empty().eraseToAnyPublisher()
                }
            }
    }
}
