import QtQuick 2.12
import Lomiri.Components 1.3
import QtGraphicalEffects 1.0
import "../theme"

Item {
    id: root

    property string appName: ""
    property string iconSource: ""
    property bool installed: true
    property bool proxied: false
    property bool tileEnabled: true
    property bool bound: true
    property string state: "ready"

    signal toggled()
    signal infoRequested()
    signal bindRequested()

    readonly property bool usable: installed && tileEnabled
    // Не привязано (первый раз) или приложение пропало после обновления — контур.
    readonly property bool needsBind: !bound || state === "missing"
    readonly property real switchW: units.gu(4.2)
    readonly property real gap: units.gu(0.8)

    implicitHeight: content.height
    implicitWidth: units.gu(11)

    Column {
        id: content
        width: parent.width
        spacing: units.gu(0.5)

        Row {
            width: parent.width
            spacing: root.gap

            Rectangle {
                id: box
                width: root.needsBind ? parent.width
                                      : parent.width - root.switchW - root.gap
                height: width
                radius: units.gu(1.2)
                color: root.needsBind ? "#12ffffff" : Theme.bgCard2
                border.width: root.needsBind ? 1 : 1
                border.color: root.needsBind ? "#26ffffff"
                                             : (root.proxied ? Theme.accent : Theme.stroke)
                opacity: root.needsBind ? 1.0 : (root.usable ? 1.0 : 0.5)

                layer.enabled: root.needsBind
                layer.effect: Desaturate { desaturation: 1.0 }

                Behavior on border.color { ColorAnimation { duration: 120 } }

                Image {
                    id: img
                    anchors.fill: parent
                    anchors.margins: units.gu(0.7)
                    source: (root.installed && root.iconSource !== "") ? root.iconSource : ""
                    fillMode: Image.PreserveAspectFit
                    opacity: root.needsBind ? 0.35 : 1.0
                    visible: status === Image.Ready
                    layer.enabled: visible
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: img.width
                            height: img.height
                            radius: img.width * 0.22
                        }
                    }
                }

                Label {
                    anchors.centerIn: parent
                    visible: !img.visible
                    text: root.installed ? (root.needsBind ? "+" : "?") : "∅"
                    color: Theme.textDim2
                    fontSize: "large"
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (root.needsBind)
                            root.bindRequested()
                        else
                            root.infoRequested()
                    }
                }
            }

            Rectangle {
                id: sw
                visible: !root.needsBind
                anchors.verticalCenter: box.verticalCenter
                width: root.switchW
                height: units.gu(2.3)
                radius: height / 2
                color: root.proxied ? Theme.accent : Theme.bgCard2
                border.width: 1
                border.color: root.proxied ? Theme.accent : Theme.stroke2

                Behavior on color { ColorAnimation { duration: 120 } }

                Rectangle {
                    width: units.gu(1.5); height: width; radius: width / 2
                    color: "#ffffff"
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.proxied ? parent.width - width - units.gu(0.25)
                                    : units.gu(0.25)
                    Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.InOutQuad } }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.usable
                    onClicked: root.toggled()
                }
            }
        }

        Label {
            id: nameLabel
            width: parent.width
            text: root.appName
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            color: root.needsBind ? Theme.textDim2 : Theme.text
            fontSize: "x-small"
        }

        Label {
            id: hintLabel
            width: parent.width
            visible: root.needsBind
            text: !root.installed ? i18n.tr("не установлено")
                                  : (root.bound ? i18n.tr("перепривязать")
                                                : i18n.tr("нажмите, чтобы привязать"))
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            color: Theme.textDim2
            fontSize: "xx-small"
        }
    }
}
