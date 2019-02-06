import QtQuick 2.9
import QtQuick.Layouts 1.1
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3
import "../components"
import "../scripts/MatrixNames.js" as MatrixNames

ListItem {
    id: chatListItem

    property var previousMessage: ""
    property var isUnread: (room.unread < room.origin_server_ts && room.sender !== settings.matrixid) || room.membership === "invite"
    property var newNotifictaions: room.notification_count > 0

    visible: { layout.title.text.toUpperCase().indexOf( searchField.displayText.toUpperCase() ) !== -1 }
    height: visible ? layout.height : 0

    color: settings.darkmode ? "#202020" : "white"

    highlightColor: settings.darkmode ? settings.mainColor : settings.brighterMainColor

    function triggered () {
        if ( room.membership !== "leave" ) {
            activeChatTypingUsers = room.typing || []
            mainStack.toChat ( room.id )
        }
        else matrix.joinChat ( room.id )
        searchField.text = ""
    }

    onClicked: triggered ()

    ListItemLayout {
        id: layout
        width: parent.width - notificationBubble.width - highlightBubble.width
        title.text: room.topic !== "" && room.topic !== null ? room.topic : MatrixNames.getChatAvatarById ( room.id, function (displayname) {
            layout.title.text = displayname
        })
        title.font.bold: true
        title.color: mainFontColor
        subtitle.text: {
            room.membership === "invite" ? i18n.tr("You have been invited to this chat") :
            (room.membership === "leave" ? "" :
            (room.topic !== "" && room.typing && room.typing.length > 0 ? MatrixNames.getTypingDisplayString ( room.typing, room.topic ) :
            (room.content_body ? ( room.sender === settings.matrixid ? i18n.tr("You: ") : "" ) + room.content_body :
            i18n.tr("No preview messages"))))
        }
        subtitle.color: mainFontColor
        subtitle.linkColor: subtitle.color

        Avatar {
            id: avatar
            SlotsLayout.position: SlotsLayout.Leading
            name: layout.title.text
            mxc: room.avatar_url !== "" && room.avatar_url !== null && room.avatar_url !== undefined ? room.avatar_url : MatrixNames.getAvatarFromSingleChat ( room.id, function ( avatar_url ) {
                avatar.mxc = avatar_url
            } )
            onClickFunction: function () { triggered () }
        }
    }


    Label {
        id: stampLabel
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: units.gu(2)
        text: stamp.getChatTime ( room.origin_server_ts )
        color: mainFontColor
        textSize: Label.XSmall
        visible: text != ""
    }


    // Notification count bubble on the bottom right
    Rectangle {
        id: notificationBubble
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: units.gu(2)
        width: unreadLabel.width + units.gu(1)
        height: units.gu(2)
        color: newNotifictaions ? settings.mainColor : mainBorderColor
        radius: units.gu(0.5)
        Label {
            id: unreadLabel
            anchors.centerIn: parent
            text: room.notification_count || "+1"
            textSize: Label.Small
            color: newNotifictaions ? UbuntuColors.porcelain : mainFontColor
        }
        visible: newNotifictaions || isUnread
    }


    Icon {
        id: highlightBubble
        visible: room.highlight_count > 0
        name: "dialog-warning-symbolic"
        anchors.right: notificationBubble.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: units.gu(2)
        anchors.rightMargin: units.gu(0.5)
        width: units.gu(2)
        height: width
    }


    // Notification-settings Button
    trailingActions: ListItemActions {
        actions: [
        Action {
            iconName: "info"
            text: i18n.tr("Chat settings")
            onTriggered: {
                activeChat = room.id
                mainStack.push (Qt.resolvedUrl("../pages/ChatSettingsPage.qml"))
            }
        }
        ]
    }

    // Delete Button
    leadingActions: ListItemActions {
        actions: [
        Action {
            iconName: "edit-delete"
            text: i18n.tr("Leave this chat")
            onTriggered: {
                activeChat = room.id
                PopupUtils.open(leaveChatDialog)
            }
        }
        ]
    }


}
