import SwiftUI

struct TimelineEventRow: View {
    let event: VehicleLocationEventEntity
    let isFirst: Bool
    let isLast: Bool
    let vehicleName: String?

    private var eventType: LocationEventType {
        event.locationEventType
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline connector
            VStack(spacing: 0) {
                Rectangle()
                    .fill(isFirst ? Color.clear : Color(.systemGray4))
                    .frame(width: 2, height: 16)

                ZStack {
                    Circle()
                        .fill(colorForType(eventType))
                        .frame(width: 28, height: 28)

                    Image(systemName: eventType.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }

                Rectangle()
                    .fill(isLast ? Color.clear : Color(.systemGray4))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 28)

            // Event content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(event.title ?? eventType.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Spacer()

                    Text(event.date, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if let vehicleName = vehicleName {
                    HStack(spacing: 4) {
                        Image(systemName: "car.fill")
                            .font(.caption2)
                        Text(vehicleName)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }

                if let address = event.address, !address.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.caption2)
                        Text(address)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundColor(.secondary)
                }

                if let notes = event.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Text(formattedTime(event.date))
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .padding(.vertical, 8)
            .padding(.trailing, 12)
        }
        .padding(.horizontal, 16)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func colorForType(_ type: LocationEventType) -> Color {
        switch type {
        case .fuel: return .cyan
        case .service: return .blue
        case .cost: return .green
        case .home: return .purple
        case .purchase: return .indigo
        case .accident: return .red
        case .trip: return .orange
        }
    }
}
