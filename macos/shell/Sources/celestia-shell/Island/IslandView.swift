import AppKit
import ShellCore
import SwiftUI

struct IslandView: View {
    @ObservedObject var island: IslandController
    @ObservedObject var model: BarModel
    @ObservedObject private var spotify: SpotifySensor

    init(island: IslandController, model: BarModel) {
        self.island = island
        self.model = model
        spotify = island.spotify
    }


    var body: some View {
        HStack(spacing: 0) {
            clock.frame(width: IslandMetrics.wing)
            Color.clear.frame(width: island.notch.width)
            trailing
                .padding(.horizontal, Theme.Island.padding)
                .frame(width: island.expanded ? IslandMetrics.toastWing : IslandMetrics.wing, alignment: island.expanded ? .leading : .center)
                .clipped()
        }
        .frame(height: island.notch.height)
        .background(UnevenRoundedRectangle(
            bottomLeadingRadius: Theme.Island.radius, bottomTrailingRadius: Theme.Island.radius, style: .continuous
        ).fill(.black))
        .contentShape(Rectangle())
        .onTapGesture { if let event = island.shown { island.activate(event) } }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var clock: some View {
        Text(Self.time(island.now))
            .font(Font(Theme.font(Theme.Family.numbers, size: Theme.Island.timeSize, weight: .medium)))
            .foregroundStyle(model.color("on_surface"))
            .monospacedDigit()
    }

    @ViewBuilder
    private var trailing: some View {
        switch island.expanded ? island.shown : nil {
        case .notice(let notice)?:
            HStack(spacing: Theme.Spacing.small) {
                Image(nsImage: Self.icon(notice.app)).resizable().frame(width: Theme.Island.iconSize, height: Theme.Island.iconSize)
                line(notice.title, role: "on_surface", weight: .medium).fixedSize()
                if let detail = notice.detail { line(detail, role: "primary", size: Theme.Island.smallSize).fixedSize() }
                line(notice.body, role: "on_surface_variant")
            }
            .transition(.opacity)
        case .nowPlaying(let track)?:
            HStack(spacing: Theme.Spacing.small) {
                artwork(for: track)
                line(track.title, role: "on_surface", weight: .medium)
                line(track.artist, role: "on_surface_variant")
                LevelMeter(color: model.color("primary"))
            }
            .transition(.opacity)
        case nil:
            HStack(spacing: Theme.Spacing.small) {
                if case .playing = spotify.state { LevelMeter(color: model.color("primary")) }
                Text(island.meeting ?? Self.day(island.now))
                    .font(Font(Theme.text(Theme.Island.textSize, weight: island.meeting == nil ? .regular : .medium)))
                    .foregroundStyle(model.color(island.meeting == nil ? "on_surface_variant" : "primary"))
                    .lineLimit(1)
            }
            .transition(.opacity)
        }
    }

    private func artwork(for track: SpotifyTrack) -> some View {
        Group {
            if let artwork = spotify.artwork, spotify.state.track?.id == track.id {
                Image(nsImage: artwork).resizable()
            } else {
                Text(Glyph.musicNote).font(Font(Theme.icon(Theme.Island.iconSize * 0.8))).foregroundStyle(model.color("primary"))
            }
        }
        .frame(width: Theme.Island.iconSize, height: Theme.Island.iconSize)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func line(_ text: String, role: String, size: CGFloat = Theme.Island.textSize, weight: NSFont.Weight = .regular) -> some View {
        Text(text).font(Font(Theme.text(size, weight: weight))).foregroundStyle(model.color(role)).lineLimit(1)
    }

    private static func time(_ date: Date) -> String {
        "\(ClockView.twoDigits(.hour, of: date)):\(ClockView.twoDigits(.minute, of: date))"
    }

    private static func day(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day())
    }

    private static func icon(_ bundleID: String) -> NSImage {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return NSImage(systemSymbolName: "bell.fill", accessibilityDescription: nil) ?? NSImage()
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

private struct LevelMeter: View {
    let color: Color

    var body: some View {
        TimelineView(.periodic(from: .now, by: Theme.Island.meterStep)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate / Theme.Island.meterStep
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<3) { bar in
                    Capsule()
                        .fill(color)
                        .frame(width: 3, height: 4 + 8 * abs(sin(phase * 0.9 + Double(bar) * 1.3)))
                }
            }
            .frame(height: 12, alignment: .bottom)
            .animation(.easeInOut(duration: Theme.Island.meterStep), value: phase)
        }
    }
}
