import QtQuick 2.9
import QtQuick.Layouts 1.1
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3
import "../components"
import "../scripts/EventDescription.js" as EventDescription
import "../scripts/MatrixNames.js" as MatrixNames
import "../scripts/ChatListPageActions.js" as ChatListPageActions

Page {
    anchors.fill: parent
    id: chatListPage


    // To disable the background image on this page
    Rectangle {
        anchors.fill: parent
        color: theme.palette.normal.background
    }

    Component.onCompleted: ChatListPageActions.loadFromDatabase ()

    Connections {
        target: matrix
        onNewChatUpdate: ChatListPageActions.newChatUpdate ( chat_id, membership, notification_count, highlight_count, limitedTimeline )
        onNewEvent: ChatListPageActions.newEvent ( type, chat_id, eventType, eventContent )
    }

    Connections {
        target: storage
        onSyncInitialized: ChatListPageActions.loadFromDatabase ()
    }

    property bool searching: false

    header: PageHeader {
        id: header
        title: contentHub.shareObject === null ? i18n.tr("FluffyChat") : i18n.tr("Share")
        flickable: chatListView

        leadingActionBar {
            numberOfSlots: 2
            actions: [
            Action {
                iconName: "back"
                visible: searching
                onTriggered: searching = false
            },
            Action {
                iconName: "close"
                visible: contentHub.shareObject !== null
                onTriggered: contentHub.shareObject = null
            }]
        }

        trailingActionBar {
            actions: [
            Action {
                iconName: "filters"
                visible: contentHub.shareObject === null && !searching
                onTriggered: bottomEdgePageStack.push (Qt.resolvedUrl("./SettingsPage.qml"))
            },
            Action {
                iconName: "find"
                visible: !searching
                onTriggered: searchField.focus = searching = true
            }]
        }

        states: [
        State {
            name: "searching"
            when: searching
            PropertyChanges {
                target: header
                contents: searchField
            }
        }
        ]
    }

    TextField {
        id: searchField
        objectName: "searchField"
        property var searchMatrixId: false
        property var upperCaseText: displayText.toUpperCase()
        property var tempElement: null
        visible: searching
        primaryItem: Icon {
            height: parent.height - units.gu(2)
            name: "find"
            anchors.left: parent.left
            anchors.leftMargin: units.gu(0.25)
        }
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        width: parent.width
        inputMethodHints: Qt.ImhNoPredictiveText
        placeholderText: i18n.tr("Search for your chats…")
    }

    ListModel { id: model }

    ListView {
        id: chatListView
        width: parent.width
        height: parent.height - bottomEdgeHint.height
        anchors.top: parent.top
        delegate: ChatListItem {}
        model: model
        move: Transition {
            SmoothedAnimation { property: "y"; duration: 300 }
        }
        displaced: Transition {
            SmoothedAnimation { property: "y"; duration: 300 }
        }

        Label {
            text: i18n.tr("Swipe up from the bottom to start a new chat or discover public groups.")
            textSize: Label.Large
            color: UbuntuColors.graphite
            anchors.centerIn: parent
            width: parent.width - units.gu(4)
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideMiddle
            wrapMode: Text.Wrap
            visible: model.count === 0
        }
    }

    // ============================== BOTTOM EDGE ==============================

    BottomEdge {
        id: bottomEdge
        height: parent.height
        preloadContent: false
        contentComponent: Rectangle {
            width: chatListPage.width
            height: chatListPage.height
            color: theme.palette.normal.background
            CreateChatPage {
                id: createChatPage
            }
        }

        hint {
            id: bottomEdgeHint
            status: BottomEdgeHint.Locked
            text: bottomEdge.hint.status == BottomEdgeHint.Locked ? i18n.tr("Add chat") : ""
            iconName: "compose"
            onStatusChanged: if (status === BottomEdgeHint.Inactive) bottomEdge.hint.status = BottomEdgeHint.Locked
        }

    }
}
