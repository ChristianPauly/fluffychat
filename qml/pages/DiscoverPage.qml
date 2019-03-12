import QtQuick 2.9
import QtQuick.Layouts 1.1
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3
import "../components"
import "../scripts/DiscoverPageActions.js" as PageActions

Page {
    anchors.fill: parent
    id: discoverPage

    property var loading: true

    Component.onCompleted: PageActions.init ()

    // To disable the background image on this page
    Rectangle {
        anchors.fill: parent
        color: theme.palette.normal.background
    }

    header: PageHeader {
        id: header
        title: i18n.tr("Groups on %1").arg(matrix.server) + (matrix.server !== "matrix.org" ? " " + i18n.tr("and matrix.org") : "")
        flickable: chatListView

        contents: TextField {
            id: searchField
            objectName: "searchField"
            z: 5
            property var searchMatrixId: false
            property var upperCaseText: displayText.toUpperCase()
            property var tempElement: null
            primaryItem: Icon {
                height: parent.height - units.gu(2)
                name: "find"
                anchors.left: parent.left
                anchors.leftMargin: units.gu(0.25)
            }
            width: parent.width - units.gu(2)
            anchors.centerIn: parent
            onDisplayTextChanged: PageActions.displayTextChanged ( displayText )
            inputMethodHints: Qt.ImhNoPredictiveText
            placeholderText: i18n.tr("Search for chats or #aliases…")
        }
    }

    ListModel { id: model }

    ListView {
        id: chatListView
        width: parent.width
        height: parent.height
        anchors.top: parent.top
        delegate: PublicChatListItem {}
        model: model
        move: Transition {
            SmoothedAnimation { property: "y"; duration: 300 }
        }
        displaced: Transition {
            SmoothedAnimation { property: "y"; duration: 300 }
        }
    }

    Label {
        id: label
        text: loading ? i18n.tr("Loading…") : i18n.tr("No chats found")
        textSize: Label.Large
        color: UbuntuColors.graphite
        anchors.centerIn: parent
        visible: loading || model.count === 0
    }

}
