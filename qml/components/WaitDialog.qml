import QtQuick 2.9
import QtQuick.Layouts 1.1
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3

Component {
    id: dialog

    Dialog {
        id: dialogue
        title: i18n.tr("Loading… Please wait.")
        Rectangle {
            height: units.gu(0.2)
            width: parent.width
            color: mainLayout.mainColor
        }
        Rectangle {
            height: units.gu(4)
            width: parent.width
            color: "#00000000"
            ActivityIndicator {
                running: true
                width: parent.height
                height: width
                anchors.centerIn: parent
            }
        }

        Connections {
            target: matrix
            onBlockUIRequestChanged: matrix.blockUIRequest === null ? PopupUtils.close ( dialogue ) : function(){}
        }

        Button {
            width: parent.width
            text: i18n.tr("Cancel process")
            onClicked: {
                if ( matrix.blockUIRequest !== null ) {
                    matrix.blockUIRequest.abort()
                    matrix.blockUIRequest = null
                }
                else PopupUtils.close(dialogue)
            }
        }
    }
}
