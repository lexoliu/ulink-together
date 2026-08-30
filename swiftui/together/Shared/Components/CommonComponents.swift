import SwiftUI

struct AppBackgroundView: View {
    var body: some View {
        Rectangle()
            .fill(AppTheme.pageBackground)
            .ignoresSafeArea()
    }
}

struct CardPanel<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(AppCardSurface())
    }
}

struct PageWidthReader<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                content
            }
            .frame(maxWidth: AppTheme.contentWidth)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .scrollIndicators(.hidden)
        .background(AppBackgroundView())
    }
}

struct StateChip: View {
    let title: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: "circle.fill")
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tint.opacity(0.10), in: Capsule())
            .fixedSize(horizontal: true, vertical: false)
    }
}

struct CapacityBar: View {
    let current: Int
    let limit: Int?

    private var progress: Double {
        guard let limit, limit > 0 else {
            return 0
        }
        return min(Double(current) / Double(limit), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Capacity")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(DisplayText.capacity(current: current, limit: limit))
                    .font(.subheadline.weight(.semibold))
            }

            ProgressView(value: progress)
                .tint(progress > 0.8 ? .orange : AppTheme.accentTint)
        }
    }
}

struct AvatarBadge: View {
    let title: String
    let imageURL: URL?
    var size: CGFloat = 52

    var body: some View {
        Group {
            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle().strokeBorder(.white.opacity(0.7), lineWidth: 1)
        }
    }

    private var placeholder: some View {
        Circle()
            .fill(.quaternary)
            .overlay {
                Text(initials)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
    }

    private var initials: String {
        let pieces = title.split(separator: " ")
        let letters = pieces.prefix(2).compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters)
    }
}

struct InlineErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(uiColor: .systemOrange))
                .frame(width: 24, height: 24)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .strokeBorder(Color(uiColor: .separator).opacity(0.18), lineWidth: 1)
        }
    }
}

struct EmptyStateCard: View {
    let title: String
    let systemImage: String

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage)
    }
}

struct LoadingCard: View {
    let title: String

    var body: some View {
        HStack(spacing: 14) {
            ProgressView()
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 12)
    }
}

private struct AppCardSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                    .strokeBorder(Color(uiColor: .separator).opacity(0.14), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.04), radius: 14, y: 6)
    }
}

struct RankingRow: View {
    let entry: LeaderboardEntry
    let avatarURL: URL?

    var body: some View {
        HStack(spacing: 16) {
            rankingIndicator
                .frame(width: 44, alignment: .leading)

            AvatarBadge(title: entry.realname, imageURL: avatarURL, size: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.realname)
                    .font(.headline)
                Text(entry.classname)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(DisplayText.hours(minutes: entry.totalMinutes))
                .font(.headline.weight(.semibold))
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var rankingIndicator: some View {
        if let medalColor {
            ZStack {
                Image(systemName: "medal.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(medalColor)

                Text("\(entry.rank)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .offset(y: -1)
            }
        } else {
            Text("#\(entry.rank)")
                .font(.title3.weight(.bold))
                .foregroundStyle(.secondary)
        }
    }

    private var medalColor: Color? {
        switch entry.rank {
        case 1:
            Color(red: 0.85, green: 0.65, blue: 0.13)
        case 2:
            Color(red: 0.60, green: 0.62, blue: 0.65)
        case 3:
            Color(red: 0.72, green: 0.45, blue: 0.20)
        default:
            nil
        }
    }
}

/// Compact list row for displaying an activity in a native `List`.
/// Designed for NavigationSplitView sidebars and standard list contexts.
struct ActivityListRow: View {
    let activity: ActivitySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(activity.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 8)
                StateChip(title: activity.state.title, tint: AppTheme.stateTint(for: activity.state))
            }

            Text(metadataLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            CapacityBar(current: activity.volunteerNum, limit: activity.maxVolunteerNum)
        }
        .padding(.vertical, 4)
    }

    private var metadataLine: String {
        let date = ServerDate.dateText(activity.date)
        let parts = [date, activity.location, DisplayText.duration(minutes: activity.duration)]
        return parts.joined(separator: " · ")
    }
}

/// Full activity card with description, metadata grid, and optional action button.
/// Use in Organiser workspace or contexts that need richer detail than `ActivityListRow`.
struct ActivityCard: View {
    let activity: ActivitySummary
    let action: (() -> Void)?
    var isSelected: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(activity.name)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                Spacer(minLength: 12)
                StateChip(title: activity.state.title, tint: AppTheme.stateTint(for: activity.state))
            }

            Text(activity.briefDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text(metadataLine)
                .font(.caption)
                .foregroundStyle(.tertiary)

            CapacityBar(current: activity.volunteerNum, limit: activity.maxVolunteerNum)

            if let action {
                Button(activity.viewerParticipating ? "Participating" : "Apply Activity", action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(activity.viewerParticipating ? .orange : AppTheme.accentTint)
                    .disabled(activity.viewerParticipating || activity.state != .needVolunteer)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .fill(isSelected ? AppTheme.accentTint.opacity(0.08) : Color(uiColor: .secondarySystemGroupedBackground))
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .strokeBorder(isSelected ? AppTheme.accentTint : Color(uiColor: .separator).opacity(0.14), lineWidth: 1)
        }
    }

    private var metadataLine: String {
        let date = ServerDate.dateText(activity.date)
        let parts = [date, activity.location, DisplayText.duration(minutes: activity.duration)]
        return parts.joined(separator: " · ")
    }
}

