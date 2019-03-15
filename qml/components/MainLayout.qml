import QtQuick 2.9
import QtQuick.Layouts 1.1
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3
import Qt.labs.settings 1.0
import "../pages"
import "../scripts/DefaultLayoutActions.js" as DefaultLayoutActions

AdaptivePageLayout {

    id: mainLayout
    anchors.fill: parent
    readonly property var defaultPageColumnWidth: units.gu(50)
    readonly property var defaultMainColorH: 0.73
    property var mainFontColor: mainLayout.darkmode ? "#FFFFFF" : "#000000"
    property var mainBorderColor: mainLayout.darkmode ? "#333333" : "#CCCCCC"
    property var mainDividerColor: mainLayout.darkmode ? UbuntuColors.slate : UbuntuColors.silk
    property var mainBackgroundColor: mainLayout.darkmode ? "#202020" : "white"
    property var mainHighlightColor: mainLayout.darkmode ? mainLayout.mainColor : mainLayout.brighterMainColor
    property var incommingChatBubbleBackground: mainLayout.darkmode ? "#191A15" : UbuntuColors.porcelain

    // Dark mode enabled?
    property var darkmode: false

    // First walkthrough seen?
    property var walkthroughFinished: false
    property var updateInfosFinished: "0"

    // The path to the chat background
    property var chatBackground

    // The main color and the 'h' value
    property var mainColor: Qt.hsla(mainColorH, 0.67, 0.44, 1)
    property var brightMainColor: Qt.hsla(mainColorH, 0.67, 0.7, 1)
    property var brighterMainColor: Qt.hsla(mainColorH, 0.67, 0.85, 1)
    property var mainColorH: defaultMainColorH

    property bool allowThreeColumns: false

    Settings {
        property alias darkmode: mainLayout.darkmode
        property alias walkthroughFinished: mainLayout.walkthroughFinished
        property alias updateInfosFinished: mainLayout.updateInfosFinished
        property alias chatBackground: mainLayout.chatBackground
        property alias mainColor: mainLayout.mainColor
        property alias brightMainColor: mainLayout.brightMainColor
        property alias brighterMainColor: mainLayout.brighterMainColor
        property alias mainColorH: mainLayout.mainColorH
    }

    layouts: [
    PageColumnsLayout {
        when: width >= 3*defaultPageColumnWidth && matrix.isLogged && mainLayout.updateInfosFinished === version
        // column #0
        PageColumn {
            minimumWidth: 0.5*defaultPageColumnWidth
            maximumWidth: 1.5*defaultPageColumnWidth
            preferredWidth: defaultPageColumnWidth
        }
        // column #1
        PageColumn {
            fillWidth: true
        }
    },
    PageColumnsLayout {
        when: width >= 2*defaultPageColumnWidth && matrix.isLogged && mainLayout.updateInfosFinished === version
        // column #0
        PageColumn {
            minimumWidth: 0.5*defaultPageColumnWidth
            maximumWidth: defaultPageColumnWidth
            preferredWidth: 0.75*defaultPageColumnWidth
        }
        // column #1
        PageColumn {
            fillWidth: true
        }
    },
    PageColumnsLayout {
        when: true
        PageColumn {
            fillWidth: true
            minimumWidth: units.gu(10)
        }
    }
    ]

    // Wait for server answer dialog
    WaitDialog {
        id: waitDialog
    }
    ChatPage { id: chatPage }
    Connections {
        target: matrix
        onIsLoggedChanged: DefaultLayoutActions.init ()
        onBlockUIRequestChanged: matrix.blockUIRequest !== null ? PopupUtils.open ( waitDialog ) : function(){}
    }

    primaryPageSource: Qt.resolvedUrl( DefaultLayoutActions.getPrimaryPage () )

    signal init ()
    signal toChat ( var chatID )
    signal toChatInvitePage ( var chatID )

    onInit: DefaultLayoutActions.init ()
    onToChat: DefaultLayoutActions.toChat ( chatID )
    onToChatInvitePage: DefaultLayoutActions.toChat ( chatID, true )
}
