import QtQuick 2.9
import Ubuntu.Components 1.3
import Ubuntu.Content 1.3
import Ubuntu.Components.Popups 1.3
import "../components"

Item {

    id: shareController
    property url uri: ""

    signal done ()

    Connections {
        target: ContentHub
        onShareRequested: startImport(transfer)
    }

    Component {
        id: shareDialog
        ContentShareDialog {
            Component.onDestruction: shareController.done()
        }
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

    function toClipboard ( text ) {
        mimeData.text = text
        Clipboard.push( mimeData )
    }

    function startImport ( transfer ) {
        console.log("NEW TRANSFER:",JSON.stringify(transfer))
        if ( transfer.contentType === ContentType.Links || transfer.contentType === ContentType.Text ) {
            mainStack.toStart()
            shareObject = transfer
        }
        else if ( transfer.contentType === ContentType.Contacts ) {
            for ( var i = 0; i < transfer.items.length; i++ ) {
                contactImport.mediaReceived ( String(transfer.items[i].url) )
            }
        }
        else toast.show (i18n.tr("We are sorry. 😕 Sharing photos, videos or files is not yet supported..."))
    }

    function share(url, text, contentType) {
        uri = url
        var sharePopup = PopupUtils.open(shareDialog, shareController, {"contentType" : contentType})
        sharePopup.items.push(contentItemComponent.createObject(shareController, {"url" : uri, "text": text}))
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
        mainStack.toStart()
        shareObject = {
            items: [ contentItemComponent.createObject(shareController, {"url" : "", "text": text}) ]
        }
    }

    function shareFileIntern ( event ) {
        mainStack.toStart()
        shareObject = {
            matrixEvent: event
        }
    }

    function shareLinkIntern ( url ) {
        uri = url
        mainStack.toStart()
        shareObject = {
            items: [ contentItemComponent.createObject(shareController, {"url" : uri, "text": url}) ]
        }
    }

}
