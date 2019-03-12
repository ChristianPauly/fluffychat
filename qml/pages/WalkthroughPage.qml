import QtQuick 2.9
import Ubuntu.Components 1.3
import "../components"

// Initial Walkthrough tutorial

Page {
    id: walkthroughPage
    anchors.fill: parent

    header: PageHeader {
        title: ""
        StyleHints {
            dividerColor: "#00000000"
            backgroundColor: "#00000000"
        }
    }

    Walkthrough {
        id: walkthrough
        anchors.fill: parent

        appName: "FluffyChat"

        onFinished: {
            walkthrough.visible = false
            mainLayout.walkthroughFinished = true
            mainLayout.updateInfosFinished = version
            init ()
        }

        model: [


        Component {
            id: slide1

            Item {
                id: slide1Container

                Image {
                    id: smileImage
                    anchors {
                        top: slide1Container.top
                        topMargin: units.gu(4)
                        horizontalCenter: slide1Container.horizontalCenter
                    }
                    height: (parent.height - introductionText.height - bodyText.contentHeight - 4.5*units.gu(4))
                    fillMode: Image.PreserveAspectFit
                    source: Qt.resolvedUrl("../../assets/sticker09.png")
                    asynchronous: true
                }

                Label {
                    id: introductionText
                    anchors {
                        bottom: bodyText.top
                        bottomMargin: units.gu(4)
                    }
                    elide: Text.ElideRight
                    fontSize: "x-large"
                    horizontalAlignment: Text.AlignHLeft
                    maximumLineCount: 2
                    text: i18n.tr("Welcome to FluffyChat")
                    width: units.gu(36)
                    wrapMode: Text.WordWrap
                }

                Label {
                    id: bodyText
                    anchors {
                        bottom: slide1Container.bottom
                        bottomMargin: units.gu(10)
                    }
                    fontSize: "large"
                    height: contentHeight
                    horizontalAlignment: Text.AlignHLeft
                    text: i18n.tr("Chat with your friends and join the community. You can use your phone number or a unique username to find friends.")
                    width: units.gu(36)
                    wrapMode: Text.WordWrap
                }
            }
        },


        Component {
            id: slide2

            Item {
                id: slide2Container

                Image {
                    id: smileImage
                    anchors {
                        top: slide2Container.top
                        topMargin: units.gu(4)
                        horizontalCenter: slide2Container.horizontalCenter
                    }
                    height: (parent.height - introductionText.height - bodyText.contentHeight - 4.5*units.gu(4))
                    fillMode: Image.PreserveAspectFit
                    source: Qt.resolvedUrl("../../assets/sticker08.png")
                    asynchronous: true
                }

                Label {
                    id: introductionText
                    anchors {
                        bottom: bodyText.top
                        bottomMargin: units.gu(4)
                    }
                    elide: Text.ElideRight
                    fontSize: "x-large"
                    horizontalAlignment: Text.AlignHLeft
                    maximumLineCount: 2
                    text: i18n.tr("Join the Matrix")
                    width: units.gu(36)
                    wrapMode: Text.WordWrap
                }

                Label {
                    id: bodyText
                    anchors {
                        bottom: slide2Container.bottom
                        bottomMargin: units.gu(10)
                    }
                    fontSize: "large"
                    height: contentHeight
                    horizontalAlignment: Text.AlignHLeft
                    text: i18n.tr("FluffyChat is compatible with other messengers like Riot, Fractal or uMatriks. You can also join IRC channels, participate in XMPP chats and bridge Telegram groups.")
                    width: units.gu(36)
                    wrapMode: Text.WordWrap
                }
            }
        },


        Component {
            id: slide3

            Item {
                id: slide3Container

                Image {
                    id: smileImage
                    anchors {
                        top: slide3Container.top
                        topMargin: units.gu(4)
                        horizontalCenter: slide3Container.horizontalCenter
                    }
                    height: (parent.height - introductionText.height - bodyText.contentHeight - 4.5*units.gu(4))
                    fillMode: Image.PreserveAspectFit
                    source: Qt.resolvedUrl("../../assets/sticker15.png")
                    asynchronous: true
                }

                Label {
                    id: introductionText
                    anchors {
                        bottom: bodyText.top
                        bottomMargin: units.gu(4)
                    }
                    elide: Text.ElideRight
                    fontSize: "x-large"
                    horizontalAlignment: Text.AlignHLeft
                    maximumLineCount: 2
                    text: i18n.tr("What's new in version %1?").arg(version)
                    width: units.gu(36)
                    wrapMode: Text.WordWrap
                }

                Label {
                    id: bodyText
                    anchors {
                        bottom: slide3Container.bottom
                        bottomMargin: units.gu(10)
                    }
                    fontSize: "large"
                    height: contentHeight
                    horizontalAlignment: Text.AlignHLeft
                    text: i18n.tr("Improved stability and performance, new translations, design changes, better tablet support and a lot of bugfixes.")
                    width: units.gu(36)
                    wrapMode: Text.WordWrap
                }
            }
        },



        Component {
            id: slide4
            Item {
                id: slide4Container

                Image {
                    id: smileImage
                    anchors {
                        top: slide4Container.top
                        topMargin: units.gu(4)
                        horizontalCenter: slide4Container.horizontalCenter
                    }
                    height: (parent.height - introductionText.height - finalMessage.contentHeight - continueButton.height - 4.5*units.gu(4))
                    visible: height > 0
                    fillMode: Image.PreserveAspectFit
                    source: Qt.resolvedUrl("../../assets/sticker12.png")
                    asynchronous: true
                }

                Label {
                    id: introductionText
                    anchors {
                        bottom: finalMessage.top
                        bottomMargin: units.gu(4)
                    }
                    elide: Text.ElideRight
                    fontSize: "x-large"
                    horizontalAlignment: Text.AlignHLeft
                    maximumLineCount: 2
                    text: i18n.tr("Community funded")
                    width: units.gu(36)
                    wrapMode: Text.WordWrap
                }

                Label {
                    id: finalMessage
                    anchors {
                        bottom: continueButton.top
                        bottomMargin: units.gu(7)
                    }
                    fontSize: "large"
                    horizontalAlignment: Text.AlignHLeft
                    text: i18n.tr("FluffyChat is open, nonprofit and cute. The development and servers is all community funded. You can donate to this project on <a href='https://www.patreon.com/bePatron?u=11123241'>Patreon</a> or <a href='https://liberapay.com/KrilleChritzelius/donate'>Liberapay</a>")
                    width: units.gu(36)
                    wrapMode: Text.WordWrap
                    linkColor: mainLayout.brightMainColor
                    textFormat: Text.StyledText
                    onLinkActivated: contentHub.openUrlExternally ( link )
                }

                Button {
                    id: continueButton
                    anchors {
                        bottom: slide4Container.bottom
                        bottomMargin: units.gu(3)
                        horizontalCenter: slide4Container.horizontalCenter
                    }
                    color: UbuntuColors.green
                    height: units.gu(5)
                    text: i18n.tr("Continue")
                    width: units.gu(36)

                    onClicked: walkthrough.finished()
                }
            }
        }
        ]
    }
}
