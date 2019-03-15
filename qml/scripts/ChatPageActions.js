// File: ChatPageActions.js
// Description: Actions for ChatPage.qml

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

        data = MessageFormats.handleCommands ( data )

    }

    var type = sticker === undefined ? "m.room.message" : "m.sticker"

    // Send the message
    var fakeEvent = {
        type: type,
        event_id: messageID,
        id: messageID,
        sender: matrix.matrixid,
        content_body: MessageFormats.formatText ( data.body ),
        displayname: activeChatMembers[matrix.matrixid].displayname,
        avatar_url: activeChatMembers[matrix.matrixid].avatar_url,
        status: msg_status.SENDING,
        origin_server_ts: now,
        content: data
    }

    matrix.newEvent( type, activeChat, "timeline", fakeEvent )
    storage.save ()

    matrix.sendMessage ( messageID, data, activeChat, function ( response ) {
        messageSent ( messageID, response )
    }, function ( error ) {
        if ( error === "DELETE" ) removeEvent ( messageID )
        else errorEvent ( messageID )
    } )

    if ( sticker === undefined ) {
        isTyping = true
        messageTextField.text = " " // Workaround for bug on bq tablet
        messageTextField.text = ""
        messageTextField.height = header.height - units.gu(2)
        sendTypingNotification ( false )
        isTyping = false
    }
}


function sendTypingNotification ( typing ) {
    if ( !matrix.sendTypingNotification ) return
    if ( typing !== isTyping) {
        typingTimer.stop ()
        isTyping = typing
        matrix.put ( "/client/r0/rooms/%1/typing/%2".arg( activeChat ).arg( matrix.matrixid ), {
            typing: typing
        }, null, null, 0 )
    }
}

function init () {
    // Get infos about the chat
    var res = storage.query ( "SELECT draft, topic, membership, unread, fully_read, notification_count, power_events_default, power_redact FROM Chats WHERE id=?", [ activeChat ])
    if ( res.rows.length === 0 ) return
    var room = res.rows[0]
    membership = room.membership
    messageTextField.text = ""
    if ( room.draft !== "" && room.draft !== null ) messageTextField.text = room.draft

    // Get the own power level of the user
    var rs = storage.query ( "SELECT power_level FROM Memberships WHERE matrix_id=? AND chat_id=?", [
        matrix.matrixid, activeChat
    ])
    var power_level = 0
    if ( rs.rows.length > 0 ) power_level = rs.rows[0].power_level
    canRedact = power_level >= room.power_redact
    canSendMessages = power_level >= room.power_events_default
    chatActive = true
    chat_id = activeChat
    topic = room.topic


    // Request all participants displaynames and avatars
    activeChatMembers = []
    var memberResults = storage.query ( "SELECT membership.matrix_id, membership.displayname, membership.avatar_url, membership.membership, membership.power_level " +
    " FROM Memberships membership " +
    " WHERE membership.chat_id='" + activeChat + "'")
    // Make sure that the event for the users matrix id exists
    activeChatMembers[matrix.matrixid] = {
        displayname: MatrixNames.transformFromId(matrix.matrixid),
        avatar_url: ""
    }
    for ( var i = 0; i < memberResults.rows.length; i++ ) {
        var mxid = memberResults.rows[i].matrix_id
        activeChatMembers[ mxid ] = memberResults.rows[i]
        if ( activeChatMembers[ mxid ].displayname === null || activeChatMembers[ mxid ].displayname === "" ) {
            activeChatMembers[ mxid ].displayname = MatrixNames.transformFromId ( mxid )
        }
    }

    // Fill the chat list
    var res = storage.query ( "SELECT id, type, content_json, content_body, origin_server_ts, sender, state_key, status " +
    " FROM Events " +
    " WHERE chat_id='" + activeChat +
    "' ORDER BY origin_server_ts DESC" )
    // We now write the rooms in the column

    initialized = res.rows.length
    model.clear ()
    for ( var i = res.rows.length-1; i >= 0; i-- ) {
        var event = res.rows.item(i)
        event.content = JSON.parse( event.content_json )
        addEventToList ( event, false )
        if ( event.matrix_id === null ) requestRoomMember ( event.sender )
    }

    // Is there an unread marker? Then mark as read!
    var lastEvent = chatScrollView.model.get(0).event
    pushClient.dismissNotification ( activeChat )
    if ( room.unread < lastEvent.origin_server_ts && lastEvent.sender !== matrix.matrixid ) {
        matrix.post( "/client/r0/rooms/" + activeChat + "/receipt/m.read/" + lastEvent.id, null, null, null, 0 )
    }

    // Scroll top to the last seen message?
    matrix.post ( "/client/r0/rooms/%1/read_markers".arg(activeChat), { "m.fully_read": lastEvent.id }, null, null, 0 )
    if ( room.fully_read !== lastEvent.id ) {
        // Check if the last event is in the database
        var found = false
        for ( var j = 0; j < count; j++ ) {
            if ( chatScrollView.model.get(j).event.id === room.fully_read ) {
                chatScrollView.positionViewAtIndex (j, ListView.Contain )

                found = true
                break
            }
        }
        if ( !found ) requestHistory ( room.fully_read )
    }


    // Is there something to share? Then now share it!
    if ( contentHub.shareObject !== null ) {
        var message = ""
        if ( contentHub.shareObject.items ) {
            for ( var i = 0; i < contentHub.shareObject.items.length; i++ ) {
                if (String(contentHub.shareObject.items[i].text).length > 0 && String(contentHub.shareObject.items[i].url).length == 0) {
                    message += String(contentHub.shareObject.items[i].text)
                }
                else if (String(contentHub.shareObject.items[i].url).length > 0 ) {
                    message += String(contentHub.shareObject.items[i].url)
                }
                if ( i+1 < contentHub.shareObject.items.length ) message += "\n"
            }
            if ( message !== "") messageTextField.text = message
        }
        else if ( contentHub.shareObject.matrixEvent ) {
            var now = new Date().getTime()
            var messageID = "" + now
            matrix.put( "/client/r0/rooms/" + activeChat + "/send/m.room.message/" + messageID, contentHub.shareObject.matrixEvent, null, null, 2 )
        }

        contentHub.shareObject = null
    }
}

