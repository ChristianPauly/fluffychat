import QtQuick 2.9
import QtQuick.Layouts 1.1
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3
import "../components"
import "../scripts/MatrixNames.js" as MatrixNames
import "../scripts/UserPageActions.js" as PageActions

Page {
    id: userSettingsPage
    property var matrix_id: ""
    property var displayname: ""

    Rectangle {
        id: background
        anchors.fill: parent
        color: theme.palette.normal.background
    }

    header: PageHeader {
        id: userHeader
        title: displayname

        trailingActionBar {
            actions: [
            Action {
                iconName: "mail-forward"
                onTriggered: contentHub.shareTextIntern ( matrix_id )
            },
            Action {
                iconName: "edit-copy"
                onTriggered: {
                    contentHub.toClipboard ( matrix_id )
                    toast.show( i18n.tr("Username copied to the clipboard") )
                }
            }
            ]
        }
    }

    Component.onCompleted: PageActions.init ()


    ScrollView {
        id: scrollView
        width: parent.width
        height: parent.height - userHeader.height
        anchors.top: userHeader.bottom
        contentItem: Column {
            width: userSettingsPage.width

            Rectangle {
                width: parent.width
                height: units.gu(2)
                color: "#00000000"
            }

            ProfileRow {
                id: profileRow
                matrixid: activeUser
                displayname: userSettingsPage.displayname
            }

            ListSeperator {
                text: matrix_id !== matrix.matrixid ? i18n.tr("Chats with this user:") : i18n.tr("This is you.")
            }

            Column {
                id: chatListView
                width: parent.width
                visible: matrix_id !== matrix.matrixid
            }

            ListItem {
                id: startNewChatButton
                height: layout.height
                color: Qt.rgba(0,0,0,0)
                visible: matrix_id !== matrix.matrixid
                onClicked: PageActions.startPrivateChat ()

                ListItemLayout {
                    id: layout
                    title.text: i18n.tr("Start new chat")
                    Icon {
                        name: "message-new"
                        width: units.gu(4)
                        height: units.gu(4)
                        SlotsLayout.position: SlotsLayout.Leading
                    }
                }
            }

        }
    }
}
