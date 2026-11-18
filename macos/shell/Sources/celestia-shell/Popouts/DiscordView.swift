import AppKit
import ShellCore
import SwiftUI

struct DiscordPopout: View {
    @ObservedObject var model: BarModel
    let popouts: PopoutPanel
    @ObservedObject private var discord = DiscordSensor.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            model.title("Discord")
            if discord.notes.isEmpty {
                model.detail("No unread notifications")
            }
            ForEach(discord.notes) { note in
                VStack(alignment: .leading, spacing: 0) {
                    model.detail(note.sender, role: "on_surface").lineLimit(1)
                    if let place = note.place {
                        Text(place)
                            .font(Font(Theme.text(Theme.Dashboard.tinyText)))
                            .foregroundStyle(model.color("primary"))
                            .lineLimit(1)
                    }
                    model.detail(note.body).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { open(note) }
            }
        }
        .onAppear { discord.refresh() }
        .onChange(of: discord.notes) { popouts.refit() }
    }

    private func open(_ note: DiscordNote) {
        guard let link = note.link else { return }
        NSWorkspace.shared.open(link)
        popouts.hide()
    }
}
