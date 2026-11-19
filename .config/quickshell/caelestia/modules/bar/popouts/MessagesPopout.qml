pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.bar.services

ColumnLayout {
    id: root

    required property PopoutState popouts
    required property string app
    required property string title
    required property var previews
    required property string countLabel

    spacing: Tokens.spacing.small

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.large

        StyledText {
            Layout.fillWidth: true
            text: root.title
            font: Tokens.font.title.small
        }

        StyledText {
            text: root.countLabel
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.medium
        }
    }

    Repeater {
        model: root.previews.slice(0, Messages.shown)

        Item {
            id: row

            required property var modelData

            Layout.fillWidth: true
            Layout.preferredWidth: 300
            implicitHeight: rowLayout.implicitHeight + Tokens.padding.small * 2

            StateLayer {
                radius: Tokens.rounding.small
                color: Colours.palette.m3primary
                onClicked: {
                    root.popouts.hasCurrent = false;
                    Messages.open(root.app, row.modelData);
                }
            }

            ColumnLayout {
                id: rowLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.small
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: row.modelData.title
                    elide: Text.ElideRight
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.body.builders.small.weight(Font.Medium).build()
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: row.modelData.place
                    elide: Text.ElideRight
                    color: Colours.palette.m3primary
                    font: Tokens.font.label.small
                }

                StyledText {
                    Layout.fillWidth: true
                    text: row.modelData.text
                    elide: Text.ElideRight
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                }
            }
        }
    }
}
