import QtQuick 2.0
import Ubuntu.Components 1.3
import Ubuntu.PushNotifications 0.1
import Qt.labs.settings 1.0

Item {

    id: pushClient

    property alias pushtoken: innerPushClient.token

    signal dismissNotification ( var tag )
    onDismissNotification: innerPushClient.clearPersistent ( tag )
    signal error ( var error )

    PushClient {
        id: innerPushClient

        property var errorReport: null
        readonly property string defaultPushUrl: "https://push.ubports.com:5003/_matrix/push/r0/notify"
        readonly property string defaultDeviceName: "FluffyChat %1 on Ubuntu Touch".arg(version)
        property string pushToken: ""
        property string pushUrl: ""
        property string pushDeviceName: ""

        onTokenChanged: {
            if ( !matrix.isLogged ) return
            // Set the pusher if it is not set
            updatePusher ()
        }


        function updatePusher () {
            if ( token !== "" && (pushToken !== token || pushUrl !== defaultPushUrl || pushDeviceName !== defaultDeviceName) ) {
                innerPushClient.setPusher ( true, function () {
                    pushToken = token
                    pushUrl = defaultPushUrl
                    pushDeviceName = defaultDeviceName
                }, function ( error ) {
                    console.warn( "ERROR:", JSON.stringify(error))
                    error ( error.error )
                } )
            }
        }

        function pusherror ( reason ) {
            console.warn("❌[Error] Push Notifications Error: ",reason)
            if ( reason === "bad auth" ) {
                errorReport = i18n.tr("Please log in to Ubuntu One to receive push notifications.")
                error ( errorReport )
            }
            else errorReport = reason
        }

        function newNotification ( message ) {
            //console.log("🔔[Push Notification]")
        }

        Component.onCompleted: {
            notificationsChanged.connect(newNotification)
            error.connect(pusherror)
        }


        // This function will toggle the push notifications. It will set or kill a
        // pusher with the pushkey of this device. Also it will reset one push rule,
        // to provide full functionality of notifications. Sometimes, other clients
        // like Riot web set push rules, which turns off all notifications.
        function setPusher ( intent, callback, error_callback ) {
            if ( intent && errorReport !== null ) {
                if ( error_callback ) error_callback ( {errcode: "NO_UBUNTUONE", error: errorReport} )
            }
            else if ( token === "" ) {
                if ( error_callback ) error_callback ( {errcode: "EMPTY_PUSHTOKEN", error: i18n.tr("Push notifications are turned off…")} )
            }
            else {
                var data = {
                    "app_display_name": "FluffyChat",
                    "app_id": appId,
                    "append": true,
                    "data": {
                        "url": defaultPushUrl
                    },
                    "device_display_name": defaultDeviceName,
                    "lang": "en",
                    "kind": intent ? "http" : null,
                    "profile_tag": "xxyyzz",
                    "pushkey": token
                }
                matrix.post ( "/client/r0/pushers/set", data, function() {
                    // This is a workaround for the problem with the riot web client, who turns off the push notifications sometimes
                    if ( intent ) matrix.put ( "/client/r0/pushrules/global/content/.m.rule.contains_user_name/enabled", { "enabled": true } )
                    callback ()
                }, error_callback, intent ? 1 : 2 )
            }
        }

        appId: "fluffychat.christianpauly_fluffychat"

    }


    Settings {
        property alias pushToken: innerPushClient.pushToken
        property alias pushUrl: innerPushClient.pushUrl
        property alias pushDeviceName: innerPushClient.pushDeviceName
    }

    Connections {
        target: matrix
        onIsLoggedChanged: {
            if ( matrix.isLogged ) innerPushClient.updatePusher ()
            else innerPushClient.pushToken = innerPushClient.pushUrl = innerPushClient.pushDeviceName = ""
        }
    }

}
