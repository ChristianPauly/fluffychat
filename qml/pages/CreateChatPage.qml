import QtQuick 2.9
import QtQuick.Layouts 1.1
import Ubuntu.Components 1.3
import "../components"

Page {
    anchors.fill: parent

    header: FcPageHeader {
        id: header
        title: i18n.tr('Contacts')
        flickable: chatListView

        trailingActionBar {
            actions: [
            Action {
                id: newContactAction
                iconName: "contact-new"
                text: i18n.tr("Add from addressbook")
                onTriggered: contactImport.requestContact()
            }
            ]
        }

        extension: Rectangle {
            width: parent.width
            height: searchField.height + units.gu(1)
            color: theme.palette.normal.background
            anchors.bottom: parent.bottom

            TextField {
                id: searchField
                objectName: "searchField"
                property var searchMatrixId: false
                property var upperCaseText: displayText.toUpperCase()
                property var tempElement: null
                primaryItem: Icon {
                    height: parent.height - units.gu(1)
                    width: height
                    name: "find"
                }
                anchors {
                    left: parent.left
                    right: parent.right
                    rightMargin: units.gu(2)
                    leftMargin: units.gu(2)
                    top: parent.top
                }
                focus: true
                inputMethodHints: Qt.ImhNoPredictiveText
                placeholderText: i18n.tr("Search for example @username:server.abc")
                onDisplayTextChanged: {

                    if ( displayText.slice( 0,1 ) === "@" && displayText.length > 1 ) {
                        var input = displayText
                        if ( input.indexOf(":") === -1 ) {
                            input += ":" + settings.server
                        }
                        if ( tempElement !== null ) {
                            model.remove ( tempElement)
                            tempElement = null
                        }
                        if ( input.split(":").length > 2 || input.split("@").length > 2 || displayText.length < 2 ) return
                        model.append ( {
                            matrix_id: input,
                            medium: "matrix",
                            name: input,
                            address: input,
                            avatar_url: "",
                            last_active_ago: 0,
                            presence: "offline",
                            temp: true
                        })
                        tempElement = model.count - 1
                    }
                }
            }
        }
    }

    Connections {
        target: events
        onNewEvent: updatePresence ( type, chat_id, eventType, eventContent )
    }

    function updatePresence ( type, chat_id, eventType, eventContent ) {
        if ( type === "m.presence" ) {
            for ( var i = 0; i < model.count; i++ ) {
                if ( model.get(i).matrix_id === eventContent.sender ) {
                    model.set(i).matrix_id = eventContent.presence
                    if ( eventContent.last_active_ago ) model.set(i).last_active_ago = eventContent.last_active_ago
                    break
                }
            }
        }
    }

    Component.onCompleted: update ()

    function update () {
        storage.transaction( "SELECT Users.matrix_id, Users.displayname, Users.avatar_url, Users.presence, Users.last_active_ago, Contacts.medium, Contacts.address FROM Users LEFT JOIN Contacts " +
        " ON Contacts.matrix_id=Users.matrix_id WHERE Users.matrix_id!='" + settings.matrixid + "' ORDER BY Contacts.medium DESC, LOWER(Users.displayname || replace(Users.matrix_id,'@','')) LIMIT 1000",
        function( res )  {
            for( var i = 0; i < res.rows.length; i++ ) {
                var user = res.rows[i]
                model.append({
                    matrix_id: user.matrix_id,
                    name: user.displayname || usernames.transformFromId(user.matrix_id),
                    avatar_url: user.avatar_url,
                    medium: user.medium || "matrix",
                    address: user.address || user.matrix_id,
                    last_active_ago: user.last_active_ago,
                    presence: user.presence,
                    temp: false
                })
            }
        })
    }

    ListView {
        id: chatListView
        width: parent.width
        height: parent.height
        anchors.top: parent.top
        delegate: ContactListItem {}
        model: ListModel { id: model }

        header: SettingsListFooter {
            icon: newContactAction.iconName
            name: newContactAction.text
            iconWidth: units.gu(4)
            onClicked: {
                contactImport.requestContact()
                selectMode = false
            }
        }
    }

    ContactImport {
        id: contactImport
        newContactsFound: function () { update() }
    }

}
