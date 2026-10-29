import QtQuick 2.12
import Lomiri.Components 1.3
import "../theme"

Item {
    id: root

    property string icon: ""
    property string label: ""
    property string value: ""
    property string trailingType: "none"   // none | dottext | flag
    property string trailingText: ""
    property color trailingColor: Theme.green
    property string iso: ""
    property bool busy: false
    property real pad: units.gu(1.2)
    property real valueRowHeight: units.gu(3.4)
    property bool centerValue: false

    Column {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            topMargin: root.pad
            leftMargin: root.pad
            rightMargin: root.pad
        }
        spacing: units.gu(0.5)

        Row {
            spacing: units.gu(0.6)

            AppIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.icon
                color: Theme.teal
                size: units.gu(2)
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: root.label
                color: Theme.textDim
                fontSize: "x-small"
            }
        }

        Item {
            id: valueRow
            width: parent.width
            height: root.valueRowHeight

            Row {
                id: valueInner
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: root.centerValue ? parent.horizontalCenter : undefined
                anchors.left: root.centerValue ? undefined : parent.left
                spacing: units.gu(0.7)
                width: root.centerValue ? implicitWidth : parent.width

                FlagCountry {
                    visible: root.trailingType === "flag"
                    anchors.verticalCenter: parent.verticalCenter
                    iso: root.iso
                }
                Label {
                    width: root.centerValue
                           ? implicitWidth
                           : parent.width - (root.trailingType === "flag" ? units.gu(4) : 0)
                             - (root.busy ? units.gu(2.6) : 0)
                    text: root.value
                    color: Theme.text
                    fontSize: "small"
                    font.bold: true
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                }
                Spinner {
                    visible: root.busy
                    anchors.verticalCenter: parent.verticalCenter
                    width: units.gu(1.6)
                    height: units.gu(1.6)
                    color: Theme.teal
                    thickness: 2
                }
            }
        }

        Row {
            visible: root.trailingType === "dottext"
            spacing: units.gu(0.6)
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: units.gu(0.9); height: width; radius: width / 2
                color: root.trailingColor
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: root.trailingText
                color: root.trailingColor
                fontSize: "x-small"
            }
        }
    }
}
