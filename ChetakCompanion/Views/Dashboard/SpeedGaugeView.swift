//
//  SpeedGaugeView.swift
//  ChetakCompanion
//
//  Speedometer-style semicircular gauge with animated needle.
//

import SwiftUI

struct SpeedGaugeView: View {
    let speed: Double
    var maxSpeed: Double = 80

    @State private var animatedSpeed: Double = 0

    private let accentGreen = Color(hex: "00A651")
    private let tickMarks: [Double] = [0, 10, 20, 30, 40, 50, 60, 70, 80]

    // Maps speed to an angle in the semicircular arc (0° at left, 180° at right)
    private var needleAngle: Double {
        let clamped = min(animatedSpeed, maxSpeed)
        return -90 + (clamped / maxSpeed) * 180
    }

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.85)
            let radius = min(geo.size.width, geo.size.height) * 0.42

            ZStack {
                // Background arc
                arcPath(center: center, radius: radius)
                    .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 8, lineCap: .round))

                // Filled arc
                arcPath(center: center, radius: radius)
                    .trim(from: 0, to: min(animatedSpeed / maxSpeed, 1.0))
                    .stroke(
                        LinearGradient(
                            colors: [accentGreen, .yellow, .orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )

                // Speed limit markers
                ForEach(tickMarks, id: \.self) { tick in
                    let angle = Angle.degrees(-180 + (tick / maxSpeed) * 180)
                    let tickStart = pointOnCircle(center: center, radius: radius - 16, angle: angle)
                    let tickEnd = pointOnCircle(center: center, radius: radius + 4, angle: angle)

                    Path { path in
                        path.move(to: tickStart)
                        path.addLine(to: tickEnd)
                    }
                    .stroke(Color.white.opacity(0.4), lineWidth: tick.truncatingRemainder(dividingBy: 20) == 0 ? 2 : 1)

                    // Label for major ticks
                    if tick.truncatingRemainder(dividingBy: 20) == 0 {
                        let labelPos = pointOnCircle(center: center, radius: radius - 30, angle: angle)
                        Text("\(Int(tick))")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .position(labelPos)
                    }
                }

                // Needle
                NeedleShape()
                    .fill(accentGreen)
                    .frame(width: 4, height: radius - 10)
                    .offset(y: -(radius - 10) / 2)
                    .rotationEffect(.degrees(needleAngle))
                    .position(center)

                // Center dot
                Circle()
                    .fill(accentGreen)
                    .frame(width: 12, height: 12)
                    .position(center)

                // Speed text
                VStack(spacing: 0) {
                    Text(String(format: "%.0f", speed))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text("km/h")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .position(x: center.x, y: center.y - 40)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                animatedSpeed = speed
            }
        }
        .onChange(of: speed) { newValue in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                animatedSpeed = newValue
            }
        }
    }

    // MARK: - Helpers

    private func arcPath(center: CGPoint, radius: CGFloat) -> Path {
        Path { path in
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(180),
                endAngle: .degrees(0),
                clockwise: false
            )
        }
    }

    private func pointOnCircle(center: CGPoint, radius: CGFloat, angle: Angle) -> CGPoint {
        CGPoint(
            x: center.x + radius * cos(CGFloat(angle.radians)),
            y: center.y + radius * sin(CGFloat(angle.radians))
        )
    }
}

// MARK: - Needle Shape

struct NeedleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        path.move(to: CGPoint(x: midX - 2, y: rect.maxY))
        path.addLine(to: CGPoint(x: midX, y: rect.minY))
        path.addLine(to: CGPoint(x: midX + 2, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview {
    SpeedGaugeView(speed: 42)
        .frame(height: 220)
        .padding()
        .background(Color(hex: "1A1A2E"))
}

#Preview("Zero Speed") {
    SpeedGaugeView(speed: 0)
        .frame(height: 220)
        .padding()
        .background(Color(hex: "1A1A2E"))
}
