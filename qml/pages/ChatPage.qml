import QtQuick 2.9
import QtQuick.Layouts 1.1
import Ubuntu.Content 1.3
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3
import "../components"

Page {

    id: chatPage

    property var membership: "join"
    property var isTyping: false
    property var pageName: "chat"
    property var canSendMessages: true
    property var replyEvent: null
    property var chat_id
    property var topic: ""

    width: mainStack.width

    function send ( message ) {
        if ( !messageTextField.displayText.replace(/\s/g, '').length && message === undefined ) return

        var sticker = undefined
        if ( message === undefined ) {
            messageTextField.focus = false
            message = messageTextField.displayText
            messageTextField.focus = true
        }
        if ( typeof message !== "string" ) sticker = message

        // Send the message
        var now = new Date().getTime()
        var messageID = "" + now
        var data = {
            msgtype: "m.text",
            body: message
        }

        if ( sticker !== undefined ) {
            if ( !sticker.name ) sticker.name = "sticker"
            data.body = sticker.name
            data.msgtype = "m.sticker"
            data.url = sticker.url
            data.info = {
                "mimetype": sticker.mimetype,
                "thumbnail_url": sticker.thumbnail_url || sticker.url,
            }
        }
        else {

            // Add reply event to message
            if ( replyEvent !== null ) {

                // Add event ID to the reply object
                data["m.relates_to"] = {
                    "m.in_reply_to": {
                        "event_id": replyEvent.id
                    }
                }

                // Use formatted body
                data.format = "org.matrix.custom.html"
                data.formatted_body = '<mx-reply><blockquote><a href="https://matrix.to/#/%1/%2">In reply to</a> <a href="https://matrix.to/#/%3">%4</a><br>%5</blockquote></mx-reply>'
                .arg(activeChat).arg(replyEvent.id).arg(replyEvent.sender).arg(replyEvent.sender).arg(replyEvent.content.body)
                + data.body

                // Change the normal body too
                var contentLines = replyEvent.content.body.split("\n")
                for ( var i = 0; i < contentLines.length; i++ ) {
                    if ( contentLines[i].slice(0,1) === ">" ) {
                        contentLines.splice(i,1)
                        i--
                    }
                }
                replyEvent.content.body = contentLines.join("\n")
                var replyBody = "> <%1> ".arg(replyEvent.sender) + replyEvent.content.body.split("\n").join("\n>")
                data.body = replyBody + "\n\n" + data.body

                replyEvent = null
            }

            data = sender.handleCommands ( data )

        }

        var type = sticker === undefined ? "m.room.message" : "m.sticker"

        // Save the message in the database
        storage.query ( "INSERT OR REPLACE INTO Events VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        [ messageID,
        activeChat,
        now,
        settings.matrixid,
        settings.matrixid,
        message,
        null,
        type,
        JSON.stringify(data),
        msg_status.SENDING ], function ( rs ) {
            // Send the message
            var fakeEvent = {
                type: type,
                id: messageID,
                sender: settings.matrixid,
                content_body: sender.formatText ( data.body ),
                displayname: activeChatMembers[settings.matrixid].displayname,
                avatar_url: activeChatMembers[settings.matrixid].avatar_url,
                status: msg_status.SENDING,
                origin_server_ts: now,
                content: data
            }
            chatScrollView.addEventToList ( fakeEvent )

            sender.sendMessage ( messageID, data, activeChat, function ( response ) {
                chatScrollView.messageSent ( messageID, response )
            }, function ( error ) {
                if ( error === "DELETE" ) chatScrollView.removeEvent ( messageID )
                else chatScrollView.errorEvent ( messageID )
            } )

            if ( sticker === undefined ) {
                isTyping = true
                messageTextField.text = " " // Workaround for bug on bq tablet
                messageTextField.text = ""
                messageTextField.height = header.height - units.gu(2)
                sendTypingNotification ( false )
                isTyping = false
            }
        })
    }


    function sendTypingNotification ( typing ) {
        if ( !settings.sendTypingNotification ) return
        if ( typing !== isTyping) {
            typingTimer.stop ()
            isTyping = typing
            matrix.put ( "/client/r0/rooms/%1/typing/%2".arg( activeChat ).arg( settings.matrixid ), {
                typing: typing
            }, null, null, 0 )
        }
    }


    Component.onCompleted: {
        storage.transaction ( "SELECT draft, topic, membership, unread, fully_read, notification_count, power_events_default, power_redact FROM Chats WHERE id='" + activeChat + "'", function (res) {
            if ( res.rows.length === 0 ) return
            var room = res.rows[0]
            membership = room.membership
            if ( room.draft !== "" && room.draft !== null ) messageTextField.text = room.draft
            storage.transaction ( "SELECT power_level FROM Memberships WHERE " +
            "matrix_id='" + settings.matrixid + "' AND chat_id='" + activeChat + "'", function ( rs ) {
                var power_level = 0
                if ( rs.rows.length > 0 ) power_level = rs.rows[0].power_level
                chatScrollView.canRedact = power_level >= room.power_redact
                canSendMessages = power_level >= room.power_events_default
            })
            chatScrollView.init ()
            chatActive = true
            chat_id = activeChat
            topic = room.topic

            // Is there an unread marker? Then mark as read!
            var lastEvent = chatScrollView.model.get(0).event
            if ( room.unread < lastEvent.origin_server_ts && lastEvent.sender !== settings.matrixid ) {
                matrix.post( "/client/r0/rooms/" + activeChat + "/receipt/m.read/" + lastEvent.id, null, null, null, 0 )
            }

            // Scroll top to the last seen message?
            if ( room.fully_read !== lastEvent.id ) {
                // Check if the last event is in the database
                var found = false
                for ( var j = 0; j < chatScrollView.count; j++ ) {
                    if ( chatScrollView.get(j).event.id === room.fully_read ) {
                        chatScrollView.currentIndex = j
                        matrix.post ( "/client/r0/rooms/%1/read_markers".arg(activeChat), { "m.fully_read": lastEvent.id }, null, null, 0 )
                        found = true
                        break
                    }
                }
                if ( !found ) chatScrollView.requestHistory ( room.fully_read )
            }
        })


        // Is there something to share? Then now share it!
        if ( shareObject !== null ) {
            var message = ""
            if ( shareObject.items ) {
                for ( var i = 0; i < shareObject.items.length; i++ ) {
                    if (String(shareObject.items[i].text).length > 0 && String(shareObject.items[i].url).length == 0) {
                        message += String(shareObject.items[i].text)
                    }
                    else if (String(shareObject.items[i].url).length > 0 ) {
                        message += String(shareObject.items[i].url)
                    }
                    if ( i+1 < shareObject.items.length ) message += "\n"
                }
                if ( message !== "") messageTextField.text = message
            }
            else if ( shareObject.matrixEvent ) {
                var now = new Date().getTime()
                var messageID = "" + now
                matrix.put( "/client/r0/rooms/" + activeChat + "/send/m.room.message/" + messageID, shareObject.matrixEvent, null, null, 2 )
            }

            shareObject = null
        }
    }

    Component.onDestruction: {
        if ( chat_id !== activeChat ) return
        var lastEventId = chatScrollView.count > 0 ? chatScrollView.lastEventId : ""
        storage.query ( "UPDATE Chats SET draft=? WHERE id=?", [
        messageTextField.displayText,
        activeChat
        ])
        sendTypingNotification ( false )
        chatActive = false
        activeChat = null
        audio.stop ()
        audio.source = ""
    }

    Connections {
        target: events
        onNewChatUpdate: newChatUpdate ( chat_id, membership, notification_count, highlight_count, limitedTimeline )
        onNewEvent: newEvent ( type, chat_id, eventType, eventContent )
    }

    function newChatUpdate ( chat_id, new_membership, notification_count, highlight_count, limitedTimeline ) {
        if ( chat_id !== activeChat ) return
        membership = new_membership
        if ( limitedTimeline ) chatScrollView.model.clear ()
    }

    function newEvent ( type, chat_id, eventType, eventContent ) {
        if ( chat_id !== activeChat ) return
        if ( type === "m.typing" ) {
            activeChatTypingUsers = eventContent
        }
        else if ( type === "m.room.member") {
            activeChatMembers [eventContent.state_key] = eventContent.content
            if ( activeChatMembers [eventContent.state_key].displayname === undefined || activeChatMembers [eventContent.state_key].displayname === null || activeChatMembers [eventContent.state_key].displayname === "" ) {
                activeChatMembers [eventContent.state_key].displayname = usernames.transformFromId ( eventContent.state_key )
            }
            if ( activeChatMembers [eventContent.state_key].avatar_url === undefined || activeChatMembers [eventContent.state_key].avatar_url === null ) {
                activeChatMembers [eventContent.state_key].avatar_url = ""
            }
            if ( topic === "" ) {
                roomnames.getById ( activeChat, function ( name ) {
                    activeChatDisplayName = name
                })
            }
        }
        else if ( type === "m.receipt" && eventContent.user !== settings.matrixid ) {
            chatScrollView.markRead ( eventContent.ts )
        }
        if ( eventType === "timeline" ) {
            chatScrollView.handleNewEvent ( type, eventContent )
            matrix.post( "/client/r0/rooms/" + activeChat + "/receipt/m.read/" + eventContent.event_id, null )
        }
    }

    ChangeChatnameDialog { id: changeChatnameDialog }

    header: FcPageHeader {
        id: header
        title: (activeChatDisplayName || i18n.tr("Unknown chat"))

        contents: Column {
            width: parent.width
            anchors.centerIn: parent

            Label {
                id: titleLabel
                text: header.title
                color: mainFontColor
                textSize: Label.Large
                Transition {
                    NumberAnimation { properties: "anchors.topMargin"; duration: 1000 }
                }
            }

            Label {
                id: typingLabel
                visible: activeChatTypingUsers.length > 0
                height: visible ? units.gu(2) : 0
                text: (activeChatTypingUsers.length > 0 ? usernames.getTypingDisplayString( activeChatTypingUsers, activeChatDisplayName ) : "")
                color: mainFontColor
            }
        }

        trailingActionBar {
            numberOfSlots: 1
            actions: [
            Action {
                iconName: "edit-delete"
                text: i18n.tr("Remove")
                visible: membership !== "join"
                onTriggered: PopupUtils.open ( leaveChatDialog )
            },
            Action {
                iconName: "info"
                text: i18n.tr("Chat info")
                visible: membership === "join"
                onTriggered: mainStack.push(Qt.resolvedUrl("./ChatSettingsPage.qml"))
            }
            ]
        }
    }

    LeaveChatDialog { id: leaveChatDialog }

    Icon {
        visible: settings.chatBackground === undefined
        source: "../../assets/chat.svg"
        color: settings.mainColor
        anchors.centerIn: parent
        width: parent.width
        height: width * ( 1052 / 744 )
        opacity: 0.1
        z: 0
    }


    Label {
        text: i18n.tr('No messages in this chat ...')
        anchors.centerIn: parent
        visible: chatScrollView.count === 0
    }


    Rectangle {
        id: replyEventView
        width: parent.width
        anchors.bottom: chatInput.top
        anchors.left: parent.left
        height: header.height - 2
        opacity: 0
        color: theme.palette.normal.background
        z: 14
        Rectangle {
            width: parent.width
            height: 1
            color: UbuntuColors.silk
            anchors.bottom: parent.bottom
            anchors.left: parent.left
        }
        Label {
            text: replyEvent !== null ? i18n.tr("Reply to <b>%1</b>: \"%2\"").arg(activeChatMembers[replyEvent.sender].displayname).arg(replyEvent.content.body.split("\n").join(" ")) : ""
            anchors.left: parent.left
            anchors.right: closeReplyIcon.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: units.gu(0.5)
            elide: Text.ElideRight
        }
        ActionBar {
            id: closeReplyIcon
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: units.gu(0.5)
            actions: [
            Action {
                iconName: "close"
                onTriggered: replyEvent = null
            }
            ]
        }
        states: State {
            name: "visible"; when: replyEvent !== null
            PropertyChanges {
                target: replyEventView
                opacity: 1
            }
        }

        transitions: Transition {
            NumberAnimation { property: "opacity"; duration: 300 }
        }
    }



    FlyingButton {
        id: scrollDownButton
        mouseArea.onClicked: chatScrollView.positionViewAtBeginning ()
        iconName: "toolkit_chevron-down_4gu"
        anchors.bottomMargin: (width/2) + chatInput.height
        visibleState: !chatScrollView.atYEnd
    }

    ChatScrollView {
        id: chatScrollView
    }

    StickerInput {
        id: stickerInput
        anchors.bottom: chatInput.top
    }

    Rectangle {
        id: chatInput
        height: messageTextField.height + units.gu(2)
        width: parent.width + 2
        border.width: 1
        border.color: settings.darkmode ? UbuntuColors.slate : UbuntuColors.silk
        color: theme.palette.normal.background
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: -border.width
            leftMargin: -border.width
            rightMargin: -border.width
        }


        Button {
            id: joinButton
            color: UbuntuColors.green
            text: membership === "invite" ? i18n.tr("Accept invitation") : i18n.tr("Join")
            anchors.centerIn: parent
            visible: membership !== "join"
            onClicked: {
                loadingScreen.visible = true
                matrix.post("/client/r0/join/" + encodeURIComponent(activeChat), null, function () {
                    events.waitForSync ()
                    membership = "join"
                })
            }
        }


        Label {
            text: i18n.tr("You do not have posting permissions here")
            anchors.centerIn: parent
            visible: !canSendMessages
        }

        Component {
            id: pickerComponent
            PickerDialog {}
        }


        Timer {
            id: typingTimer
            interval: typingTimeout
            running: false
            repeat: false
            onTriggered: isTyping = false
        }

        TextArea {
            id: messageTextField
            anchors {
                bottom: parent.bottom
                margins: units.gu(1)
                rightMargin: units.gu(0.5)
                right: chatInputActionBar.left
                left: showStickerInput.visible ? showStickerInput.right : parent.left
            }
            property var hasText: false
            autoSize: height <= mainStackWidth / 2 - header.height - units.gu(2)
            maximumLineCount: 0
            placeholderText: i18n.tr("Type something ...")
            Keys.onReturnPressed: sendButton.trigger ()
            // If the user leaves the focus of the textfield: Send that he is no
            // longer typing.
            onActiveFocusChanged: {
                if ( activeFocus && stickerInput.visible ) stickerInput.hide()
                if ( !activeFocus ) sendTypingNotification ( activeFocus )
            }
            onDisplayTextChanged: {
                // A message must not start with white space
                if ( displayText === " " ) text = ""
                else {
                    // Send typing notification true or false
                    if ( displayText !== "" ) {
                        sendTypingNotification ( true )
                    }
                    else {
                        sendTypingNotification ( false )
                    }
                }
            }
            visible: membership === "join" && canSendMessages
        }

        Button {
            id: showStickerInput
            iconName: stickerInput.visible ? "close" : "add"
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: units.gu(1)
            color: settings.darkmode ? UbuntuColors.graphite : UbuntuColors.porcelain
            visible: membership === "join" && canSendMessages && replyEvent === null
            width: height
            onClicked: mediaImport.requestMedia()//stickerInput.visible ? stickerInput.hide() : stickerInput.show()
        }

        MediaImport {
            id: mediaImport
            onMediaReceived: matrix.upload ( mediaUrl )
        }

        ActionBar {
            id: chatInputActionBar
            visible: membership === "join" && canSendMessages
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: units.gu(0.5)
            actions: [
            Action {
                id: sendButton
                iconName: "send"
                onTriggered: send ()
            }
            ]
        }
    }

}
