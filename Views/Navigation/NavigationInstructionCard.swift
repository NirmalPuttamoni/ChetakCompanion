//
//  NavigationInstructionCard.swift
//  ChetakCompanion
//
//  Card overlay showing the current turn-by-turn navigation instruction.
//

import SwiftUI

struct NavigationInstructionCard: View {
    let instruction: NavigationInstruction

    @State private var appeared = false

    private let accentGreen = Color(hex: "00A651")

    var body: some View {
        HStack(spacing: 16) {
            // Direction icon
            directionIcon
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(accentGreen)
                .frame(width: 50, height: 50)
                .background(accentGreen.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            // Street name and distance
            VStack(alignment: .leading, spacing: 4) {
                Text(instruction.streetName)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(formattedDistance)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Direction label
            Text(directionLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(accentGreen)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(accentGreen.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        .offset(y: appeared ? 0 : 24)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }

    // MARK: - Computed Properties

    @ViewBuilder
    private var directionIcon: some View {
        Image(systemName: instruction.iconName)
    }

    private var directionLabel: String {
        switch instruction.direction {
        case .left: return "Turn Left"
        case .right: return "Turn Right"
        case .straight: return "Continue"
        case .uTurn: return "U-Turn"
        case .arrive: return "Arrive"
        }
    }

    private var formattedDistance: String {
        if instruction.distanceMeters >= 1000 {
            return String(format: "%.1f km", instruction.distanceMeters / 1000)
        } else {
            return String(format: "%.0f m", instruction.distanceMeters)
        }
    }
}

// MARK: - Preview

#Preview("Turn Right") {
    NavigationInstructionCard(
        instruction: NavigationInstruction(
            direction: .right,
            streetName: "Brigade Road",
            distanceMeters: 250
        )
    )
    .padding()
    .background(Color(hex: "1A1A2E"))
}

#Preview("Continue Straight") {
    NavigationInstructionCard(
        instruction: NavigationInstruction(
            direction: .straight,
            streetName: "MG Road",
            distanceMeters: 1200
        )
    )
    .padding()
    .background(Color(hex: "1A1A2E"))
}

#Preview("Arriving") {
    NavigationInstructionCard(
        instruction: NavigationInstruction(
            direction: .arrive,
            streetName: "Chetak Showroom",
            distanceMeters: 50
        )
    )
    .padding()
    .background(Color(hex: "1A1A2E"))
}
