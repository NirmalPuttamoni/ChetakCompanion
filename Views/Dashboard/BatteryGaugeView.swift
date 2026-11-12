//
//  BatteryGaugeView.swift
//  ChetakCompanion
//
//  Circular arc gauge showing battery percentage with gradient coloring.
//

import SwiftUI

struct BatteryGaugeView: View {
    let percentage: Int

    @State private var animatedPercentage: Double = 0

    private var gaugeColor: Color {
        switch percentage {
        case 0..<20: return .red
        case 20..<50: return .yellow
        default: return Color(hex: "00A651")
        }
    }

    private var gradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [.red, .yellow, Color(hex: "00A651")]),
            center: .center,
            startAngle: .degrees(135),
            endAngle: .degrees(135 + 270 * animatedPercentage / 100)
        )
    }

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(
                    Color.white.opacity(0.1),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(135))

            // Filled arc
            Circle()
                .trim(from: 0, to: 0.75 * animatedPercentage / 100)
                .stroke(
                    gradient,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(135))

            // Center text
            VStack(spacing: 2) {
                Text("\(percentage)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text("%")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Image(systemName: "bolt.fill")
                    .font(.caption2)
                    .foregroundStyle(gaugeColor)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                animatedPercentage = Double(percentage)
            }
        }
        .onChange(of: percentage) { newValue in
            withAnimation(.easeInOut(duration: 0.6)) {
                animatedPercentage = Double(newValue)
            }
        }
    }
}

// MARK: - Preview

#Preview("Full Battery") {
    BatteryGaugeView(percentage: 85)
        .frame(width: 160, height: 160)
        .padding()
        .background(Color(hex: "1A1A2E"))
}

#Preview("Low Battery") {
    BatteryGaugeView(percentage: 12)
        .frame(width: 160, height: 160)
        .padding()
        .background(Color(hex: "1A1A2E"))
}

#Preview("Mid Battery") {
    BatteryGaugeView(percentage: 45)
        .frame(width: 160, height: 160)
        .padding()
        .background(Color(hex: "1A1A2E"))
}
