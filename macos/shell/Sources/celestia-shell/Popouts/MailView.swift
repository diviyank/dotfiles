import AppKit
import ShellCore
import SwiftUI

struct MailPopout: View {
    @ObservedObject var model: BarModel
    let popouts: PopoutPanel
    @ObservedObject private var mail = MailSensor.shared
    @ObservedObject private var badges = BadgeSensor.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            HStack {
                model.title("Mail")
                Spacer()
                if let count = badges.mail { model.number("\(count) unread") }
            }
            switch mail.unread {
            case nil: model.detail("Loading…")
            case let unread? where unread.isEmpty: model.detail("Nothing new")
            case let unread?:
                ForEach(unread, id: \.self) { message in
                    VStack(alignment: .leading, spacing: 0) {
                        model.detail(message.sender, role: "on_surface").lineLimit(1)
                        model.detail(message.subject).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { open(message) }
                }
            }
        }
        .onAppear { mail.refresh() }
        .onChange(of: mail.unread) { popouts.refit() }
    }

    private func open(_ message: MailSummary) {
        guard let url = mailMessageURL(message.messageID) else { return }
        NSWorkspace.shared.open(url)
        popouts.hide()
    }
}
