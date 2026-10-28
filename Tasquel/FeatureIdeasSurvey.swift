import SwiftUI

// MARK: - Feature Ideas Survey

/// Features being considered, for the Settings survey. Not in the app: the raw values
/// are what the survey sends, so they stay the same even when the titles change.
enum UpcomingFeature: String, CaseIterable, Identifiable {
    case iCloudSync = "iCloud Sync"
    case stats = "Stats & Charts"
    case secretCategories = "Secret Categories"

    var id: Self { self }

    var title: String {
        switch self {
        case .iCloudSync: "Sync Across Devices"
        case .stats: "Stats & Charts"
        case .secretCategories: "Locked Categories"
        }
    }

    var detail: String {
        switch self {
        case .iCloudSync: "Your tasks on your iPhone and iPad"
        case .stats: "See how your weeks, goals and habits went"
        case .secretCategories: "Categories that stay hidden until you unlock them"
        }
    }

    var symbol: String {
        switch self {
        case .iCloudSync: "icloud"
        case .stats: "chart.bar.xaxis"
        case .secretCategories: "lock"
        }
    }
}

/// Where survey answers go: a Cloudflare Pages Function on the support site that stores
/// them anonymously (see the site's functions/tasquel/survey.js). Only the ticked features,
/// the optional comment and the app version are sent: no name, email, device or app
/// identifier, over a cookie-free session. Send stays off until `isLive`.
enum SurveyForm {
    static let endpoint = URL(string: "https://jbfentner.com/tasquel/survey")!
    /// Turned on once the site's endpoint is deployed.
    static let isLive = true

    static var isConfigured: Bool { isLive }

    private struct Submission: Encodable {
        let app = "Tasquel"
        let version: String
        let features: [String]
        let comment: String
    }

    static func send(_ features: [UpcomingFeature], comment: String) async throws {
        let submission = Submission(
            version: AppInfo.version(),
            features: features.map(\.rawValue),
            comment: String(comment.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1000))
        )
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(submission)
        let (_, response) = try await URLSession(configuration: .ephemeral).data(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(status) else {
            throw URLError(.badServerResponse)
        }
    }
}

/// What's been ticked and typed in Feature Ideas, kept while Settings switches layout (Retro
/// has its own) or closes and opens again; cleared once sent.
@Observable
final class FeatureIdeasDraft {
    static let shared = FeatureIdeasDraft()
    var picks: Set<UpcomingFeature> = []
    var comment = ""
}

/// Settings ▸ Feature Ideas: tick the features you'd use (Tasquel's own check circles),
/// add a comment if you like, and send. Rows only; Settings puts them in its section.
struct FeatureIdeasSurvey: View {
    let store: ChecklistStore
    /// The comment field, which Settings keeps in view as it grows.
    static let commentID = "featureIdeasComment"

    @Bindable private var draft = FeatureIdeasDraft.shared
    @State private var status = Status.idle
    /// Sent once already: shows thanks instead of the form, until Change. (The key keeps
    /// the section's old name so earlier answers are remembered.)
    @AppStorage("didSendComingSoonSurvey") private var didSend = false

    private enum Status: Equatable { case idle, sending, failed }

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }
    private var retro: Bool { Theme.isRetro(theme) }
    private var canSend: Bool {
        SurveyForm.isConfigured && status != .sending
            && (!draft.picks.isEmpty || !draft.comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        if didSend {
            HStack {
                Label(retro ? "> thanks // picks sent" : "Thanks! Your picks were sent.", systemImage: "checkmark.circle.fill")
                    .font(retro ? Theme.bodyFont(theme) : .body)
                    .foregroundStyle(retro ? Theme.accent(theme, rc: rc) : .green)
                Spacer()
                Button(retro ? "[CHANGE]" : "Change") { didSend = false }
                    .font(retro ? Theme.bodyFont(theme) : .subheadline)
                    .foregroundStyle(Theme.accent(theme, rc: rc))
                    .buttonStyle(.borderless)
            }
            .frame(minHeight: 44)
        } else {
            ForEach(UpcomingFeature.allCases) { feature in
                featureRow(feature)
            }
            TextField(retro ? "anything_else>" : "Anything else? (optional)", text: $draft.comment, axis: .vertical)
                .font(retro ? Theme.bodyFont(theme) : .body)
                .lineLimit(1...4)
                .frame(minHeight: 44)
                .id(Self.commentID)
            Button(action: send) {
                HStack {
                    Text(sendTitle)
                        .font(retro ? Theme.bodyFont(theme) : .body.weight(.semibold))
                    if status == .sending { Spacer(); ProgressView() }
                }
                .foregroundStyle(canSend ? Theme.accent(theme, rc: rc) : Theme.textTertiary(theme, rc: rc))
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
    }

    private var sendTitle: String {
        switch status {
        case .failed: retro ? "> send failed // try again" : "Couldn't send. Try Again"
        case .sending: retro ? "> sending…" : "Sending…"
        case .idle: retro ? "> Send" : "Send Anonymously"
        }
    }

    /// The check circle matches a task's: filled when ticked.
    private func featureRow(_ feature: UpcomingFeature) -> some View {
        let isPicked = draft.picks.contains(feature)
        return Button {
            if isPicked { draft.picks.remove(feature) } else { draft.picks.insert(feature) }
        } label: {
            HStack(spacing: 12) {
                Group {
                    if retro {
                        Text(isPicked ? "[x]" : "[ ]")
                            .hiddenFromVoiceOver()  // the row says it's selected
                            .font(.system(.subheadline, design: .monospaced).bold())
                            .foregroundStyle(isPicked ? Theme.dotComplete(theme, rc: rc) : Theme.textSecondary(theme, rc: rc))
                    } else {
                        Circle()
                            .fill(isPicked ? Theme.dotComplete(theme, rc: rc) : Color.clear)
                            .overlay(Circle().stroke(isPicked ? Theme.dotComplete(theme, rc: rc) : Theme.textSecondary(theme, rc: rc), lineWidth: 1.5))
                            .frame(width: 20, height: 20)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Label(feature.title, systemImage: feature.symbol)
                        .font(retro ? Theme.bodyFont(theme) : .body)
                        .foregroundStyle(Theme.textPrimary(theme, rc: rc))
                    Text(feature.detail)
                        .font(retro ? Theme.captionFont(theme) : .footnote)
                        .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isPicked)
        .accessibilityAddTraits(isPicked ? .isSelected : [])
        .accessibilityHint("Tick if you'd use this")
    }

    private func send() {
        guard canSend else { return }
        status = .sending
        let features = UpcomingFeature.allCases.filter(draft.picks.contains)
        Task {
            do {
                try await SurveyForm.send(features, comment: draft.comment)
                status = .idle
                draft.picks = []
                draft.comment = ""
                didSend = true
            } catch {
                status = .failed
            }
        }
    }
}
