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
    let message: String
    let systemImage: String

    var body: some View {
        CardPanel {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppTheme.accentTint)
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct LoadingCard: View {
    let title: String

    var body: some View {
        CardPanel {
            HStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                    .tint(AppTheme.accentTint)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text("The app is syncing with the server.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
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

struct ActivityCard: View {
    let activity: ActivitySummary
    let action: (() -> Void)?

    var body: some View {
        CardPanel {
            VStack(alignment: .leading, spacing: 16) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(activity.name)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            Text(activity.briefDescription)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 16)
                        StateChip(title: activity.state.title, tint: AppTheme.stateTint(for: activity.state))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(activity.name)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        StateChip(title: activity.state.title, tint: AppTheme.stateTint(for: activity.state))
                        Text(activity.briefDescription)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                    GridRow {
                        metadataLabel(title: "Date", systemImage: "calendar")
                        Text(ServerDate.dateText(activity.date))
                            .font(.subheadline.weight(.medium))
                    }
                    GridRow {
                        metadataLabel(title: "Place", systemImage: "mappin.and.ellipse")
                        Text(activity.location)
                            .font(.subheadline.weight(.medium))
                    }
                    GridRow {
                        metadataLabel(title: "Duration", systemImage: "clock")
                        Text(DisplayText.duration(minutes: activity.duration))
                            .font(.subheadline.weight(.medium))
                    }
                }

                CapacityBar(current: activity.volunteerNum, limit: activity.maxVolunteerNum)

                if let action {
                    Button(activity.viewerParticipating ? "Participating" : "Apply Activity", action: action)
                        .buttonStyle(.borderedProminent)
                        .tint(activity.viewerParticipating ? .orange : AppTheme.accentTint)
                        .disabled(activity.viewerParticipating || activity.state != .needVolunteer)
                }
            }
        }
    }

    private func metadataLabel(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}

struct ContractNoteCard: View {
    let title: String
    let message: String

    var body: some View {
        CardPanel {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: "wrench.and.screwdriver")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
