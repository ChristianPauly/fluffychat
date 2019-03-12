import QtQuick 2.9
import QtQuick.Layouts 1.1
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3

Component {
    id: dialog

    Dialog {
        id: dialogue
        title: i18n.tr("Log out")

        Rectangle {
            height: icon.height
            color: "transparent"
            Icon {
                id: icon
                width: parent.width / 2
                height: width
                anchors.horizontalCenter: parent.horizontalCenter
                name: "system-shutdown"
            }
        }
        Label {
            text: i18n.tr("Are you sure you want to log out?")
            color: UbuntuColors.red
            width: parent.width
            wrapMode: Text.Wrap
        }
        Row {
            width: parent.width
            spacing: units.gu(1)
            Button {
                width: (parent.width - units.gu(1)) / 2
                text: i18n.tr("Cancel")
                onClicked: PopupUtils.close(dialogue)
            }
            Button {
                width: (parent.width - units.gu(1)) / 2
                text: i18n.tr("Log out")
                color: UbuntuColors.red
                onClicked: {
                    PopupUtils.close(dialogue)
                    bottomEdgePageStack.pop ()
                    matrix.logout ()
                }
            }
        }
    }
}
