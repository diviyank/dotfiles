import ShellCore
import SwiftUI

struct MediaCard: View {
    @ObservedObject var model: BarModel
    @ObservedObject var spotify: SpotifySensor

    var body: some View {
        DashboardCard(model: model) {
            HStack(spacing: Theme.Spacing.medium) {
                art
                details
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var art: some View {
        RoundedRectangle(cornerRadius: Theme.Rounding.large)
            .fill(model.color("surface_container_highest"))
            .overlay {
                if let artwork = spotify.artwork {
                    Image(nsImage: artwork).resizable()
                } else {
                    Text(Glyph.musicNote)
                        .font(Font(Theme.icon(Theme.IconSize.large)))
                        .foregroundStyle(model.color("on_surface_variant"))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Rounding.large))
            .frame(width: Theme.Dashboard.artSize, height: Theme.Dashboard.artSize)
    }

    @ViewBuilder
    private var details: some View {
        switch spotify.state {
        case .notRunning:
            caption("Nothing playing")
        case .denied:
            caption("Allow Spotify control in Privacy & Security")
        case .playing(let track), .paused(let track):
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(Font(Theme.text(Theme.Dashboard.bodyText, weight: .medium)))
                    .foregroundStyle(model.color("on_surface"))
                    .lineLimit(1)
                caption(track.artist)
                progress(track)
                controls(isPlaying: track.isPlaying)
            }
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(Font(Theme.text(Theme.Dashboard.tinyText)))
            .foregroundStyle(model.color("on_surface_variant"))
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func progress(_ track: SpotifyTrack) -> some View {
        Group {
            if track.isPlaying {
                TimelineView(.periodic(from: spotify.measuredAt, by: 1)) { context in
                    progressBar(track, elapsed: context.date.timeIntervalSince(spotify.measuredAt))
                }
            } else {
                progressBar(track, elapsed: 0)
            }
        }
        .padding(.vertical, Theme.Spacing.extraSmall)
    }

    private func progressBar(_ track: SpotifyTrack, elapsed: TimeInterval) -> some View {
        let fraction = track.duration > 0 ? min((track.position + elapsed) / track.duration, 1) : 0
        return Capsule()
            .fill(model.color("surface_container_highest"))
            .frame(height: 4)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule().fill(model.color("primary")).frame(width: proxy.size.width * fraction)
                }
            }
    }

    private func controls(isPlaying: Bool) -> some View {
        HStack(spacing: Theme.Spacing.medium) {
            control(Glyph.skipPrevious, role: "on_surface_variant", action: spotify.previous)
            control(isPlaying ? Glyph.pauseCircle : Glyph.playCircle, role: "primary", action: spotify.playPause)
            control(Glyph.skipNext, role: "on_surface_variant", action: spotify.next)
        }
    }

    private func control(_ glyph: String, role: String, action: @escaping () -> Void) -> some View {
        Text(glyph)
            .font(Font(Theme.icon(Theme.Dashboard.controlSize)))
            .foregroundStyle(model.color(role))
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
    }
}
