import QtQuick 2.9
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3

/* =============================== MATRIX CONTROLLER ===============================

The matrix controller handles all requests to the matrix server. There are also
functions to login, logout and to autologin, when there are saved login
credentials
*/

Item {

    // The online status (bool)
    property var onlineStatus: false

    // The list of the current active requests, to prevent multiple same requests
    property var activeRequests: []


    // Login and set username, token and server! Needs to be done, before anything else
    function login ( newUsername, newPassword, newServer, newDeviceName, callback, error_callback) {

        settings.username = newUsername.toLowerCase()
        settings.server = newServer.toLowerCase()
        settings.deviceName = newDeviceName

        var data = {
            "initial_device_display_name": newDeviceName,
            "user": newUsername,
            "password": newPassword,
            "type": "m.login.password"
        }

        var onLogged = function ( response ) {
            settings.token = response.access_token
            settings.deviceID = response.device_id
            settings.username = (response.user_id.substr(1)).split(":")[0]
            settings.matrixid = response.user_id
            settings.server = newServer.toLowerCase()
            settings.deviceName = newDeviceName
            settings.dbversion = storage.version
            onlineStatus = true
            events.init ()
            if ( callback ) callback ( response )
        }

        var onError = function ( response ) {
            resetSettings ()
            if ( error_callback ) error_callback ( response )
        }
        xmlRequest ( "POST", data, "/client/r0/login", onLogged, error_callback, 2)
    }

    function register ( newUsername, newPassword, newServer, newDeviceName, callback, error_callback) {

        settings.username = newUsername.toLowerCase()
        settings.server = newServer.toLowerCase()
        settings.deviceName = newDeviceName

        var data = {
            "initial_device_display_name": newDeviceName,
            "username": newUsername,
            "password": newPassword
        }

        var onResponse = function ( response ) {
            // If error
            if ( response.errcode ) {
                if ( response.errcode !== "M_USER_IN_USE" ) resetSettings ()
                if ( error_callback ) error_callback ( response )
                return
            }

            // The homeserver requires additional authentication information.
            if ( response.flows ) {
                var forwarded = false
                for ( var i = 0; i < response.flows.length; i++ ) {

                    // If there is m.login.dummy, just retry the registration with
                    // the session id
                    if ( response.flows[i].stages[0] === "m.login.dummy" ) {
                        data.auth = {
                            "type": response.flows[i].stages[0],
                            "session": response.session
                        }
                        xmlRequest ( "POST", data, "/client/r0/register", function ( response ) {
                            settings.token = response.access_token
                            settings.deviceID = response.device_id
                            settings.username = (response.user_id.substr(1)).split(":")[0]
                            settings.matrixid = response.user_id
                            settings.server = newServer.toLowerCase()
                            settings.deviceName = newDeviceName
                            settings.dbversion = storage.version
                            onlineStatus = true
                            events.init ()
                            if ( callback ) callback ( response )
                        }, error_callback, 2 )
                        forwarded = true
                        break
                    }
                }

                // If there is no other choice, then the registration can not succeed
                if ( !forwarded ) throw ("ERROR")
            }

            // The account has been registered.
            else {
                settings.token = response.access_token
                settings.deviceID = response.device_id
                settings.username = (response.user_id.substr(1)).split(":")[0]
                settings.server = newServer.toLowerCase()
                settings.deviceName = newDeviceName
                settings.dbversion = storage.version
                onlineStatus = true
                events.init ()
                if ( callback ) callback ( response )
            }
        }

        xmlRequest ( "POST", data, "/client/r0/register", onResponse, onResponse, 2 )
    }

    function logout () {
        if ( events.syncRequest ) {
            events.abortSync = true
            events.syncRequest.abort ()
            events.abortSync = false
        }
        var callback = function () { post ( "/client/r0/logout", {}, reset, reset ) }
        pushclient.setPusher ( false, callback, callback )
    }


    function reset () {
        storage.drop ()
        onlineStatus = false
        resetSettings ()
        mainStack.clear ()
        mainStack.push(Qt.resolvedUrl("../pages/LoginPage.qml"))
    }


    function joinChat (chat_id) {
        showConfirmDialog ( i18n.tr("Do you want to join this chat?").arg(chat_id), function () {
            loadingScreen.visible = true
            matrix.post( "/client/r0/join/" + encodeURIComponent(chat_id), null, function ( response ) {
                loadingScreen.visible = true
                events.waitForSync()
                mainStack.toChat( response.room_id )
            }, null, 2 )
        } )

    }


    function resetSettings () {
        settings.username = settings.server = settings.token = settings.pushToken = settings.deviceID = settings.deviceName = settings.requestedArchive = settings.since = settings.matrixVersions = settings.matrixid = settings.lazy_load_members = undefined
    }


    function get ( action, data, callback, error_callback, priority ) {
        return xmlRequest ( "GET", data, action, callback, error_callback, priority )
    }

    function post ( action, data, callback, error_callback, priority ) {
        return xmlRequest ( "POST", data, action, callback, error_callback, priority )
    }

    function put ( action, data, callback, error_callback, priority ) {
        return xmlRequest ( "PUT", data, action, callback, error_callback, priority )
    }

    // Needs the name remove, because delete is reserved
    function remove ( action, file, callback, error_callback, priority ) {
        return xmlRequest ( "DELETE", file, action, callback, error_callback, priority )
    }

    function xmlRequest ( type, data, action, callback, error_callback, priority ) {

        if ( priority === undefined ) priority = 1

        // Check if the same request is actual sent
        var checksum = type + JSON.stringify(data) + action
        if ( activeRequests.indexOf(checksum) !== -1 ) return console.warn( "multiple request detected!" )
        else activeRequests.push ( checksum )

        var http = new XMLHttpRequest();
        var postData = {}
        var getData = ""

        if ( type === "GET" && data != null ) {
            for ( var i in data ) {
                getData += "&" + i + "=" + encodeURIComponent(data[i])
            }
            getData = "?" + getData.substr(1)
            //getData = getData.replace("")
        }
        else if ( data != null ) postData = data

        function Timer() {
            return Qt.createQmlObject("import QtQuick 2.0; Timer {}", root)
        }
        var timer = new Timer()

        // Is this a request for the matrix server or the identity server?
        // This defaults to the matrix homeserver
        var server = settings.server
        if ( action.substring(0,10) === "/identity/" ) server = settings.id_server

        // Calculate the action url
        var requestUrl = action + getData
        if ( action.indexOf ( "https://" ) === -1 ) {
            requestUrl = "https://" + server + "/_matrix" + requestUrl
        }

        // Build the request
        var longPolling = (data != null && data.timeout)
        var isSyncRequest = (action === "/client/r0/sync")
        http.open( type, requestUrl, true);
        http.timeout = defaultTimeout
        if ( !(server === settings.id_server && type === "GET") ) http.setRequestHeader('Content-type', 'application/json; charset=utf-8')
        if ( server === settings.server && settings.token ) http.setRequestHeader('Authorization', 'Bearer ' + settings.token);
        http.onreadystatechange = function() {
            if (http.readyState === XMLHttpRequest.DONE) {
                try {
                    var index = activeRequests.indexOf(checksum);
                    activeRequests.splice( index, 1 )
                    if ( !longPolling && priority > 0 ) progressBarRequests--
                    if ( priority > 1 ) waitDialogRequest = null
                    if ( progressBarRequests < 0 ) progressBarRequests = 0

                    if ( !timer.running ) throw( "CONNERROR" )
                    timer.stop ()

                    if ( http.responseText === "" ) throw( "CONNERROR" )

                    var responseType = http.getResponseHeader("Content-Type")
                    if ( responseType === "application/json" ) {
                        var response = JSON.parse(http.responseText)
                        if ( "errcode" in response || http.status !== 200 ) throw response
                        if ( callback ) callback( response )
                    }
                    else if ( responseType = "image/png" ) {
                        if ( callback ) callback( http.responseText )
                    }
                }
                catch ( error ) {
                    if ( !isSyncRequest ) console.error("There was an error: When calling ", type, requestUrl, " With data: ", JSON.stringify(data), " Error-Report: ", error, JSON.stringify(error))
                    if ( typeof error === "string" ) error = {"errcode": "ERROR", "error": error}
                    if ( error.errcode === "M_UNKNOWN_TOKEN" ) reset ()
                    if ( !error_callback && error.error === "CONNERROR" ) {
                        onlineStatus = false
                        toast.show (i18n.tr("😕 No connection..."))
                    }
                    else if ( error.errcode === "M_CONSENT_NOT_GIVEN") {
                        loadingScreen.visible = false
                        if ( "consent_uri" in error ) {
                            consentUrl = error.consent_uri
                            var item = Qt.createComponent("../components/ConsentViewer.qml")
                            item.createObject(mainStack.currentItem, { })
                        }
                        else toast.show ( error.error )
                    }
                    else if ( error_callback ) error_callback ( error )
                    else if ( error.errcode !== undefined && error.error !== undefined && priority > 0 ) toast.show ( error.error )
                }
            }
        }
        if ( !longPolling && priority > 0 ) {
            progressBarRequests++
        }
        if ( priority > 1 ) waitDialogRequest = http

        // Make timeout working in qml
        timer.stop ()
        timer.interval = (longPolling || isSyncRequest) ? longPollingTimeout*1.5 : defaultTimeout
        timer.repeat = false
        timer.triggered.connect(function () {
            if (http.readyState === XMLHttpRequest.OPENED) http.abort ()
        })
        timer.start();

        // Send the request now
        //console.log("[SEND]", requestUrl, JSON.stringify(postData))
        http.send( JSON.stringify( postData ) )

        return http
    }


    function load_binary_resource( url, callback ) {
        var oReq = new XMLHttpRequest();
        oReq.open("GET", url, true);
        oReq.onreadystatechange = function() {
            if ( oReq.readyState === XMLHttpRequest.DONE ) {
                console.log("Got file, transfering it now...")
                var str = oReq.response;
                var buf = new ArrayBuffer(str.length*2); // 2 bytes for each char
                var bufView = new Uint16Array(buf);
                for (var i=0, strLen=str.length; i<strLen; i++) {
                    bufView[i] = str.charCodeAt(i);
                }
                callback ( bufView );
            }
        };
        oReq.send();
    }


    function upload ( path, callback ) {
        console.log("Uploading:", path)
        load_binary_resource( path, function ( blob ) {
            console.log("Got blob ...")
            // Send the file to the server
            var requestUrl = "https://%1/_matrix/media/r0/upload".arg(settings.server)
            var http = new XMLHttpRequest();
            http.open( "POST", requestUrl, true);
            http.setRequestHeader('Authorization', 'Bearer ' + settings.token);
            http.setRequestHeader('Content-Type', 'image/png');
            http.onreadystatechange = function() {
                if ( http.readyState === XMLHttpRequest.DONE ) {
                    console.log ( JSON.parse(http.responseText) )
                    console.log ( http.responseText )
                }
            }
            http.send ( blob )
            console.log("blob sent...")
        } )
    }

}
