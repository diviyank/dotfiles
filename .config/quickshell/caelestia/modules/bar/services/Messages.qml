pragma Singleton

import QtQuick
import Quickshell
import qs.services

Singleton {
    id: root

    readonly property int shown: 5

    readonly property var mail: newestFirst(app => app === "thunderbird").map(mailPreview)
    readonly property var discord: newestFirst(app => app === "discord").map(discordPreview)
    readonly property int mailCount: mail.reduce((sum, preview) => sum + preview.count, 0)
    readonly property int discordCount: discord.length

    readonly property var workspaces: ({
            mail: 7,
            discord: 6
        })

    function newestFirst(matchesApp: var): var {
        return Notifs.notClosed.filter(n => matchesApp(n.appName.toLowerCase())).sort((a, b) => b.time - a.time);
    }

    function plain(text: string): string {
        return text.replace(/[⁦-⁩]/g, "").replace(/\*\*|__|~~|`/g, "").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/&#39;|&apos;/g, "'").trim();
    }

    function mailPreview(notif: var): var {
        const firstLine = plain(notif.body).split("\n")[0];
        const separator = firstLine.search(/\s?:\s/);
        const countInSummary = notif.summary.match(/(\d+)\D*$/);
        return {
            notif,
            count: countInSummary ? parseInt(countInSummary[1]) : 1,
            title: separator > 0 ? firstLine.slice(0, separator).trim() : plain(notif.summary),
            place: "",
            text: separator > 0 ? firstLine.slice(separator).replace(/^\s?:\s/, "") : firstLine
        };
    }

    function discordPreview(notif: var): var {
        const title = plain(notif.summary);
        const placeMatch = title.match(/^(.*) \((.*)\)$/);
        return {
            notif,
            count: 1,
            title: placeMatch ? placeMatch[1] : title,
            place: placeMatch ? placeMatch[2].split(", ").join(" · ") : "",
            text: plain(notif.body).split("\n").join(" ")
        };
    }

    function focus(app: string): void {
        Hypr.focusWorkspace(workspaces[app]);
    }

    function open(app: string, preview: var): void {
        const notif = preview.notif;
        notif.actions.find(action => action.identifier === "default")?.invoke?.();
        focus(app);
        if (Notifs.list.includes(notif))
            notif.close();
    }

    function markRead(app: string): void {
        newestFirst(name => name === (app === "mail" ? "thunderbird" : app)).forEach(n => n.close());
    }

    Connections {
        target: Hypr

        function onActiveToplevelChanged(): void {
            const windowClass = Hypr.activeToplevel?.lastIpcObject?.class?.toLowerCase() ?? "";
            if (windowClass.includes("thunderbird"))
                root.markRead("mail");
            else if (windowClass === "discord")
                root.markRead("discord");
        }
    }
}
