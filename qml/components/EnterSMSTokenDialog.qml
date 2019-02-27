import QtQuick 2.9
import QtQuick.Layouts 1.1
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3

Component {
    id: dialog

    Dialog {
        id: dialogue
        title: i18n.tr("Please enter the validation code")
        Rectangle {
            height: units.gu(0.2)
            width: parent.width
            color: mainLayout.mainColor
        }
        TextField {
            id: addressTextField
            placeholderText: i18n.tr("Validation code")
            focus: true
            inputMethodHints: Qt.ImhDigitsOnly
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
                text: i18n.tr("Connect")
                color: UbuntuColors.green
                enabled: addressTextField.displayText !== "" && sid !== null
                onClicked: {
                    var success_callback = function () {
                        PopupUtils.close(dialogue)
                        phoneSettingsPage.sync ()
                    }
                    var _page = phoneSettingsPage || passwordCreationPage
                    var _matrix = matrix
                    matrix.post ( "/identity/api/v1/validate/msisdn/submitToken", {
                        client_secret: client_secret,
                        sid: sid,
                        token: addressTextField.displayText
                    }, function () {
                        PopupUtils.close(dialogue)
                        var threePidCreds = {
                            client_secret: _page.client_secret,
                            sid: _page.sid,
                            id_server: matrix.id_server
                        }
                        _matrix.post ("/client/r0/account/3pid", {
                            bind: true,
                            threePidCreds: threePidCreds
                        }, _page.sync )
                    }, function ( error ) {
                        dialogue.title = error.error
                    } )
                }
            }
        }
    }
}
