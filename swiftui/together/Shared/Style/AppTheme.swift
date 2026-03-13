import Foundation
import SwiftUI

enum AppTheme {
    static let contentWidth: CGFloat = 960
    static let cardRadius: CGFloat = 30
    static let compactCardRadius: CGFloat = 22

    static var pageBackground: some ShapeStyle {
        LinearGradient(
            colors: [
                Color(red: 0.97, green: 0.96, blue: 0.94),
                Color(red: 0.95, green: 0.95, blue: 0.93),
                Color(red: 0.97, green: 0.96, blue: 0.94),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var accentTint: Color {
        Color(red: 0.16, green: 0.28, blue: 0.44)
    }

    static var neutralTint: Color {
        Color(red: 0.43, green: 0.49, blue: 0.56)
    }

    static func stateTint(for state: ActivityState) -> Color {
        switch state {
        case .needVolunteer:
            Color(red: 0.37, green: 0.47, blue: 0.33)
        case .going:
            accentTint
        case .ended:
            neutralTint
        case .canceled:
            Color(red: 0.63, green: 0.30, blue: 0.27)
        }
    }

    static func stateTint(for state: RecordState) -> Color {
        switch state {
        case .todo:
            Color(red: 0.64, green: 0.46, blue: 0.23)
        case .done:
            Color(red: 0.37, green: 0.47, blue: 0.33)
        case .canceled:
            Color(red: 0.63, green: 0.30, blue: 0.27)
        }
    }
}

enum ServerDate {
    static let encoderFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

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

    static func encoded(_ date: Date) -> String {
        encoderFormatter.string(from: date)
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
