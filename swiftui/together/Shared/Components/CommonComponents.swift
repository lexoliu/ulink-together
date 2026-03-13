import SwiftUI

struct AppBackgroundView: View {
    var body: some View {
        Rectangle()
            .fill(AppTheme.pageBackground)
            .ignoresSafeArea()
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(.blue.opacity(0.08))
                    .frame(width: 280, height: 280)
                    .blur(radius: 8)
                    .offset(x: 70, y: -40)
            }
            .overlay(alignment: .bottomLeading) {
                Circle()
                    .fill(.teal.opacity(0.08))
                    .frame(width: 320, height: 320)
                    .blur(radius: 12)
                    .offset(x: -100, y: 80)
            }
    }
}

struct CardPanel<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                    .fill(.thinMaterial)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.35), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.04), radius: 18, y: 12)
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
            .padding(.vertical, 16)
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
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tint.opacity(0.12), in: Capsule())
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
                .tint(progress > 0.8 ? .orange : .blue)
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
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline)
            .foregroundStyle(.orange)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                    .foregroundStyle(.blue)
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

struct RankingRow: View {
    let entry: LeaderboardEntry
    let avatarURL: URL?

    var body: some View {
        HStack(spacing: 16) {
            Text("#\(entry.rank)")
                .font(.title3.weight(.bold))
                .foregroundStyle(entry.rank <= 3 ? .blue : .secondary)
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
}

struct ActivityCard: View {
    let activity: ActivitySummary
    let action: (() -> Void)?

    var body: some View {
        CardPanel {
            VStack(alignment: .leading, spacing: 16) {
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
                    Button(activity.viewerJoined ? "Joined" : "Join Activity", action: action)
                        .buttonStyle(.borderedProminent)
                        .tint(activity.viewerJoined ? .orange : .blue)
                        .disabled(activity.viewerJoined || activity.state != .needVolunteer)
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
