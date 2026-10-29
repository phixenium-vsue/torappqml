import QtQuick 2.12
import Lomiri.Components 1.3
import "../components"
import "../theme"
import "../state"

Item {
    id: page

    signal back()

    property string note: ""

    AppBar {
        id: appbar
        anchors { left: parent.left; right: parent.right; top: parent.top }
        canGoBack: true
        title: i18n.tr("Свои мосты")
        onBackClicked: page.back()
    }

    Label {
        id: hint
        anchors {
            left: parent.left
            right: parent.right
            top: appbar.bottom
            leftMargin: units.gu(1.6)
            rightMargin: units.gu(1.6)
            topMargin: units.gu(1.6)
        }
        text: i18n.tr("Вставьте адреса мостов — по одному в строке. Сохранённые мосты появятся в выборе мостов.")
        color: Theme.textDim
        fontSize: "small"
        wrapMode: Text.WordWrap
    }

    Rectangle {
        id: box
        anchors {
            left: parent.left
            right: parent.right
            top: hint.bottom
            bottom: bottomCol.top
            leftMargin: units.gu(1.6)
            rightMargin: units.gu(1.6)
            topMargin: units.gu(1.6)
            bottomMargin: units.gu(1.6)
        }
        color: Theme.bgCard
        radius: Theme.radiusCard
        border.width: 1
        border.color: Theme.stroke

        Flickable {
            anchors.fill: parent
            anchors.margins: units.gu(1.4)
            clip: true
            contentWidth: width
            contentHeight: te.contentHeight

            TextEdit {
                id: te
                width: parent.width
                text: App.customBridges
                color: Theme.text
                wrapMode: TextEdit.WrapAnywhere
                font.pixelSize: units.gu(1.8)
                font.family: "Ubuntu Mono"
                selectByMouse: true

                Label {
                    anchors.fill: parent
                    visible: te.text === ""
                    text: i18n.tr("obfs4 1.2.3.4:443 ...")
                    color: Theme.textDim2
                    font.pixelSize: units.gu(1.8)
                    font.family: "Ubuntu Mono"
                    wrapMode: Text.WrapAnywhere
                }
            }
        }
    }

    Column {
        id: bottomCol
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: units.gu(1.6)
            rightMargin: units.gu(1.6)
            bottomMargin: units.gu(1.6)
        }
        spacing: units.gu(1)

        Label {
            width: parent.width
            text: page.note
            color: Theme.green
            fontSize: "x-small"
            wrapMode: Text.WordWrap
            visible: page.note !== ""
        }

        Row {
            width: parent.width
            spacing: units.gu(1.2)

            ButtonPrimary {
                width: (parent.width - units.gu(1.2)) / 2
                text: i18n.tr("Привести к виду")
                variant: "flat"
                onClicked: {
                    App.normalizeBridges(te.text, function (count, text) {
                        te.text = text
                        page.note = count > 0
                            ? i18n.tr("Распознано мостов: ") + count
                            : i18n.tr("Валидных мостов не найдено")
                    })
                }
            }
            ButtonPrimary {
                id: saveBtn
                width: (parent.width - units.gu(1.2)) / 2
                text: i18n.tr("Сохранить")
                iconName: "list"
                onClicked: {
                    App.saveCustomBridges(te.text)
                    page.back()
                }
            }
        }
    }
}