// Request more previous events from the server
function requestHistory ( event_id ) {
    if ( initialized !== model.count || requesting || (model.count > 0 && model.get( model.count -1 ).event.type === "m.room.create") ) return
    requesting = true
    var rs = storage.query ( "SELECT prev_batch FROM Chats WHERE id=?", [ activeChat ] )
    if ( rs.rows.length === 0 ) return
    var maxHistoryCount = historyCount
    if ( event_id ) maxHistoryCount = historyCount*4
    var data = {
        from: rs.rows[0].prev_batch,
        dir: "b",
        limit: historyCount
    }

    var historyRequestCallback = function ( result ) {
        if ( activeChat !== currentChat ) return
        if ( result.chunk.length > 0 ) {
            var eventFound = false

            if ( event_id ) {
                for ( var i = 0; i < result.chunk.length; i++ ) {
                    if ( event_id && !eventFound && event_id === result.chunk[i].event_id ) eventFound = i
                }
            }

            matrix.handleRoomEvents ( activeChat, result.chunk, "history", matrix.newEvent )
            storage.save ()

            requesting = false
            storage.query ( "UPDATE Chats SET prev_batch=? WHERE id=?", [ result.end, activeChat ])
        }
        else requesting = false
        if ( event_id ) {
            if ( eventFound !== false ) {
                var indx = count - 1 - historyCount + eventFound
                chatScrollView.positionViewAtIndex ( indx, ListView.Contain )
            }
        }
    }

    var historyRequestErrorCallback = function () {
        requesting = false
    }

    var currentChat = activeChat

    matrix.get( "/client/r0/rooms/" + activeChat + "/messages", data, historyRequestCallback, historyRequestErrorCallback, 1 )
}

function destruction () {
    model.clear ()
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
            activeChatMembers [eventContent.state_key].displayname = MatrixNames.transformFromId ( eventContent.state_key )
        }
        if ( activeChatMembers [eventContent.state_key].avatar_url === undefined || activeChatMembers [eventContent.state_key].avatar_url === null ) {
            activeChatMembers [eventContent.state_key].avatar_url = ""
        }
        if ( topic === "" ) {
            MatrixNames.getChatAvatarById ( activeChat, function ( name ) {
                activeChatDisplayName = name
            })
        }
    }
    else if ( type === "m.receipt" && eventContent.user !== matrix.matrixid ) {
        markRead ( eventContent.ts )
    }
    if ( eventType === "timeline" || eventType === "history" ) {
        eventContent.id = eventContent.event_id
        if ( typeof eventContent.status !== "number" ) {
            eventContent.status = msg_status.RECEIVED
        }
        addEventToList ( eventContent, eventType === "history" )

        if ( type === "m.room.redaction" ) removeEvent ( eventContent.redacts )
        if ( eventType !== "history" ) {
            matrix.post( "/client/r0/rooms/" + activeChat + "/receipt/m.read/" + eventContent.event_id, null )
        }
    }
}


