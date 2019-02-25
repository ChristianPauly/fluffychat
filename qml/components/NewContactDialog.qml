import QtQuick 2.9
import QtQuick.Layouts 1.1
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3

Component {
    id: dialog

    Dialog {
        id: dialogue
        title: i18n.tr("New single chat")
        Rectangle {
            height: units.gu(0.2)
            width: parent.width
            color: mainLayout.mainColor
        }
        Label {
            text: i18n.tr("What is your friends username?")
            width: parent.width
            wrapMode: Text.Wrap
        }
        Label {
            text: i18n.tr("(Your username is: <b>%1</b>)").arg(matrix.matrixid)
            width: parent.width
            wrapMode: Text.Wrap
            textSize: Label.Small
        }
        TextField {
            id: contactTextField
            text: newContactMatrixID !== undefined ? newContactMatrixID : ""
            placeholderText: i18n.tr("@yourfriend:" + matrix.server)
            focus: true
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
                text: i18n.tr("Continue")
                enabled: contactTextField.displayText !== ""
                color: UbuntuColors.green
                onClicked: {

                    matrix.waitForSync ()
                    var data = {
                        "invite": [ contactTextField.displayText ],
                        "is_direct": true,
                        "preset": "private_chat"
                    }
                    if ( success_callback === undefined ) var success_callback = null
                    matrix.post( "/client/r0/createRoom", data, success_callback )

                    PopupUtils.close(dialogue)
                }
            }
        }
    }
}
