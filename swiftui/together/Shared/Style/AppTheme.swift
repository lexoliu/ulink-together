import Foundation
import SwiftUI

enum AppTheme {
    static let contentWidth: CGFloat = 960
    static let cardRadius: CGFloat = 16
    static let compactCardRadius: CGFloat = 12

    static var pageBackground: some ShapeStyle {
        Color(uiColor: .systemGroupedBackground)
    }

    static var accentTint: Color {
        Color(red: 0.20, green: 0.36, blue: 0.56)
    }

    static var neutralTint: Color {
        Color(red: 0.43, green: 0.49, blue: 0.56)
    }

    static func stateTint(for state: ActivityState) -> Color {
        switch state {
        case .needVolunteer:
            Color(red: 0.30, green: 0.55, blue: 0.35)
        case .going:
            accentTint
        case .ended:
            neutralTint
        case .canceled:
            Color(red: 0.70, green: 0.30, blue: 0.28)
        }
    }

    static func stateTint(for state: RecordState) -> Color {
        switch state {
        case .pendingApproval:
            Color(red: 0.72, green: 0.52, blue: 0.22)
        case .approved:
            Color(red: 0.30, green: 0.55, blue: 0.35)
        case .confirmed:
            accentTint
        case .canceled:
            Color(red: 0.70, green: 0.30, blue: 0.28)
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
