// File: PasswordCreationPageActions.js
// Description: Actions for PasswordCreationPage.qml

function register () {

    var registerSuccess = function () {
        var _root = root

        if ( desiredPhoneNumber !== null ) {
            root.firstSMSClientSecret = "SECRET:" + new Date().getTime()
            PopupUtils.open(enterFirstSMSToken)
            // Verify this address with this matrix id
            matrix.post ( "/client/r0/account/3pid/msisdn/requestToken", {
                client_secret: root.firstSMSClientSecret,
                country: matrix.countryCode,
                phone_number: desiredPhoneNumber,
                send_attempt: 1,
                id_server: matrix.id_server
            }, function ( response ) {
                if ( response.sid ) _root.firstSMSSid = response.sid
            }, function ( response ) {
                if ( response.sid ) _root.firstSMSSid = response.sid
            } )
        }
        else mainLayout.init ()
    }

    var registerError = function (error) {
        if ( error.errcode === "M_USER_IN_USE" ) toast.show (i18n.tr("Username already taken"))
        else if ( error.errcode === "M_INVALID_USERNAME" ) toast.show ( i18n.tr("The desired user ID is not a valid username") )
        else if ( error.errcode === "M_EXCLUSIVE" ) toast.show ( i18n.tr("The desired user ID is in the exclusive namespace claimed by an application service") )
        else toast.show ( i18n.tr("Could not register on %1…").arg((loginDomain || defaultDomain)) )
    }

    matrix.register ( desiredUsername.toLowerCase(), loginTextField.text, (loginDomain || defaultDomain), "UbuntuPhone", registerSuccess, registerError )
}


function toggleHide () {
    if ( loginTextField.echoMode === TextInput.Normal ) {
        loginTextField.echoMode = TextInput.Password
    }
    else {
        loginTextField.echoMode = TextInput.Normal
    }
    loginTextField.focus = true
}
