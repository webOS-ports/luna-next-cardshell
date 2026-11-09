/* @@@LICENSE
*
*      Copyright (c) 2009-2013 LG Electronics, Inc.
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*
* LICENSE@@@ */

import QtQuick 2.0
import LunaNext.Common 0.1
// Connman
import Connman 0.2

Drawer {
    id: wifiMenu
    property int ident:         0
    property int internalIdent: 0

    property alias isWifiOn: wifiList.powered
    readonly property string _wifiState: wifiList.powered ? "ON" : "OFF"
    property bool closeOnConnect: false

    TechnologyModel {
        id: wifiList
        name: "wifi"
    }

    /*
     * connman sends RequestInput to the agent of whoever called Connect. A
     * network with no saved passphrase is handed to the Wi-Fi app before
     * anything connects (see the delegate's onAction), so this only hears from
     * connman when a saved network wants something new - a changed
     * passphrase, say. This menu has no field to type it in: cancel at once
     * (an empty reply is net.connman.Agent.Error.Canceled), or connman keeps
     * the service mid-connect waiting for an answer and every tap in the app
     * gets InProgress. The app then connects itself and its agent asks.
     */
    UserAgent {
        id: connmanUserAgent
        objectName: "connmanUserAgent"
        onUserInputRequested: function(servicePath, fields) {
            connmanUserAgent.sendUserReply({});
            wifiMenu.userInputRequested(servicePath);
        }
    }

    // ------------------------------------------------------------
    // External interface to the WiFi Element is defined here:

    signal menuCloseRequest(int delayMs)
    signal menuOpened()
    signal menuClosed()
    signal onOffTriggered()
    signal prefsTriggered()
    signal userInputRequested(string servicePath)
    signal detailsRequested(string servicePath)
    // ------------------------------------------------------------


    width: parent.width

    onDrawerOpened: menuOpened()
    onDrawerClosed: menuClosed()

    onDrawerFinishedClosingAnimation: {
        clearWifiList();
    }

    drawerHeader:
    MenuListEntry {
        selectable: wifiMenu.active
        content: Item {
                    width: parent.width;

                    Text{
                        id: wifiTitle
                        x: ident;
                        anchors.verticalCenter: parent.verticalCenter
                        // text: runtime.getLocalizedString("Wi-Fi");
                        text: "Wi-Fi"
                        color: wifiMenu.active ? "#FFF" : "#AAA";
                        font.bold: false;
                        font.pixelSize: FontUtils.sizeToPixels("medium") // 18
                        font.family: "Prelude"
                    }

                    Spinner {
                        id: wifiSpinner
                        width: Units.gu(3.2)
                        height: Units.gu(3.2)
                        x: wifiTitle.width + Units.gu(1.8); 
                        anchors.verticalCenter: parent.verticalCenter
                        on: wifiList.scanning
                    }

                    Text {
                        id: wifiTitleState
                        x: wifiMenu.width - width - Units.gu(1.4); 
                        anchors.verticalCenter: parent.verticalCenter
                        //text: runtime.getLocalizedString("init");
                        text: _wifiState
                        width: wifiMenu.width - wifiTitle.width - Units.gu(6.0)
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight;
                        color: "#AAA";
                        font.pixelSize: FontUtils.sizeToPixels("small") //13
                        font.family: "Prelude"
                        font.capitalization: Font.AllUppercase
                    }
                }
    }

    drawerBody:
    Column {
        spacing: 0
        width: parent.width

        MenuDivider  { id: separator }

        MenuListEntry {
            id: wifiOnOff
            selectable: true
            content: Text {  id: wifiOnOffText;
                             x: ident + internalIdent;
                             //text: isWifiOn ? runtime.getLocalizedString("Turn off WiFi") : runtime.getLocalizedString("Turn on WiFi");
                             text: isWifiOn ? "Turn off WiFi" : "Turn on WiFi"
                             color: "#FFF";
                             font.bold: false;
                             font.pixelSize: FontUtils.sizeToPixels("medium") //18
                             font.family: "Prelude"
                         }

            onAction: {
                isWifiOn = !isWifiOn
                if(!isWifiOn) {
                    menuCloseRequest(300);
                } else {
                    closeOnConnect = true;
                }
            }
        }

        MenuDivider {}

        Repeater {
            id: wifiListView
            width: parent.width
            model: wifiList
            delegate: wifiListDelegate
        }

        MenuListEntry {
            selectable: true
            content: Text {
                x: ident + internalIdent
                //text: runtime.getLocalizedString("Wi-Fi Preferences")
                text: "Wi-Fi Preferences"
                color: "#FFF"; font.bold: false; font.pixelSize: FontUtils.sizeToPixels("medium"); font.family: "Prelude"}
                //color: "#FFF"; font.bold: false; font.pixelSize: 18; font.family: "Prelude"}
            onAction: {
                prefsTriggered()
                menuCloseRequest(300);
            }
        }
    }

    Component {
        id: wifiListDelegate
        Column {
            spacing: 0
            width: parent.width

            property NetworkService delegateService: modelData

            Connections {
                target: delegateService
                function onConnectedChanged() {
                    if(delegateService.connected && closeOnConnect) {
                        menuCloseRequest(1000);
                        closeOnConnect = false;
                    }
                }
            }

            MenuListEntry {
                id: entry
                selectable: true
                forceSelected: delegateService.connected

                content: WifiEntry {
                            id: wifiNetworkData
                            x: ident + internalIdent;
                            width: wifiMenu.width-x;
                            name:         delegateService.name;
                            strength:     delegateService.strength;
                            securityType: delegateService.securityType;
                            status:       delegateService.state;
                            connected:    delegateService.connected;
                         }
                onAction: {
                    if(delegateService.connected) {
                        delegateService.requestDisconnect();
                    }
                    else if (delegateService.securityType !== NetworkService.SecurityNone &&
                             delegateService.securityType !== NetworkService.SecurityUnknown &&
                             !delegateService.favorite) {
                        // Secured and never joined: the passphrase is asked for
                        // by the Wi-Fi app, which connects to the network itself
                        // so connman's request goes to its agent.
                        wifiMenu.userInputRequested(delegateService.path);
                    }
                    else {
                        delegateService.requestConnect();
                    }

                    menuCloseRequest(300);
                    closeOnConnect = true;
                }
                // As in the Wi-Fi app: touch and hold for the network's details.
                onHeld: {
                    wifiMenu.detailsRequested(delegateService.path);
                    menuCloseRequest(300);
                }
            }

            MenuDivider {}
        }

    }

    onMenuOpened: {
        closeOnConnect = false;
        if(isWifiOn) {
            wifiList.requestScan();
        }
    }

    onMenuClosed: {
        closeOnConnect = false;
    }
}

