// File: SettingsPageActions.js
// Description: Actions for SettingsPage.qml

function changeBackground ( mediaUrl ) {
    mainLayout.chatBackground = mediaUrl
}

function updateAvatar ( type, chat_id, eventType, eventContent ) {
    if ( type === "m.room.member" && eventContent.sender === matrix.matrixid ) {
        var rs = storage.query ( "SELECT avatar_url, displayname FROM Users WHERE matrix_id=?", [ matrix.matrixid ] )
        if ( rs.rows.length > 0 ) {
            var displayname = rs.rows[0].displayname !== "" ? rs.rows[0].displayname : matrix.matrixid
            avatarImage.name = displayname
            avatarImage.mxc = rs.rows[0].avatar_url
            hasAvatar = (rs.rows[0].avatar_url !== "" && rs.rows[0].avatar_url !== null)
            header.title = i18n.tr('Settings for %1').arg( displayname )
        }
    }
}


function getProfileInfo () {
    var rs = storage.query ( "SELECT avatar_url, displayname FROM Users WHERE matrix_id=?", [ matrix.matrixid ] )
    if ( rs.rows.length > 0 ) {
        displayname = rs.rows[0].displayname !== "" ? rs.rows[0].displayname : matrix.matrixid
        avatarImage.mxc = rs.rows[0].avatar_url
    }
}


function removeBackground () {
    mainLayout.chatBackground = undefined
    toast.show ( i18n.tr("Background removed") )
}
