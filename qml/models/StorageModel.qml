import QtQuick 2.9
import Ubuntu.Components 1.3
import QtQuick.LocalStorage 2.0
import Qt.labs.settings 1.0
import "../scripts/MatrixNames.js" as MatrixNames
import "../scripts/MessageFormats.js" as MessageFormats

/*============================= STORAGE MODEL =============================

The storage model is responsible for the database. There are some helper
functions for transactions and for the config table. In the future, the
database model will change sometimes and apps with a previous version must
drop their existing database and replace with it with the new model. In this
case, the storage controller will detect this via the version-property. If there
are changes to the database model, the version-property MUST be increaded!
*/

Item {

    id: storage

    property var version: "0.3.8"
    property string dbversion: ""
    property var db: LocalStorage.openDatabaseSync("FluffyChat", "2.0", "FluffyChat Database", 1000000)

    signal syncInitialized ()

    Settings {
        property alias dbversion: storage.dbversion
    }

    // Shortener for the sqlite transactions
    function query ( query, insert ) {
        try {
            var rs = {}
            db.transaction(
                function(tx) {
                    if ( insert ) rs = tx.executeSql( query, insert )
                    else rs = tx.executeSql( query )
                }
            )
            return rs
        }
        catch (e) {
            console.error("❌[Error]",e,query)
            if ( e.code && e.code === 2 ) {
                lockedScreen.visible = true
            }
        }
    }


    // Initializing the database
    Component.onCompleted: {
        // Check the database version number
        if ( dbversion !== version ) {
            console.log ("👷[Init] Create the database and drop previous one if existing")
            matrix.prevBatch = ""
            drop ()
            dbversion = version
        }
        query ( 'PRAGMA foreign_keys = OFF')
        query ( 'PRAGMA locking_mode = EXCLUSIVE')
        query ( 'PRAGMA temp_store = MEMORY')
        query ( 'PRAGMA cache_size')
        query ( 'PRAGMA cache_size = 10000')

        // TABLE SCHEMA FOR CHATS
        query('CREATE TABLE IF NOT EXISTS Chats(' +
        'id TEXT PRIMARY KEY, ' +
        'membership TEXT, ' +
        'topic TEXT, ' +
        'highlight_count INTEGER, ' +
        'notification_count INTEGER, ' +
        'limitedTimeline INTEGER, ' +
        'prev_batch TEXT, ' +
        'avatar_url TEXT, ' +
        'draft TEXT, ' +
        'unread INTEGER, ' +        // Timestamp of when the user has last read the chat
        'fully_read TEXT, ' +       // ID of the fully read marker event
        'description TEXT, ' +
        'canonical_alias TEXT, ' +  // The address in the form: #roomname:homeserver.org

        // Security rules
        'guest_access TEXT, ' +
        'history_visibility TEXT, ' +
        'join_rules TEXT, ' +

        // Power levels
        'power_events_default INTEGER, ' +
        'power_state_default INTEGER, ' +
        'power_redact INTEGER, ' +
        'power_invite INTEGER, ' +
        'power_ban INTEGER, ' +
        'power_kick INTEGER, ' +
        'power_user_default INTEGER, ' +

        // Power levels for events
        'power_event_avatar INTEGER, ' +
        'power_event_history_visibility INTEGER, ' +
        'power_event_canonical_alias INTEGER, ' +
        'power_event_aliases INTEGER, ' +
        'power_event_name INTEGER, ' +
        'power_event_power_levels INTEGER, ' +

        'UNIQUE(id))')

        // TABLE SCHEMA FOR EVENTS
        query('CREATE TABLE IF NOT EXISTS Events(' +
        'id TEXT PRIMARY KEY, ' +
        'chat_id TEXT, ' +
        'origin_server_ts INTEGER, ' +
        'sender TEXT, ' +
        'state_key TEXT, ' +
        'content_body TEXT, ' +
        'type TEXT, ' +
        'content_json TEXT, ' +
        "status INTEGER, " +
        'UNIQUE(id))')

        // TABLE SCHEMA FOR USERS
        query('CREATE TABLE IF NOT EXISTS Users(' +
        'matrix_id TEXT, ' +
        'displayname TEXT, ' +
        'avatar_url TEXT, ' +
        'presence TEXT, ' +
        'currently_active INTEGER, ' +
        'last_active_ago INTEGER, ' +
        'UNIQUE(matrix_id))')

        // TABLE SCHEMA FOR MEMBERSHIPS
        query('CREATE TABLE IF NOT EXISTS Memberships(' +
        'chat_id TEXT, ' +      // The chat id of this membership
        'matrix_id TEXT, ' +    // The matrix id of this user
        'displayname TEXT, ' +
        'avatar_url TEXT, ' +
        'membership TEXT, ' +   // The status of the membership. Must be one of [join, invite, ban, leave]
        'power_level INTEGER, ' +   // The power level of this user. Must be in [0,..,100]
        'UNIQUE(chat_id, matrix_id))')

        // TABLE SCHEMA FOR CONTACTS
        query('CREATE TABLE IF NOT EXISTS Contacts(' +
        'medium TEXT, ' +       // The medium this contact is identified by
        'address TEXT, ' +      // The email or phone number of this user if exists
        'matrix_id TEXT, ' +    // The matrix id of this user
        'UNIQUE(matrix_id))')

        // TABLE SCHEMA FOR CHAT ADDRESSES
        query('CREATE TABLE IF NOT EXISTS Addresses(' +
        'chat_id TEXT, ' +    // The correct chat id in the form: !hashstring:homeserver.org
        'address TEXT, ' + // The address in the form: #roomname:homeserver.org
        'UNIQUE(chat_id, address))')

        // TABLE SCHEMA FOR THIRD PARTY IDENTIFIES
        query('CREATE TABLE IF NOT EXISTS ThirdPIDs(' +
        'medium TEXT, ' +    // Should be "email" or "msisdn"
        'address TEXT, ' + // The email address or phone number
        'UNIQUE(medium, address))')

        // TABLE SCHEMA FOR UPLOADED MEDIA
        query('CREATE TABLE IF NOT EXISTS Media(' +
        'mimetype TEXT, ' +
        'url TEXT, ' +
        'name TEXT, ' +
        'thumbnail_url TEXT, ' +
        'UNIQUE(url))')

        if ( matrix.isLogged ) {
            storage.markSendingEventsAsError ()
        }
    }

    Connections {
        target: matrix
        onIsLoggedChanged: {
            if ( matrix.isLogged ) {
                storage.markSendingEventsAsError ()
            }
            else storage.clear ()
        }
    }


    function clear () {
        query('DELETE FROM Chats')
        query('DELETE FROM Events')
        query('DELETE FROM Users')
        query('DELETE FROM Memberships')
        query('DELETE FROM Contacts')
        query('DELETE FROM Addresses')
        query('DELETE FROM ThirdPIDs')
        query('DELETE FROM Media')
    }


    function drop () {
        query('DROP TABLE IF EXISTS Chats')
        query('DROP TABLE IF EXISTS Events')
        query('DROP TABLE IF EXISTS Users')
        query('DROP TABLE IF EXISTS Memberships')
        query('DROP TABLE IF EXISTS Contacts')
        query('DROP TABLE IF EXISTS Addresses')
        query('DROP TABLE IF EXISTS ThirdPIDs')
        query('DROP TABLE IF EXISTS Media')
    }

    property var queryQueue: []

    function addQuery ( query, param ) {
        var parameters = []
        if ( param ) parameters = param
        queryQueue[queryQueue.length] = { "query": query, "param": parameters}
    }


    // Save all incomming events in the database
    Connections {
        target: matrix

        onNewSync: save ()

        onNewEvent: newEvent ( type, chat_id, eventType, eventContent )
        onNewChatUpdate: newChatUpdate ( chat_id, membership, notification_count, highlight_count, limitedTimeline, prevBatch )
    }

    function save () {
        try {
            db.transaction(
                function(tx) {
                    while ( queryQueue.length > 0 ) {
                        tx.executeSql ( queryQueue[0].query, queryQueue[0].param )
                        queryQueue.splice( 0, 1 )
                    }
                }
            )
            if ( matrix.prevBatch === "" ) storage.syncInitialized ()
        }
        catch (e) {
            console.error("❌[Error]",e,query)
            if ( e.code && e.code === 2 ) {
                lockedScreen.visible = true
            }
        }
    }

    function newChatUpdate ( chat_id, membership, notification_count, highlight_count, limitedTimeline, prevBatch ) {
        // Insert the chat into the database if not exists
        addQuery ("INSERT OR IGNORE INTO Chats " +
        "VALUES(?, ?, '', 0, 0, 0, '', '', '', 0, '', '', '', '', '', '', 0, 50, 50, 0, 50, 50, 0, 50, 100, 50, 50, 50, 100) ", [
        chat_id, membership
        ] )

        // Update the notification counts and the limited timeline boolean
        addQuery ( "UPDATE Chats SET highlight_count=?, notification_count=?, membership=?, limitedTimeline=? WHERE id=? ", [
        highlight_count, notification_count, membership, limitedTimeline, chat_id
        ] )

        // Is the timeline limited? Then all previous messages should be
        // removed from the database!
        if ( limitedTimeline ) {
            addQuery ("DELETE FROM Events WHERE chat_id='" + chat_id + "'")
            addQuery ("UPDATE Chats SET prev_batch='" + prevBatch + "' WHERE id='" + chat_id + "'")
        }
    }

    function newEvent ( type, chat_id, eventType, eventContent ) {
        // Save timeline events in the database
        if ( eventType === "timeline" || eventType === "history" ) {

            // calculate the status
            var status = msg_status.RECEIVED
            if ( typeof eventContent.status === "number" ) status = eventContent.status
            else if ( eventType === "history" ) status = msg_status.HISTORY

            // Format the text for the app
            if( typeof eventContent.content.body === "string" ) {
                eventContent.content_body = MessageFormats.formatText ( eventContent.content.body )
            }
            else eventContent.content_body = null

            // Make unsigned part of the content
            if ( typeof eventContent.content.unsigned === "undefined" && typeof eventContent.unsigned !== "undefined" ) {
                eventContent.content.unsigned = eventContent.unsigned
            }

            // Get the state_key for m.room.member events
            var state_key = ""
            if ( typeof eventContent.state_key === "string" ) {
                state_key = eventContent.state_key
            }

            addQuery ( "INSERT OR REPLACE INTO Events VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [ eventContent.event_id,
            chat_id,
            eventContent.origin_server_ts,
            eventContent.sender,
            state_key,
            eventContent.content_body,
            eventContent.type,
            JSON.stringify(eventContent.content),
            status ])
        }

        // If this is a history event, then stop here...
        if ( eventType === "history" ) return

        // Handle state events
        switch ( type ) {

        case "m.presence":
            if ( typeof eventContent.content.presence === "string" ) {
                var query = "UPDATE Users SET presence = '%1' ".arg( eventContent.content.presence )
                if ( typeof eventContent.content.currently_active !== "undefined" ) {
                    query += ", currently_active = %1 ".arg( eventContent.content.currently_active ? "1" : "0" )
                }
                if ( typeof eventContent.content.last_active_ago !== "undefined" ) {
                    query += ", last_active_ago = %1 ".arg( (new Date().getTime() - eventContent.content.last_active_ago).toString() )
                }
                query += "WHERE matrix_id = '%1'".arg(eventContent.sender)
                addQuery( query )
            }
            break

        case "m.receipt":
            if ( eventContent.user === matrix.matrixid ) {
                addQuery( "UPDATE Chats SET unread=? WHERE id=?",
                [ eventContent.ts || new Date().getTime(),
                chat_id ])
            }
            else {
                // Mark all previous received messages as seen
                addQuery ( "UPDATE Events SET status=3 WHERE origin_server_ts<=" + eventContent.ts +
                " AND chat_id='" + chat_id + "' AND status=2")
            }
            break
            // This event means, that the name of a room has been changed, so
            // it has to be changed in the database.
        case "m.room.name":
            addQuery( "UPDATE Chats SET topic=? WHERE id=?",
            [ eventContent.content.name,
            chat_id ])
            break
            // This event means, that the topic of a room has been changed, so
            // it has to be changed in the database
        case "m.room.topic":
            addQuery( "UPDATE Chats SET description=? WHERE id=?",
            [ MessageFormats.formatText(eventContent.content.topic) || "",
            chat_id ])
            break
            // This event means, that the canonical alias of a room has been changed, so
            // it has to be changed in the database
        case "m.room.canonical_alias":
            addQuery( "UPDATE Chats SET canonical_alias=? WHERE id=?",
            [ eventContent.content.alias || "",
            chat_id ])
            break
            // This event means, that the topic of a room has been changed, so
            // it has to be changed in the database
        case "m.room.history_visibility":
            addQuery( "UPDATE Chats SET history_visibility=? WHERE id=?",
            [ eventContent.content.history_visibility,
            chat_id ])
            break
            // This event means, that the topic of a room has been changed, so
            // it has to be changed in the database
        case "m.room.redaction":
            addQuery( "DELETE FROM Events WHERE id=?",
            [ eventContent.redacts ])
            break
            // This event means, that the topic of a room has been changed, so
            // it has to be changed in the database
        case "m.room.guest_access":
            addQuery( "UPDATE Chats SET guest_access=? WHERE id=?",
            [ eventContent.content.guest_access,
            chat_id ])
            break
            // This event means, that the topic of a room has been changed, so
            // it has to be changed in the database
        case "m.room.join_rules":
            addQuery( "UPDATE Chats SET join_rules=? WHERE id=?",
            [ eventContent.content.join_rule,
            chat_id ])
            break
            // This event means, that the avatar of a room has been changed, so
            // it has to be changed in the database
        case "m.room.avatar":
            addQuery( "UPDATE Chats SET avatar_url=? WHERE id=?",
            [ eventContent.content.url,
            chat_id ])
            break
            // This event means, that the aliases of a room has been changed, so
            // it has to be changed in the database
        case "m.room.aliases":
            addQuery( "DELETE FROM Addresses WHERE chat_id='" + chat_id + "'")
            for ( var alias = 0; alias < eventContent.content.aliases.length; alias++ ) {
                if ( typeof eventContent.content.aliases[alias] !== "string" ) break
                addQuery( "INSERT INTO Addresses VALUES(?,?)",
                [ chat_id, eventContent.content.aliases[alias] ] )
            }
            break
            // This event means, that the aliases of a room has been changed, so
            // it has to be changed in the database
        case "m.fully_read":
            addQuery( "UPDATE Chats SET fully_read=? WHERE id=?",
            [ eventContent.content.event_id,
            chat_id ])
            break
            // This event means, that someone joined the room, has left the room
            // or has changed his nickname
        case "m.room.member":
            var membership = eventContent.content.membership
            var state_key = eventContent.state_key
            var insertDisplayname = ""
            var insertAvatarUrl = ""
            if ( typeof eventContent.content.displayname === "string" ) {
                insertDisplayname = eventContent.content.displayname
            }
            if ( typeof eventContent.content.avatar_url === "string" ) {
                insertAvatarUrl = eventContent.content.avatar_url
            }

            // Update user database
            var newUser = addQuery( "INSERT OR IGNORE INTO Users VALUES(?,?,?, '', '', 0)", [
            state_key, insertDisplayname, insertAvatarUrl
            ] )
            var queryStr = "UPDATE Users SET matrix_id=?"
            var queryArgs = [ state_key ]

            if ( typeof eventContent.content.displayname === "string" ) {
                queryStr += " , displayname=?"
                queryArgs[queryArgs.length] = eventContent.content.displayname
            }
            if ( typeof eventContent.content.avatar_url === "string" ) {
                queryStr += " , avatar_url=?"
                queryArgs[queryArgs.length] = eventContent.content.avatar_url
            }

            queryStr += " WHERE matrix_id=?"
            queryArgs[queryArgs.length] = state_key
            addQuery( queryStr, queryArgs)

            // Update membership table
            var newMembership = addQuery( "INSERT OR IGNORE INTO Memberships VALUES(?,?,?,?,?,0)", [
            chat_id, state_key, insertDisplayname, insertAvatarUrl, membership
            ] )
            var queryStr = "UPDATE Memberships SET membership=?"
            var queryArgs = [ membership ]

            if ( typeof eventContent.content.displayname === "string" ) {
                queryStr += " , displayname=?"
                queryArgs[queryArgs.length] = eventContent.content.displayname
            }
            if ( typeof eventContent.content.avatar_url === "string" ) {
                queryStr += " , avatar_url=?"
                queryArgs[queryArgs.length] = eventContent.content.avatar_url
            }

            queryStr += " WHERE matrix_id=? AND chat_id=?"
            queryArgs[queryArgs.length] = state_key
            queryArgs[queryArgs.length] = chat_id
            addQuery( queryStr, queryArgs)
            break
            // This event changes the permissions of the users and the power levels
        case "m.room.power_levels":
            var query = "UPDATE Chats SET "
            if ( typeof eventContent.content.ban === "number" ) query += ", power_ban=" + eventContent.content.ban
            if ( typeof eventContent.content.events_default === "number" ) query += ", power_events_default=" + eventContent.content.events_default
            if ( typeof eventContent.content.state_default === "number" ) query += ", power_state_default=" + eventContent.content.state_default
            if ( typeof eventContent.content.redact === "number" ) query += ", power_redact=" + eventContent.content.redact
            if ( typeof eventContent.content.invite === "number" ) query += ", power_invite=" + eventContent.content.invite
            if ( typeof eventContent.content.kick === "number" ) query += ", power_kick=" + eventContent.content.kick
            if ( typeof eventContent.content.user_default === "number" ) query += ", power_user_default=" + eventContent.content.user_default
            if ( typeof eventContent.content.events === "object" ) {
                if ( typeof eventContent.content.events["m.room.avatar"] === "number" ) query += ", power_event_avatar=" + eventContent.content.events["m.room.avatar"]
                if ( typeof eventContent.content.events["m.room.history_visibility"] === "number" ) query += ", power_event_history_visibility=" + eventContent.content.events["m.room.history_visibility"]
                if ( typeof eventContent.content.events["m.room.canonical_alias"] === "number" ) query += ", power_event_canonical_alias=" + eventContent.content.events["m.room.canonical_alias"]
                if ( typeof eventContent.content.events["m.room.aliases"] === "number" ) query += ", power_event_aliases=" + eventContent.content.events["m.room.aliases"]
                if ( typeof eventContent.content.events["m.room.name"] === "number" ) query += ", power_event_name=" + eventContent.content.events["m.room.name"]
                if ( typeof eventContent.content.events["m.room.power_levels"] === "number" ) query += ", power_event_power_levels=" + eventContent.content.events["m.room.power_levels"]
            }
            if ( query !== "UPDATE Chats SET ") {
                query = query.replace(",","")
                addQuery( query + " WHERE id=?",[ chat_id ])
            }

            // Set the users power levels:
            if ( typeof eventContent.content.users === "object" ) {
                for ( var user in eventContent.content.users ) {
                    var power_level = eventContent.content.users[user]
                    if ( typeof power_level !== "number" || typeof user !== "string" ) break
                    var updateResult = addQuery( "UPDATE Memberships SET power_level=? WHERE matrix_id=? AND chat_id=?",
                    [ power_level,
                    user,
                    chat_id ])
                    addQuery( "INSERT OR IGNORE INTO Memberships VALUES(?, ?, '', '', ?, ?)",
                    [ chat_id,
                    user,
                    "unknown",
                    power_level ])
                }
            }
            break
        }
    }

    function markSendingEventsAsError () {
        storage.query ( "UPDATE Events SET status=-1 WHERE status=0" )
    }

}
