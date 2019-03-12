// File: LoginPageActions.js
// Description: Actions for LoginPage.qml

function changeHomeServer ( homeserverInput, dialogue ) {
    domainChanged = true
    loginDomain = homeserverInput.displayText.toLowerCase()
    if ( homeserverInput.displayText === "" ) loginDomain = defaultDomain
    PopupUtils.close(dialogue)
}

function changeIDServer ( identityserverInput, dialogue ) {
    if ( identityserverInput.displayText === "" ) matrix.id_server = defaultIDServer
    else matrix.id_server = identityserverInput.displayText.toLowerCase()
    PopupUtils.close(dialogue)
}

function showCountryPicker () {
    var item = Qt.createComponent("../components/CountryPicker.qml")
    item.createObject( root, { })
}

function updateHomeServerByTextField ( displayText ) {
    if ( domainChanged ) return
    if ( displayText.indexOf ("@") !== -1 && !domainChanged ) {
        var usernameSplitted = displayText.substr(1).split ( ":" )
        loginDomain = usernameSplitted [1]
    }
}

function login () {
    if ( loginDomain === "" ) loginDomain = defaultDomain
    signInButton.enabled = false
    var username = loginTextField.displayText
    desiredUsername = username

    // Step 1: Transforming the username:
    // If it is a normal username, then use the current domain
    // If it is a matrix-id, then get the infos from this form:
    // @username:domain
    if ( username.indexOf ("@") !== -1 ) {
        var usernameSplitted = username.substr(1).split ( ":" )
        username = usernameSplitted [0]
        if ( !domainChanged ) loginDomain = usernameSplitted [1]
    }
    matrix.username = username
    matrix.server = loginDomain

    // Step 2: If there is no phone number, and the user is new then try to register the username
    if ( phoneTextField.displayText === "" && newHereCheckBox.checked ) register ( username )

    // Step 2.1: If there is no phone number and the user is not new, then check if user exists:
    else if  ( phoneTextField.displayText === "" ) {
        matrix.get( "/client/r0/register/available", {"username": username.toLowerCase() }, function ( response ) {
            if ( typeof response.available !== "boolean" ) toast.show (i18n.tr("Server %1 not found").arg(matrix.server))
            else if ( !response.available ) mainLayout.addPageToCurrentColumn ( loginPage, Qt.resolvedUrl("../pages/PasswordInputPage.qml") )
            else toast.show (i18n.tr("Username '%1' not found on %2").arg(username).arg(loginDomain))
        }, function ( response ) {
            if ( response.errcode === "M_USER_IN_USE" ) mainLayout.addPageToCurrentColumn ( loginPage, Qt.resolvedUrl("../pages/PasswordInputPage.qml") )
            else if ( response.error === "CONNERROR" ) toast.show (i18n.tr("😕 No connection…"))
            else toast.show ( response.error )
        }, 2)
    }

    // Step 3: Try to get the username via the phone number and login
    else {
        // Transform the phone number
        var phoneInput = phoneTextField.displayText.replace(/\D/g,'')
        if ( phoneInput.charAt(0) === "0" ) phoneInput = phoneInput.substr(1)
        phoneInput = matrix.countryTel + phoneInput

        // Step 3.1: Look for this phone number
        matrix.get ("/identity/api/v1/lookup", {
            "medium": "msisdn",
            "address": phoneInput
        }, function ( response ) {

            // Step 3.2: There is a registered Matrix ID. Go to the password input…
            if ( response.mxid ) {
                var splittedMxid = response.mxid.substr(1).split ( ":" )
                matrix.username = splittedMxid[0]
                matrix.server = splittedMxid[1]
                mainLayout.addPageToCurrentColumn ( loginPage, Qt.resolvedUrl("../pages/PasswordInputPage.qml") )
            }
            // Step 3.3.1: There is no registered Matrix ID. Try to register one…
            else {
                desiredPhoneNumber = phoneInput
                register ( username )
            }
        }, null, 2)
    }
    signInButton.enabled = loginTextField.displayText !== "" && loginTextField.displayText !== " "
}

function register ( username ) {
    matrix.get( "/client/r0/register/available", {"username": username.toLowerCase() }, function ( response ) {
        if ( response.available ) mainLayout.addPageToCurrentColumn ( loginPage, Qt.resolvedUrl("../pages/PasswordCreationPage.qml") )
        else toast.show (i18n.tr("Username is already taken"))
    }, function ( response ) {
        if ( response.errcode === "M_USER_IN_USE" ) toast.show (i18n.tr("Username is already taken"))
        else if ( response.error === "CONNERROR" ) toast.show (i18n.tr("😕 No connection…"))
        else toast.show ( response.error )
    }, 2)
}