// This function writes the event in the chat. The event MUST have the format
// of a database entry, described in the storage controller
function addEventToList ( event, history ) {

    // Display this event at all? In the chat settings the user can choose
    // which events should be displayed. Less important events are all events,
    // that or not member events from other users and the room create events.
    if ( matrix.hideLessImportantEvents && model.count > 0 && event.type !== "m.room.message" && event.type !== "m.room.encrypted" && event.type !== "m.sticker" ) {
        var lastEvent = model.get(0).event
        if ( lastEvent.origin_server_ts < event.origin_server_ts ) {
            if ( lastEvent.type === "m.room.create" && event.sender === lastEvent.sender ) return
            if ( (lastEvent.type === "m.room.member" || lastEvent.type === "m.room.multipleMember") && event.type === "m.room.member" ) {
                event.type = "m.room.multipleMember"
                model.remove( 0 )
                model.insert( 0, { "event": event } )
                return
            }
        }
    }

    // Is the sender of this event in the local database? If not, then request
    // the displayname and avatar url of this sender.
    if ( activeChatMembers[event.sender] === undefined) {
        activeChatMembers[event.sender] = {
            "displayname": MatrixNames.transformFromId ( event.sender ),
            "avatar_url": ""
        }
        matrix.get ( "/client/r0/rooms/%1/state/m.room.member/%2".arg(activeChat).arg(event.sender), {}, function ( response ) {
            var newEvent = {
                content: response,
                state_key: event.sender,
                type: "m.room.member"
            }
            matrix.handleRoomEvents ( activeChat, [ newEvent ], "state" )
            storage.save ()
        }, null, 0)
    }


    if ( !("content_body" in event) ) event.content_body = event.content.body
    if ( history ) event.status = msg_status.HISTORY


    // If there is a transaction id, remove the sending event and end here
    if ( "unsigned" in event && "transaction_id" in event.unsigned ) {
        event.unsigned.transaction_id = event.unsigned.transaction_id
        for ( var i = 0; i < model.count; i++ ) {
            var tempEvent = model.get(i).event
            if ( tempEvent.id === event.unsigned.transaction_id || tempEvent.id === event.id) {
                model.set( i, { "event": event } )
                return
            }
        }
    }


    // Find the right position for this event
    var j = history ? model.count : 0
    if ( !history ) {
        while ( j < model.count && event.origin_server_ts < model.get(j).event.origin_server_ts ) j++
    }


    // Check that there is no duplication:
    if ( model.count > j && event.id === model.get(j).event.id ) {
        model.set( j, { "event": event } )
        return
    }


    // Now insert it
    model.insert ( j, { "event": event } )
    initialized = model.count
}


function messageSent ( oldID, newID ) {
    for ( var i = 0; i < model.count; i++ ) {
        if ( model.get(i).event.id === oldID ) {
            var tempEvent = model.get(i).event
            tempEvent.id = newID
            tempEvent.status = msg_status.SENT
            tempEvent.origin_server_ts = new Date().getTime()
            model.set( i, { "event": tempEvent } )

            // Move the event to the correct position if necessary
            var j = i
            while ( j > 0 && tempEvent.origin_server_ts > model.get(j).event.origin_server_ts ) j--
            if ( i !== j ) {
                model.move( i, j, 1 )
            }
            break
        }
        else if ( model.get(i).event.id === newID ) break
    }
}


function errorEvent ( messageID ) {
    console.log("ERRORMSG", messageID)
    for ( var i = 0; i < model.count; i++ ) {
        if ( model.get(i).event.id === messageID ) {
            console.log(i,msg_status.ERROR)
            var tempEvent = model.get(i).event
            tempEvent.status = msg_status.ERROR
            model.set( i, { "event": tempEvent } )
            break
        }
    }
}


// This function handles new events, based on the signal from the event
// controller. It just has to format the event to the database format
function handleNewEvent ( type, eventContent ) {
    eventContent.id = eventContent.event_id
    addEventToList ( eventContent )

    if ( type === "m.room.redaction" ) removeEvent ( eventContent.redacts )
}


function removeEvent ( event_id ) {
    for ( var i = 0; i < model.count; i++ ) {
        if ( model.get(i).event.id === event_id ) {
            model.remove ( i )
            break
        }
    }
}


function markRead ( timestamp ) {
    for ( var i = 0; i < model.count; i++ ) {
        if ( model.get(i).event.sender === matrix.matrixid &&
        model.get(i).event.origin_server_ts <= timestamp &&
        model.get(i).event.status > msg_status.SENT ) {
            var tempEvent = model.get(i).event
            tempEvent.status = msg_status.SEEN
            model.set( i, { "event": tempEvent } )
        }
        else if ( model.get(i).event.status === msg_status.SEEN ) break
    }
}


function join () {
    var successCallback = function () {
        matrix.waitForSync ()
        membership = "join"
    }
    matrix.post("/client/r0/join/" + encodeURIComponent(activeChat), null, successCallback, 2)
}


function ActiveFocusChanged ( activeFocus ) {
    if ( activeFocus && stickerInput.visible ) stickerInput.hide()
    if ( !activeFocus ) sendTypingNotification ( activeFocus )
}
