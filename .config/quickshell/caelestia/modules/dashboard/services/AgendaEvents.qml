pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

Singleton {
    id: root

    property bool configured: true
    property var events: []

    function apply(json: string): void {
        if (!json.trim())
            return;
        const result = JSON.parse(json);
        configured = result.configured;
        events = result.events;
    }

    FileView {
        blockLoading: true
        printErrors: false
        path: `${Paths.cache}/agenda.json`
        onLoaded: root.apply(text())
    }

    Process {
        id: fetcher

        command: ["/usr/bin/python3", Qt.resolvedUrl("../agenda.py").toString().replace("file://", "")]
        stdout: StdioCollector {
            onStreamFinished: root.apply(text)
        }
    }

    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: 5 * 60 * 1000
        onTriggered: fetcher.running = true
    }
}
