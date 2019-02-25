import QtQuick 2.9
import QtQuick.Layouts 1.1
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3

Component {
    id: dialog

    Dialog {
        id: dialogue
        title: i18n.tr("Connect new phone number") + i18n.tr("...")
        Rectangle {
            height: units.gu(0.2)
            width: parent.width
            color: mainLayout.mainColor
        }
        Row {
            Button {
                width: units.gu(8)
                text: matrix.countryCode + " +%1".arg(matrix.countryTel)
                onClicked: dialogue.title = i18n.tr("Please log out to change your country")
            }
            TextField {
                id: addressTextField
                placeholderText: i18n.tr("Phone number...")
                Keys.onReturnPressed: okButton.clicked ()
                inputMethodHints: Qt.ImhDigitsOnly
                width: parent.width - units.gu(8)
                focus: true
            }
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
                id: okButton
                width: (parent.width - units.gu(1)) / 2
                text: i18n.tr("Connect")
                color: UbuntuColors.green
                enabled: addressTextField.displayText !== ""
                onClicked: {
                    var address = addressTextField.displayText
                    if ( address.charAt(0) === "0" ) address = address.replace( "0", matrix.countryTel )
                    PopupUtils.close(dialogue)
                    PopupUtils.open(enterSMSToken)
                    client_secret = "SECRET:" + new Date().getTime()
                    var _phoneSettingsPage = phoneSettingsPage

                    var callback = function ( response ) {
                        if ( response.error ) return toast.show ( response.error )
                        if ( response.sid ) {
                            _phoneSettingsPage.sid = response.sid
                        }
                    }

                    // Verify this address with this matrix id
                    matrix.post ( "/client/r0/account/3pid/msisdn/requestToken", {
                        client_secret: client_secret,
                        country: matrix.countryCode,
                        phone_number: address,
                        send_attempt: 1,
                        id_server: matrix.id_server
                    }, callback, callback)
                }
            }
        }
    }
}
