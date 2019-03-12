import QtQuick 2.9
import QtQuick.Layouts 1.1
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3
import "../components"
import "../scripts/MatrixNames.js" as MatrixNames
import "../scripts/ChatPageSettingsActions.js" as PageActions

Page {
    id: chatSettingsPage
    anchors.fill: parent

    property var membership: "unknown"
    property var max: 20
    property var position: 0
    property var blocked: false
    property var newContactMatrixID
    property var description: ""
    property var hasAvatar: false

    property var activeUserPower
    property var activeUserMembership

    // User permission
    property var power: 0
    property bool canChangeName: false
    property bool canKick: false
    property bool canBan: false
    property bool canInvite: true
    property bool canChangePermissions: false
    property bool canChangeAvatar: false

    property var memberCount: 0

    // To disable the background image on this page
    Rectangle {
        anchors.fill: parent
        color: theme.palette.normal.background
    }

    Connections {
        target: matrix
        onNewEvent: PageActions.update ( type, chat_id, eventType, eventContent )
    }


    Component.onCompleted: PageActions.init ()

    Component.onDestruction: PageActions.destruct ()

    ChangeChatnameDialog { id: changeChatnameDialog }

    ChangeChatAvatarDialog { id: changeChatAvatarDialog }

    header: PageHeader {
        id: header
        title: activeChatDisplayName

        trailingActionBar {
            actions: [
            Action {
                iconName: "edit"
                text: i18n.tr("Edit chat name")
                onTriggered: PopupUtils.open(changeChatnameDialog)
            }
            ]
        }
    }


    ScrollView {
        id: scrollView
        width: parent.width
        height: parent.height - header.height
        anchors.top: header.bottom
        contentItem: Column {
            width: chatSettingsPage.width

            Rectangle {
                width: parent.width
                height: units.gu(2)
                color: "#00000000"
                visible: profileRow.visible
            }

            Row {
                id: profileRow
                width: parent.width
                height: parent.width / 2
                spacing: units.gu(2)
                visible: hasAvatar || description !== ""

                property var avatar_url: ""

                Rectangle {
                    height: parent.height
                    width: 1
                    color: "#00000000"
                }

                Avatar {
                    id: avatarImage
                    name: activeChatDisplayName
                    height: parent.height - units.gu(3)
                    width: height
                    mxc: ""
                    onClickFunction: function () {
                        imageViewer.show ( mxc )
                    }
                    Button {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        width: parent.width / 2
                        visible: canChangeAvatar
                        opacity: 0.75
                        color: "#000000"
                        iconName: "camera-app-symbolic"
                        onClicked: PopupUtils.open(changeChatAvatarDialog)
                    }
                    Component.onCompleted: MatrixNames.getAvatarUrl ( activeChat, function ( avatar_url ) { mxc = avatar_url } )
                }

                Column {
                    id: descColumn
                    width: parent.height - units.gu(3)
                    anchors.verticalCenter: parent.verticalCenter
                    Label {
                        text: i18n.tr("Description:")
                        width: parent.width
                        wrapMode: Text.Wrap
                        font.bold: true
                    }
                    Label {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: description !== "" ? description : i18n.tr("No chat description found…")
                        linkColor: mainLayout.brightMainColor
                        textFormat: Text.StyledText
                        onLinkActivated: contentHub.openUrlExternally ( link )
                    }
                    Label {
                        text: " "
                        width: parent.width
                    }
                }

            }

            Rectangle {
                width: parent.width
                height: settingsColumn.height
                color: theme.palette.normal.background
                Column {
                    id: settingsColumn
                    width: parent.width
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: UbuntuColors.ash
                        visible: profileRow.visible
                    }
                    SettingsListLink {
                        name: i18n.tr("Notifications")
                        icon: "notification"
                        page: "NotificationChatSettingsPage"
                        sourcePage: chatSettingsPage
                    }
                    SettingsListLink {
                        name: i18n.tr("Advanced settings")
                        icon: "filters"
                        page: "ChatAdvancedSettingsPage"
                        sourcePage: chatSettingsPage
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: units.gu(2)
                color: theme.palette.normal.background
            }
            Rectangle {
                width: parent.width
                height: units.gu(2)
                color: theme.palette.normal.background
                Label {
                    id: userInfo
                    height: units.gu(2)
                    anchors.left: parent.left
                    anchors.leftMargin: units.gu(2)
                    text: i18n.tr("Users in this chat (%1):").arg(memberCount)
                    font.bold: true
                }
            }
            Rectangle {
                width: parent.width
                height: units.gu(2)
                color: theme.palette.normal.background
            }
            Rectangle {
                width: parent.width
                height: searchField.height + units.gu(2)
                color: theme.palette.normal.background
                TextField {
                    id: searchField
                    objectName: "searchField"
                    property var upperCaseText: displayText.toUpperCase()
                    anchors {
                        left: parent.left
                        right: parent.right
                        rightMargin: units.gu(2)
                        leftMargin: units.gu(2)
                    }
                    inputMethodHints: Qt.ImhNoPredictiveText
                    placeholderText: i18n.tr("Search…")
                    onActiveFocusChanged: if ( activeFocus ) scrollView.flickableItem.contentY = scrollView.flickableItem.contentHeight - scrollView.height
                }
            }
            Rectangle {
                width: parent.width
                height: 1
                color: UbuntuColors.ash
            }

            ListView {
                id: memberList
                width: parent.width
                height: root.height - header.height - searchField.height - units.gu(8)
                delegate: MemberListItem { }
                model: ListModel { id: model }
                z: -1

                header: SettingsListFooter {
                    visible: canInvite
                    name: i18n.tr("Invite friends")
                    icon: "contact-new"
                    iconWidth: units.gu(4)
                    onClicked: bottomEdgePageStack.push ( Qt.resolvedUrl("./InvitePage.qml") )
                }

                Button {
                    anchors.centerIn: parent
                    text: i18n.tr("Reload")
                    color: UbuntuColors.green
                    onClicked: init()
                    visible: model.count === 0
                }
            }
        }
    }


    property var selectedUserId

    ActionSelectionPopover {
        id: contextualActions
        z: 10
        actions: ActionList {
            Action {
                text: i18n.tr("Enroll as member")
                onTriggered: PageActions.changePowerLevel ( 0 )
            }
            Action {
                text: i18n.tr("Appoint to moderator")
                onTriggered: PageActions.changePowerLevel ( 50 )
                visible: power >= 50
            }
            Action {
                text: i18n.tr("Appoint to admin")
                onTriggered: PageActions.changePowerLevel ( 100 )
                visible: power >= 100
            }
        }
    }

}
