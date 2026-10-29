import QtQuick 2.12
import Lomiri.Components 1.3
import "../components"
import "../theme"
import "../state"

Item {
    id: page

    signal back()

    function colorFor(kind) {
        switch (kind) {
        case "ok":   return Theme.green
        case "warn": return Theme.yellow
        case "info": return Theme.text
        default:     return Theme.textDim
        }
    }

    AppBar {
        id: appbar
        anchors { left: parent.left; right: parent.right; top: parent.top }
        canGoBack: true
        title: i18n.tr("Журнал")
        rightText: i18n.tr("Очистить")
        onBackClicked: page.back()
        onRightClicked: App.clearLog()
    }

    Flickable {
        id: flick
        anchors {
            left: parent.left
            right: parent.right
            top: appbar.bottom
            bottom: parent.bottom
        }
        contentHeight: col.height + units.gu(3)
        clip: true

        onContentHeightChanged: contentY = Math.max(0, contentHeight - height)
        onHeightChanged: contentY = Math.max(0, contentHeight - height)

        Column {
            id: col
            x: units.gu(1.6)
            y: units.gu(1.6)
            width: flick.width - units.gu(3.2)
            spacing: units.gu(0.7)

            Repeater {
                model: App.logLines
                delegate: Item {
                    width: col.width
                    height: Math.max(logTime.height, logText.height)

                    Label {
                        id: logTime
                        anchors { left: parent.left; top: parent.top }
                        width: units.gu(7)
                        text: modelData.time || ""
                        color: Theme.textDim2
                        font.pixelSize: units.gu(1.6)
                        font.family: "Ubuntu Mono"
                    }
                    Label {
                        id: logText
                        anchors { left: logTime.right; right: parent.right; top: parent.top }
                        text: modelData.text || ""
                        color: page.colorFor(modelData.kind)
                        font.pixelSize: units.gu(1.6)
                        font.family: "Ubuntu Mono"
                        wrapMode: Text.WrapAnywhere
                    }
                }
            }

            Label {
                visible: App.logLines.length === 0
                text: i18n.tr("Журнал пуст")
                color: Theme.textDim2
                fontSize: "small"
            }
        }
    }
}
