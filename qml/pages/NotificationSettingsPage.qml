import QtQuick 2.9
import QtQuick.Layouts 1.1
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3
import "../components"
import "../scripts/NotificationSettingsPageActions.js" as PageActions

Page {
    id: notificationSettingsPage
    anchors.fill: parent

    header: PageHeader {
        title: i18n.tr('Receive notifications for…')
    }

    ScrollView {

        id: scrollView
        width: parent.width
        height: parent.height - header.height
        anchors.top: header.bottom
        contentItem: Column {
            width: notificationSettingsPage.width
            id: notificationSettingsList
            property var enabled: false
            opacity: enabled ? 1 : 0.5

            SettingsListSwitch {
                name: i18n.tr("Common messages")
                id: mrule_message
                icon: "message"
                isEnabled: notificationSettingsList.enabled
                onSwitching: function () {
                    if ( isEnabled ) PageActions.changeRule ( ".m.rule.message", isChecked, "underride" )
                }
            }

            SettingsListSwitch {
                name: i18n.tr("Messages from single chats")
                id: mrule_room_one_to_one
                icon: "contact"
                isEnabled: notificationSettingsList.enabled
                onSwitching: function () {
                    if ( isEnabled ) PageActions.changeRule ( ".m.rule.room_one_to_one", isChecked, "underride" )
                }
            }

            SettingsListSwitch {
                name: i18n.tr("Mention my display name")
                id: mrule_contains_display_name
                icon: "crop"
                isEnabled: notificationSettingsList.enabled
                onSwitching: function () {
                    if ( isEnabled ) PageActions.changeRule ( ".m.rule.contains_display_name", isChecked, "override" )
                }
            }

            SettingsListSwitch {
                name: i18n.tr("Mention my user name")
                id: mrule_contains_user_name
                icon: "account"
                isEnabled: notificationSettingsList.enabled
                onSwitching: function () {
                    if ( isEnabled ) PageActions.changeRule ( ".m.rule.contains_user_name", isChecked, "default" )
                }
            }

            SettingsListSwitch {
                name: i18n.tr("Invitations for me")
                id: mrule_invite_for_me
                icon: "contact-new"
                isEnabled: notificationSettingsList.enabled
                onSwitching: function () {
                    if ( isEnabled ) PageActions.changeRule ( ".m.rule.invite_for_me", isChecked, "override" )
                }
            }

            SettingsListSwitch {
                name: i18n.tr("Chat member changes")
                id: mrule_member_event
                icon: "contact-group"
                isEnabled: notificationSettingsList.enabled
                onSwitching: function () {
                    if ( isEnabled ) PageActions.changeRule ( ".m.rule.member_event", isChecked, "override" )
                }
            }

            SettingsListSwitch {
                name: i18n.tr("Messages from bots")
                id: mrule_suppress_notices
                icon: "computer-symbolic"
                isEnabled: notificationSettingsList.enabled
                onSwitching: function () {
                    if ( isEnabled ) PageActions.changeRule ( ".m.rule.suppress_notices", !isChecked, "override" )
                }
            }

            Component.onCompleted: PageActions.getRules ()

        }
    }
}
