import QtQuick 2.9
import QtQuick.Layouts 1.1
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3
import "../components"

StyledPage {
    anchors.fill: parent
    id: phoneSettingsPage

    property var client_secret
    property var sid


    Component.onCompleted: sync ()


    function sync () {
        update()

        // Check for updates online
        matrix.get( "/client/r0/account/3pid", null, function ( res ) {
            storage.transaction ( "DELETE FROM ThirdPIDs")
            if ( res.threepids.length === 0 ) return
            for ( var i = 0; i < res.threepids.length; i++ ) {
                storage.query ( "INSERT OR IGNORE INTO ThirdPIDs VALUES( ?, ? )", [ res.threepids[i].medium, res.threepids[i].address ])
            }
            update()
        })
    }


    function update () {
        // Get all phone numbers
        storage.transaction ( "SELECT address FROM ThirdPIDs WHERE medium='msisdn'", function (response) {
            model.clear()
            for ( var i = 0; i < response.rows.length; i++ ) {
                model.append({
                    name: response.rows[ i ].address
                })
            }
        })
    }

    header: PageHeader {
        id: header
        title:  i18n.tr('Connected phone numbers')

        trailingActionBar {
            numberOfSlots: 1
            actions: [
            Action {
                iconName: "add"
                text: i18n.tr("Add phone number")
                onTriggered: PopupUtils.open( addPhoneDialog )
            }
            ]
        }
    }

    AddPhoneDialog { id: addPhoneDialog }
    EnterSMSTokenDialog { id: enterSMSToken }

    Label {
        anchors.centerIn: addressesList
        text: i18n.tr("No phone numbers connected")
        visible: model.count === 0
    }

    ListView {
        id: addressesList
        anchors.top: header.bottom
        width: parent.width
        height: parent.height - header.height
        delegate: PhoneListItem { }
        model: ListModel { id: model }
        z: -1
    }

}
