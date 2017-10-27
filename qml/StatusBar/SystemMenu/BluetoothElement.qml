/* @@@LICENSE
*
* Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
* Copyright (c) 2009-2013 LG Electronics, Inc.
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
import LuneOS.Bluetooth 0.1

Drawer {
    id: bluetoothMenu
    property int ident:        0
    property int internalIdent: 0

    property bool closeOnConnect: false
    property string deviceAddressInError: ""

    readonly property ListModel bluetoothList: BluetoothService.deviceModel

    // ------------------------------------------------------------
    // External interface to the Bluetooth Element is defined here:

    signal menuCloseRequest(int delayMs)
    signal menuOpened()
    signal menuClosed()
    signal onOffTriggered()
    signal prefsTriggered()
    signal itemSelected()

    property string bluetoothToggleStr:
        BluetoothService.isTurningOn ? "Turning on Bluetooth..." :
        BluetoothService.powered ? "Turn off Bluetooth" :
                                      "Turn on Bluetooth";
    property string bluetoothStateStr:
        BluetoothService.isTurningOn ? "INIT" :
        BluetoothService.powered ? "ON":"OFF";

    // ------------------------------------------------------------

    width: parent.width

    onDrawerOpened:  {
        closeOnConnect = false;
        menuOpened();
        BluetoothService.startDiscovery();
        resetStatusTimer.stop();
    }
    Connections {
        target: BluetoothService
        onPoweredChanged: {
            if(BluetoothService.powered) {
                if(bluetoothMenu.isOpen()) {
                    BluetoothService.startDiscovery();
                }
            }
        }
    }

    onDrawerClosed: {
        BluetoothService.stopDiscovery();
        menuClosed()
    }

    drawerHeader:
    MenuListEntry {
        selectable: bluetoothMenu.active
        content: Item {
                    width: parent.width;

                    Text{
                        id: bluetoothTitle
                        x: ident;
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Bluetooth";
                        color: bluetoothMenu.active ? "#FFF" : "#AAA";
                        font.bold: false;
                        font.pixelSize: FontUtils.sizeToPixels("medium") //18
                        font.family: "Prelude"
                    }

                    Spinner {
                        id: bluetoothSpinner
                        x: bluetoothTitle.width + Units.gu(2); 
                        y: Units.gu(-1.7) 
                        width: Units.gu(3.2)
                        height: Units.gu(3.2)
                        on: BluetoothService.isTurningOn && bluetoothMenu.isOpen();
                    }

                    Text {
                        id: bluetoothTitleState
                        x: bluetoothMenu.width - width - Units.gu(1.4); 
                        width: bluetoothMenu.width - bluetoothTitle.width - Units.gu(3.5)
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight;
                        anchors.verticalCenter: parent.verticalCenter
                        text: bluetoothMenu.bluetoothStateStr
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

        MenuDivider { id: separator }

        MenuListEntry {
            id: bluetoothOnOff
            selectable: true
            content: Text {
                         id: bluetoothOnOffText;
                         x: ident + internalIdent;
                         text: bluetoothMenu.bluetoothToggleStr;
                         color: "#FFF";
                         font.bold: false;
                         font.pixelSize: FontUtils.sizeToPixels("medium"); //18;
                         font.family: "Prelude"
                     }
            onAction: {
                if(BluetoothService.powered && !BluetoothService.isTurningOn)
                    menuCloseRequest(300);

                onOffTriggered()
            }
        }

        MenuDivider  { }

        ListView {
            id: bluetoothListView
            width: parent.width
            height: (bluetoothOnOff.height + separator.height) * bluetoothList.count
            interactive: false
            spacing: 0
            model: bluetoothList
            delegate: bluetoothListDelegate
        }

        MenuListEntry {
            selectable: true
            content: Text {
                x: ident + internalIdent;
                text: "Bluetooth Preferences";
                color: "#FFF";
                font.bold: false;
                font.pixelSize: FontUtils.sizeToPixels("medium"); //18;
                font.family: "Prelude";
            }
            onAction: {
                prefsTriggered();
                menuCloseRequest(300);
            }
        }
    }

    Component {
        id: bluetoothListDelegate
        Column {
            spacing: 0
            width: parent.width

            property BluetoothDevice delegateDevice: device

            MenuListEntry {
                id: entry
                selectable: true
                forceSelected: delegateDevice.connecting

                content: BluetoothEntry {
                            id: btDeviceData
                            x: ident + internalIdent;
                            width: bluetoothMenu.width-x;
                            name:         delegateDevice.name;
                            connected:    delegateDevice.connected;
                            connecting:   delegateDevice.connecting;
                            lastConnectFailed: delegateDevice.lastConnectFailed;
                         }

                onAction: {
                    if (BluetoothService.powered) {
                        console.log("Bluetooth Device Selected. Name = " + delegateDevice.name + ", connected = " + delegateDevice.connected + ", connecting = " + delegateDevice.connecting);
                        if(!delegateDevice.connected && !delegateDevice.connecting)
                            delegateDevice.connectDevice();
                        else {
                            delegateDevice.disconnectDevice();
                            // close whatever happens
                            menuCloseRequest(350);
                        }
                    }
                }
            }

            MenuDivider  { }

        }

    }

    Timer{
        id      : resetStatusTimer
        repeat  : false;
        running : false;

        onTriggered: resetEntryStatus()
    }
}

