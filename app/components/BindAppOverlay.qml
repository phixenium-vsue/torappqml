import QtQuick 2.12
import Lomiri.Components 1.3
import "../theme"

Rectangle {
    id: root
    anchors.fill: parent
    color: "#cc000000"
    visible: false

    property string appKey: ""
    property string appName: ""
    property var candidates: []
    property var binding: null

    signal bindRequested(string pkg, string app)
    signal openStoreRequested()
    signal closed()

    function open(key, name, res) {
        appKey = key
        appName = name
        candidates = (res && res.candidates) ? res.candidates : []
        binding = (res && res.binding) ? res.binding : null
        visible = true
    }
    function close() {
        visible = false
        closed()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: parent.width - units.gu(6)
        height: panel.height + units.gu(4)
        radius: Theme.radiusCard
        color: Theme.bgCard
        border.width: 1
        border.color: Theme.stroke

        MouseArea { anchors.fill: parent }

        Column {
            id: panel
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: units.gu(2)
                rightMargin: units.gu(2)
            }
            spacing: units.gu(1.4)

            Label {
                width: parent.width
                text: (root.appName !== "" ? root.appName : i18n.tr("Приложение"))
                color: Theme.text
                fontSize: "large"
                font.bold: true
            }

            Label {
                width: parent.width
                visible: root.candidates.length === 0
                text: root.appKey === "openstore"
                      ? i18n.tr("OpenStore не найден на устройстве.")
                      : i18n.tr("Приложение не найдено на устройстве. Установите его из OpenStore, затем вернитесь и привяжите.")
                color: Theme.textDim
                fontSize: "small"
                wrapMode: Text.WordWrap
            }
            Label {
                width: parent.width
                visible: root.candidates.length > 0
                text: root.candidates.length === 1
                      ? i18n.tr("Найдено приложение. Привязать его?")
                      : i18n.tr("Выберите приложение:")
                color: Theme.textDim
                fontSize: "small"
                wrapMode: Text.WordWrap
            }

            Row {
                width: parent.width
                spacing: units.gu(1.2)
                visible: root.candidates.length === 1

                Image {
                    width: units.gu(4); height: width
                    source: root.candidates.length === 1 && root.candidates[0].icon
                            ? "file://" + root.candidates[0].icon : ""
                    fillMode: Image.PreserveAspectFit
                }
                Column {
                    width: parent.width - units.gu(5.2)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: units.gu(0.1)
                    Label {
                        width: parent.width
                        text: root.candidates.length === 1 ? root.candidates[0].name : ""
                        color: Theme.text; fontSize: "small"; elide: Text.ElideRight
                    }
                    Label {
                        width: parent.width
                        text: root.candidates.length === 1 ? root.candidates[0].pkg : ""
                        color: Theme.textDim; fontSize: "x-small"; elide: Text.ElideRight
                    }
                }
            }

            Column {
                width: parent.width
                spacing: units.gu(0.8)
                visible: root.candidates.length > 1

                Repeater {
                    model: root.candidates
                    delegate: Rectangle {
                        width: panel.width
                        height: units.gu(4.2)
                        radius: units.gu(0.8)
                        color: Theme.bgCard2
                        border.width: 1
                        border.color: Theme.stroke

                        Row {
                            anchors {
                                fill: parent
                                leftMargin: units.gu(1)
                                rightMargin: units.gu(1)
                            }
                            spacing: units.gu(1)

                            Image {
                                width: units.gu(3); height: width
                                anchors.verticalCenter: parent.verticalCenter
                                source: modelData.icon ? "file://" + modelData.icon : ""
                                fillMode: Image.PreserveAspectFit
                            }
                            Column {
                                width: parent.width - units.gu(4.2)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: units.gu(0.1)
                                Label {
                                    width: parent.width
                                    text: modelData.name
                                    color: Theme.text; fontSize: "small"; elide: Text.ElideRight
                                }
                                Label {
                                    width: parent.width
                                    text: modelData.pkg
                                    color: Theme.textDim; fontSize: "x-small"; elide: Text.ElideRight
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.bindRequested(modelData.pkg, modelData.app)
                        }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: units.gu(1.2)
                visible: root.candidates.length === 1

                ButtonPrimary {
                    width: (parent.width - units.gu(1.2)) / 2
                    text: i18n.tr("Отмена")
                    variant: "flat"
                    onClicked: root.close()
                }
                ButtonPrimary {
                    width: (parent.width - units.gu(1.2)) / 2
                    text: i18n.tr("Привязать")
                    onClicked: root.bindRequested(root.candidates[0].pkg, root.candidates[0].app)
                }
            }

            Row {
                width: parent.width
                spacing: units.gu(1.2)
                visible: root.candidates.length === 0

                ButtonPrimary {
                    width: (parent.width - units.gu(1.2)) / 2
                    text: i18n.tr("Отмена")
                    variant: "flat"
                    onClicked: root.close()
                }
                ButtonPrimary {
                    width: (parent.width - units.gu(1.2)) / 2
                    text: i18n.tr("Открыть OpenStore")
                    visible: root.appKey !== "openstore"
                    onClicked: root.openStoreRequested()
                }
            }

            ButtonPrimary {
                width: parent.width
                text: i18n.tr("Закрыть")
                variant: "flat"
                visible: root.candidates.length > 1
                onClicked: root.close()
            }
        }
    }
}
