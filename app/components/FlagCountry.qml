import QtQuick 2.12
import Lomiri.Components 1.3

Item {
    id: root
    property string iso: ""

    readonly property string emoji: {
        if (!iso || iso.length !== 2) return ""
        var c = iso.toUpperCase()
        var a = 0x1F1E6 + (c.charCodeAt(0) - 65)
        var b = 0x1F1E6 + (c.charCodeAt(1) - 65)
        if (a < 0x1F1E6 || a > 0x1F1FF || b < 0x1F1E6 || b > 0x1F1FF) return ""
        return String.fromCodePoint(a) + String.fromCodePoint(b)
    }

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Label {
        id: label
        anchors.centerIn: parent
        text: root.emoji
        font.pixelSize: units.gu(2.6)
        visible: text !== ""
    }
}
