import QtQuick 2.9
import QtQuick.Layouts 1.1
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3
import "../components"

ListItem {
    id: deviceListItem
    height: layout.height

    color: mainLayout.darkmode ? "#202020" : "white"

    property var target
    property var thisDevice: target.pushkey === pushClient.pushtoken

    onClicked: {
        currentTarget = target
        PopupUtils.open(targetInfoDialog)
    }

    ListItemLayout {
        id: layout
        width: parent.width
        title.text: (thisDevice ? (" (" + i18n.tr("This device") + ") ") : "") + target.app_display_name
        title.font.bold: thisDevice
        subtitle.text: (target.device_display_name || device.device_id)

        Icon {
            width: units.gu(4)
            height: units.gu(4)
            SlotsLayout.position: SlotsLayout.Leading
            name: "phone-smartphone-symbolic"
        }
    }


}
