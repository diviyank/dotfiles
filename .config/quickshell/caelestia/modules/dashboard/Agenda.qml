pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.dashboard.services

Item {
    id: root

    readonly property int todayLimit: 4
    readonly property int tomorrowLimit: 3
    readonly property int dayLimit: 5

    property var selectedDay: null

    readonly property bool configured: AgendaEvents.configured
    readonly property var events: AgendaEvents.events

    readonly property date todayStart: new Date(Time.date.getFullYear(), Time.date.getMonth(), Time.date.getDate())
    readonly property date tomorrowStart: new Date(todayStart.getFullYear(), todayStart.getMonth(), todayStart.getDate() + 1)
    readonly property date tomorrowEnd: new Date(todayStart.getFullYear(), todayStart.getMonth(), todayStart.getDate() + 2)

    readonly property var todayEvents: eventsBetween(todayStart, tomorrowStart).filter(event => event.end > Time.date)
    readonly property var tomorrowEvents: eventsBetween(tomorrowStart, tomorrowEnd)
    readonly property var selectedDayEvents: selectedDay ? eventsBetween(selectedDay, new Date(selectedDay.getFullYear(), selectedDay.getMonth(), selectedDay.getDate() + 1)) : []

    function eventsBetween(start: date, end: date): var {
        return events.filter(event => event.start < end && event.end > start).sort((a, b) => a.allDay !== b.allDay ? (a.allDay ? -1 : 1) : a.start - b.start);
    }

    function timeRange(event: var): string {
        if (event.allDay)
            return qsTr("All day");
        return `${Qt.formatTime(new Date(event.start), "hh:mm")} – ${Qt.formatTime(new Date(event.end), "hh:mm")}`;
    }

    anchors.fill: parent
    implicitWidth: 260

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.small

        Section {
            visible: !!root.selectedDay
            title: root.selectedDay ? Qt.formatDate(root.selectedDay, "ddd d MMM") : ""
            events: root.selectedDayEvents
            limit: root.dayLimit
        }

        Section {
            visible: !root.selectedDay
            title: qsTr("Today")
            events: root.todayEvents
            limit: root.todayLimit
        }

        Section {
            visible: !root.selectedDay
            title: qsTr("Tomorrow")
            events: root.tomorrowEvents
            limit: root.tomorrowLimit
        }

        Item {
            Layout.fillHeight: true
        }
    }

    component Section: ColumnLayout {
        id: section

        required property string title
        required property var events
        required property int limit

        Layout.fillWidth: true
        spacing: Tokens.spacing.extraSmall

        StyledText {
            text: section.title.toUpperCase()
            color: Colours.palette.m3outline
            font: Tokens.font.body.builders.small.weight(Font.Medium).build()
        }

        Muted {
            visible: section.events.length === 0
            text: root.configured ? qsTr("No events") : qsTr("Add ICS URLs to ~/.local/share/caelestia/agenda-calendars")
        }

        Repeater {
            model: section.events.slice(0, section.limit)

            EventRow {}
        }

        Muted {
            visible: section.events.length > section.limit
            text: qsTr("+%1 more").arg(section.events.length - section.limit)
        }
    }

    component EventRow: Item {
        id: row

        required property var modelData
        readonly property bool joinable: !!modelData.url

        Layout.fillWidth: true
        implicitHeight: rowLayout.implicitHeight + Tokens.padding.extraSmall * 2

        StateLayer {
            disabled: !row.joinable
            radius: Tokens.rounding.small
            color: Colours.palette.m3primary
            onClicked: Qt.openUrlExternally(row.modelData.url)
        }

        RowLayout {
            id: rowLayout

            anchors.fill: parent
            anchors.margins: Tokens.padding.extraSmall
            spacing: Tokens.spacing.small

            StyledRect {
                Layout.fillHeight: true
                implicitWidth: 3
                radius: 2
                color: row.joinable ? Colours.palette.m3primary : Colours.palette.m3tertiary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        Layout.fillWidth: true
                        text: row.modelData.title
                        elide: Text.ElideRight
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.body.small
                    }

                    MaterialIcon {
                        visible: row.joinable
                        text: "videocam"
                        color: Colours.palette.m3primary
                    }
                }

                StyledText {
                    text: root.timeRange(row.modelData)
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }
            }
        }
    }

    component Muted: StyledText {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.label.small
    }
}
