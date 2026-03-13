import Foundation
import SwiftUI

enum AppTheme {
    static let contentWidth: CGFloat = 880
    static let cardRadius: CGFloat = 28

    static var pageBackground: some ShapeStyle {
        LinearGradient(
            colors: [
                Color(.systemGroupedBackground),
                Color(.secondarySystemGroupedBackground),
                Color(.systemGroupedBackground),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func stateTint(for state: ActivityState) -> Color {
        switch state {
        case .needVolunteer:
            .green
        case .going:
            .blue
        case .ended:
            .secondary
        case .canceled:
            .red
        }
    }

    static func stateTint(for state: RecordState) -> Color {
        switch state {
        case .todo:
            .orange
        case .done:
            .green
        case .canceled:
            .red
        }
    }
}

enum ServerDate {
    static func parsed(_ value: String?) -> Date? {
        guard let value else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    static func dateText(_ value: String?) -> String {
        guard let date = parsed(value) else {
            return "To be scheduled"
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    static func dateTimeText(_ value: String?) -> String {
        guard let date = parsed(value) else {
            return "Unavailable"
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

enum DisplayText {
    static func duration(minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours > 0, remainingMinutes > 0 {
            return "\(hours)h \(remainingMinutes)m"
        }
        if hours > 0 {
            return "\(hours)h"
        }
        return "\(remainingMinutes)m"
    }

    static func hours(minutes: Int) -> String {
        let value = Double(minutes) / 60
        return value.formatted(.number.precision(.fractionLength(1))) + " hrs"
    }

    static func capacity(current: Int, limit: Int?) -> String {
        if let limit {
            return "\(current)/\(limit)"
        }
        return "\(current)"
    }

    static func shortIdentifier(_ value: String) -> String {
        String(value.suffix(6))
    }
}

extension String {
    var trimmedNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
