import QtQuick 2.12
import QtQuick.Controls 2.12
import Lomiri.Components 1.3
import "theme"
import "pages"

MainView {
    id: app

    applicationName: "torapp.phablet"
    automaticOrientation: true
    backgroundColor: Theme.bgApp

    width: units.gu(48)
    height: units.gu(85)

    StackView {
        id: stack
        anchors.fill: parent
        initialItem: homeComp
    }

    Component {
        id: homeComp
        HomePage {
            onOpenJournal: stack.push(journalComp)
            onOpenCustomBridges: stack.push(customComp)
            onOpenSettings: stack.push(settingsComp)
        }
    }

    Component {
        id: journalComp
        JournalPage {
            onBack: stack.pop()
        }
    }

    Component {
        id: settingsComp
        SettingsPage {
            onBack: stack.pop()
        }
    }

    Component {
        id: customComp
        CustomBridgesPage {
            onBack: stack.pop()
        }
    }
}
