import QtQuick 2.9
import Ubuntu.Components 1.3
import Ubuntu.Content 1.3
import Ubuntu.Components.Popups 1.3
import "../components"
import "../scripts/MatrixNames.js" as MatrixNames

Item {

    id: contentHub
    property url uri: ""
    property var shareObject: null

    signal done ()
    signal copiedToClipboard ()

    Connections {
        target: ContentHub
        onShareRequested: startImport(transfer)
    }

    Component {
        id: shareDialog
        ContentShareDialog {
            Component.onDestruction: contentHub.done()
        }
    }

    Connections {
        target: UriHandler
        onOpened: openUri ( uris )
    }

    MimeData {
        id: mimeData
        text: ""
    }

    Component {
        id: contentItemComponent
        ContentItem { }
    }

    ContactImport { id: contactImport }

    function openUri ( uris ) {
        // no url
        if (uris.length === 0 ) return

        var uri = uris[0]
        uri = uri.replace("https://matrix.to/#/","fluffychat://")
        if ( uri.slice(0,14) === "fluffychat://@" ) {
            uri = uri.replace("fluffychat://","")
            MatrixNames.handleUserUri( uri )
        }
        else if ( uri.slice(0,14) === "fluffychat://#" ) {
            uri = uri.replace("fluffychat://","")
            mainLayout.toChat ( uri )
        }
        else if ( uri.slice(0,14) === "fluffychat://!" ) {
            uri = uri.replace("fluffychat://","")
            mainLayout.toChat ( uri )
        }
        else if ( uri.slice(0,14) === "fluffychat://+" ) {
            uri = uri.replace("fluffychat://","")
            bottomEdgePageStack.push ( Qt.resolvedUrl ("../pages/CommunityPage.qml" ), { activeCommunity: uri } )
        }
        else console.error("Unkown URI…", uri)
    }

    function openUrlExternally ( link ) {
        if ( link.indexOf("fluffychat://") !== -1 ) openUri ( [link] )
        else if ( link.indexOf("https://matrix.to/#/") !== -1 ) openUri ( [link] )
        else if ( link.indexOf("http") !== -1 ) Qt.openUrlExternally ( link )
        else Qt.openUrlExternally ( "http://" + link )
    }

    function toClipboard ( text ) {
        mimeData.text = text
        Clipboard.push( mimeData )
        toast.show ( i18n.tr ( "Copied to clipboard" ) )
    }

    function startImport ( transfer ) {
        console.log("NEW TRANSFER:",JSON.stringify(transfer))
        if ( transfer.contentType === ContentType.Links || transfer.contentType === ContentType.Text ) {
            mainLayout.removePages( mainLayout.primaryPage )
            contentHub.shareObject = transfer
        }
        else if ( transfer.contentType === ContentType.Contacts ) {
            for ( var i = 0; i < transfer.items.length; i++ ) {
                contactImport.mediaReceived ( String(transfer.items[i].url) )
            }
        }
        else toast.show (i18n.tr("Sorry. 😕 Sharing photos, videos or files is not yet supported…"))
    }

    function share(url, text, contentType) {
        uri = url
        var sharePopup = PopupUtils.open(shareDialog, contentHub, {"contentType" : contentType})
        sharePopup.items.push(contentItemComponent.createObject(contentHub, {"url" : uri, "text": text}))
    }

    function shareLink( url ) {
        share( url, url, ContentType.Links)
    }

    function shareText( text ) {
        share( "", text, ContentType.Text)
    }

    function sharePicture( url, title ) {
        share( url, title, ContentType.Pictures)
    }

    function shareAudio( url, title ) {
        share( url, title, ContentType.Music)
    }

    function shareVideo( url, title ) {
        share( url, title, ContentType.Videos)
    }

    function shareFile( url, title ) {
        share( url, title, ContentType.Documents)
    }

    function shareAll( url, title ) {
        share( url, title, ContentType.All)
    }

    function shareTextIntern ( text ) {
        mainLayout.removePages( mainLayout.primaryPage )
        bottomEdgePageStack.clear ()
        contentHub.shareObject = {
            items: [ contentItemComponent.createObject(contentHub, {"url" : "", "text": text}) ]
        }
    }

    function shareFileIntern ( event ) {
        mainLayout.removePages( mainLayout.primaryPage )
        bottomEdgePageStack.clear ()
        contentHub.shareObject = {
            matrixEvent: event
        }
    }

    function shareLinkIntern ( url ) {
        uri = url
        mainLayout.removePages( mainLayout.primaryPage )
        bottomEdgePageStack.clear ()
        contentHub.shareObject = {
            items: [ contentItemComponent.createObject(contentHub, {"url" : uri, "text": url}) ]
        }
    }

}
