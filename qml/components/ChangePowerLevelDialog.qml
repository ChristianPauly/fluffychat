import QtQuick 2.9
import QtQuick.Layouts 1.1
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3

Component {
    id: dialog

    Dialog {
        id: dialogue
        title: powerLevelDescription
        Rectangle {
            height: units.gu(0.2)
            width: parent.width
            color: mainLayout.mainColor
        }
        Column {
            SettingsListItem {
                name: i18n.tr("Admins")
                icon: "view-collapse"
                onClicked: {
                    var data = {}
                    if ( activePowerLevel.indexOf("m.room") !== -1 ) {
                        data["events"] = {}
                        data["events"][activePowerLevel] = 100
                    }
                    else data[activePowerLevel] = 100
                    matrix.put("/client/r0/rooms/" + activeChat + "/state/m.room.power_levels/", data )
                    PopupUtils.close(dialogue)
                }
            }
            SettingsListItem {
                name: i18n.tr("Moderators")
                icon: "view-collapse"
                onClicked: {
                    var data = {}
                    if ( activePowerLevel.indexOf("m.room") !== -1 ) {
                        data["events"] = {}
                        data["events"][activePowerLevel] = 50
                    }
                    else data[activePowerLevel] = 50
                    matrix.put("/client/r0/rooms/" + activeChat + "/state/m.room.power_levels/", data )
                    PopupUtils.close(dialogue)
                }
            }
            SettingsListItem {
                name: i18n.tr("Members")
                icon: "view-collapse"
                onClicked: {
                    var data = {}
                    if ( activePowerLevel.indexOf("m.room") !== -1 ) {
                        data["events"] = {}
                        data["events"][activePowerLevel] = 0
                    }
                    else data[activePowerLevel] = 0
                    matrix.put("/client/r0/rooms/" + activeChat + "/state/m.room.power_levels/", data )
                    PopupUtils.close(dialogue)
                }
            }
        }

        Button {
            width: (parent.width - units.gu(1)) / 2
            text: i18n.tr("Close")
            onClicked: PopupUtils.close(dialogue)
        }
    }
}
