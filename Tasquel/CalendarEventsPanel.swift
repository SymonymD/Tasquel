import SwiftUI

// MARK: - Calendar Events Panel

/// The week's calendar events, shown inside the bottom bar when its calendar toggle
/// is on. Read-only; tapping an event opens the Calendar app at that event's date.
/// Swiping down minimizes it (from the handle/header, or anywhere when the list doesn't scroll).
struct CalendarEventsPanel: View {
    let store: ChecklistStore
    /// The week's events by day, or nil while loading.
    let days: [EventDay]?
    let onOpen: (CalendarEvent) -> Void
    /// Called with the swipe's downward speed, in panel heights per second (0 when not swiped),
    /// so the close can carry on at the finger's speed.
    let onDismiss: (_ velocity: Double) -> Void
    /// Whether the panel is being dragged down (shrunk by the finger).
    var onDragChanged: (Bool) -> Void = { _ in }

    @State private var listHeight: CGFloat = 0
    @State private var panelHeight: CGFloat = 0
    /// How far the panel has been dragged down; it shrinks by this much.
    @State private var dragOffset: CGFloat = 0
    /// Resets on its own when iOS cancels the drag (onEnded isn't called then), so a
    /// cancelled drag can't leave the panel shrunk with its events disabled.
    @GestureState private var isDragging = false
    @State private var isDismissing = false
    /// Set when a press on an event is held: letting go then doesn't open Calendar.
    @State private var wasHeld = false

    private let maxListHeight: CGFloat = 280
    private var listScrolls: Bool { listHeight > maxListHeight }

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }
    private var retro: Bool { Theme.isRetro(theme) }
    private var design: Font.Design { retro ? .monospaced : .default }

    /// Each event once (multi-day events appear under several days).
    private var eventCount: Int {
        Set((days ?? []).flatMap(\.events).map(\.event.id)).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Grab handle + header: always draggable.
            VStack(spacing: 6) {
            Capsule()
                .fill(Theme.textTertiary(theme, rc: rc))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
            HStack(alignment: .firstTextBaseline) {
                Text(retro ? "[EVENTS]" : "This Week's Events")
                    .font(.system(.subheadline, design: design).weight(.semibold))
                    .foregroundStyle(Theme.textPrimary(theme, rc: rc))
                Spacer()
                if days != nil {
                    Text(eventCount == 1 ? "1 event" : "\(eventCount) events")
                        .font(.system(.caption, design: design))
                        .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                }
            }
            }
            .contentShape(Rectangle())
            .gesture(dismissDrag)

            // As tall as its events, up to a limit; then it scrolls. Shrinks while dragged down.
            // A short list isn't in a ScrollView at all: a vertical ScrollView claims vertical
            // drags even when it can't scroll, which would block swipe-down from the list.
            Group {
                if listScrolls {
                    ScrollView { measuredList }
                } else {
                    measuredList
                }
            }
            .frame(height: max(0, min(max(listHeight, 20), maxListHeight) - dragOffset), alignment: .top)
            .clipped()
            // A drag that starts on an event must not open it.
            .disabled(dragOffset > 0)
            // Attached outside `.disabled`, which would otherwise cancel this drag as it starts.
            .simultaneousGesture(dismissDrag, including: listScrolls ? .subviews : .all)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { panelHeight = $0 }
        .accessibilityAction(.escape) { onDismiss(0) }
        .onChange(of: dragOffset > 0) { _, dragged in onDragChanged(dragged) }
        .onChange(of: isDragging) { _, dragging in
            guard !dragging, !isDismissing, dragOffset > 0 else { return }
            withAnimation(.snappy(duration: 0.25)) { dragOffset = 0 }
        }
    }

    private var measuredList: some View {
        eventList
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { listHeight = $0 }
    }

    private var dismissDrag: some Gesture {
        // Measured on the screen: the header moves as the panel shrinks, and measuring
        // against it made the panel jump back and forth every frame of a slow drag.
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .updating($isDragging) { _, dragging, _ in dragging = true }
            .onChanged { value in
                if isDismissing { isDismissing = false }
                dragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                if value.translation.height > 60 || value.predictedEndTranslation.height > 160 {
                    isDismissing = true
                    let speed = max(0, value.velocity.height) / max(panelHeight, 1)
                    onDismiss(min(speed, 12))
                } else {
                    withAnimation(.snappy(duration: 0.25)) { dragOffset = 0 }
                }
            }
    }

    @ViewBuilder
    private var eventList: some View {
        VStack(alignment: .leading, spacing: 10) {
            if days == nil {
                ProgressView().frame(maxWidth: .infinity)
            } else if eventCount == 0 {
                Text(retro ? "> nothing scheduled" : "Nothing scheduled this week.")
                    .font(.system(.subheadline, design: design))
                    .foregroundStyle(Theme.textTertiary(theme, rc: rc))
            }
            ForEach(days ?? []) { day in
                VStack(alignment: .leading, spacing: 4) {
                    Text(dayTitle(day.date))
                        .font(.system(.caption, design: design).weight(.semibold))
                        .foregroundStyle(Calendar.current.isDateInToday(day.date) ? Theme.accent(theme, rc: rc) : Theme.textSecondary(theme, rc: rc))
                    ForEach(day.events) { dayEvent in
                        Button {
                            guard !wasHeld else { wasHeld = false; return }
                            onOpen(dayEvent.event)
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Circle().fill(dayEvent.event.color).frame(width: 8, height: 8)
                                Text(dayEvent.timeLabel)
                                    .font(.system(.caption, design: design).monospacedDigit())
                                    .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                                    .frame(width: 66, alignment: .leading)
                                Text(dayEvent.event.title)
                                    .font(.system(.subheadline, design: design))
                                    .foregroundStyle(Theme.textPrimary(theme, rc: rc))
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.up.forward.app")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textTertiary(theme, rc: rc))
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(EventButtonStyle())
                        // Only a tap opens the event; holding (or pausing before a swipe) doesn't.
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.4)
                                .onChanged { _ in wasHeld = false }
                                .onEnded { _ in wasHeld = true }
                        )
                        .accessibilityLabel("\(dayEvent.event.title), \(dayEvent.timeLabel)")
                        .accessibilityHint("Opens Calendar")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dayTitle(_ date: Date) -> String {
        let title = date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        return retro ? title.uppercased() : title
    }
}

/// Like `.plain`, but doesn't dim while disabled: the list is disabled during a swipe
/// down, and dimming then made the events flash gray as the panel closed.
private struct EventButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.6 : 1)
    }
}
