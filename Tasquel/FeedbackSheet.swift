import SwiftUI

// MARK: - Feedback Sheet
//
// Sends feedback via POST to a Google Apps Script webhook.
//
// Setup (one-time):
// 1. Go to script.google.com and create a new project.
// 2. Paste the following Apps Script code, then deploy as a Web App
//    (Execute as: Me, Who has access: Anyone):
//
//    function doPost(e) {
//      var data = JSON.parse(e.postData.contents);
//      var sheet = SpreadsheetApp.openById("YOUR_SHEET_ID").getActiveSheet();
//      sheet.appendRow([new Date(), data.name || "Anonymous", data.feedback]);
//      return ContentService.createTextOutput("ok");
//    }
//
// 3. Replace the webhookURL constant below with your deployed Web App URL.
//
// The sheet receives three columns: Timestamp | Name | Feedback

private let webhookURL = "https://script.google.com/macros/s/YOUR_SCRIPT_ID/exec"

struct FeedbackSheet: View {
    let store: ChecklistStore
    @Environment(\.dismiss) private var dismiss

    @State private var feedbackText = ""
    @State private var submissionState: SubmissionState = .idle

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }
    private var retro: Bool { Theme.isRetro(theme) }

    private enum SubmissionState {
        case idle, sending, success, failure(String)
    }

    var body: some View {
        NavigationStack {
            Group {
                if retro {
                    retroFeedback
                } else {
                    standardFeedback
                }
            }
            .navigationTitle(retro ? "> FEEDBACK_" : "Send Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(retro ? "[CANCEL]" : "Cancel") { dismiss() }
                        .font(retro ? .system(.subheadline, design: .monospaced) : .body)
                        .foregroundStyle(retro ? Theme.textSecondary(theme, rc: rc) : .secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(retro ? "[SEND]" : "Send") { submit() }
                        .font(retro ? .system(.subheadline, design: .monospaced).bold() : .body.bold())
                        .foregroundStyle(retro ? Theme.accent(theme, rc: rc) : .blue)
                        .disabled(feedbackText.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
                }
            }
        }
        .preferredColorScheme(store.colorScheme)
    }

    private var isSending: Bool {
        if case .sending = submissionState { return true }
        return false
    }

    // MARK: - Standard Layout

    private var standardFeedback: some View {
        VStack(spacing: 20) {
            Text("What's on your mind?")
                .font(.subheadline).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 20)

            TextEditor(text: $feedbackText)
                .font(.body)
                .frame(minHeight: 140)
                .padding(8)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .disabled(isSending)

            statusView

            Spacer()
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Retro Layout

    private var retroFeedback: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("> what_is_on_your_mind?")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary(theme, rc: rc))

                TextEditor(text: $feedbackText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary(theme, rc: rc))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 140)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.cardFill(theme))
                            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.cardBorder(theme, rc: rc), lineWidth: 1))
                    )
                    .disabled(isSending)

                retroStatusView
            }
            .padding(16)
        }
        .background(Theme.background(theme))
        .foregroundStyle(Theme.textPrimary(theme, rc: rc))
    }

    // MARK: - Status Views

    @ViewBuilder
    private var statusView: some View {
        switch submissionState {
        case .idle:
            EmptyView()
        case .sending:
            HStack(spacing: 8) {
                ProgressView().tint(.secondary)
                Text("Sending…").font(.subheadline).foregroundStyle(.secondary)
            }
        case .success:
            Label("Feedback sent — thank you!", systemImage: "checkmark.circle.fill")
                .font(.subheadline).foregroundStyle(.green)
        case .failure(let msg):
            Label(msg, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline).foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private var retroStatusView: some View {
        switch submissionState {
        case .idle:
            EmptyView()
        case .sending:
            Text("> sending...")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.textSecondary(theme, rc: rc))
        case .success:
            Text("> [OK] feedback_sent")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(Theme.dotComplete(theme, rc: rc))
        case .failure(let msg):
            Text("> [ERR] \(msg)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.orange)
        }
    }

    // MARK: - Submit

    private func submit() {
        let text = feedbackText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        submissionState = .sending

        guard let url = URL(string: webhookURL) else {
            submissionState = .failure("Invalid webhook URL")
            return
        }

        let payload: [String: String] = [
            "name": store.userName.isEmpty ? "Anonymous" : store.userName,
            "feedback": text
        ]

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            submissionState = .failure("Failed to encode feedback")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        Task {
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                await MainActor.run {
                    if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                        submissionState = .success
                        feedbackText = ""
                        // Auto-dismiss after a short delay so user sees the confirmation
                        Task {
                            try? await Task.sleep(nanoseconds: 1_500_000_000)
                            dismiss()
                        }
                    } else {
                        submissionState = .failure("Server error — please try again")
                    }
                }
            } catch {
                await MainActor.run {
                    submissionState = .failure("No connection — please try again")
                }
            }
        }
    }
}
