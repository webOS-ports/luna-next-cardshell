/*
 * Copyright (C) 2026 Herman van Hazendonk <github.com@herrie.org>
 *
 * QML rework of the "New Device Menu" patch for legacy webOS by
 * Garrett Downs (https://github.com/garredow/webos-patches): the
 * tree-based system menu is replaced by a tabbed interface with a
 * date header, a row of app-icon tabs and one pane per tab.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>
 */

import QtQuick 2.5
import QtQuick.Window 2.2
import LuneOS.Service 1.0
import LunaNext.Common 0.1
import LunaNext.Shell 0.1
// Connman
import Connman 0.2
// LuneOS Bluetooth wrapper
import LuneOS.Bluetooth 0.2
import "../../Connectors"

Item {
    id: deviceMenu

    // The legacy patch showed a 306px wide, max 413px tall popup on a
    // 320x480 screen: almost the full screen width, centered, with a
    // small margin on either side.
    property int  preferredWidth: Units.gu(40)
    property int  maxHeight: Math.min(Units.gu(45), Screen.height - Units.gu(6))
    property int  ident: Units.gu(1.8)
    property int  subIdent: Units.gu(2)
    property int  dividerWidthOffset: Units.gu(0.7)
    property bool flickableOverride: false

    // Tells the StatusBar to center the menu instead of docking it to
    // the right edge like the classic system menu.
    property bool centered: true
    property int  edgeOffset: 0
    property bool visibleBeforeLock: false

    // Tab memory: the menu keeps the last opened tab as long as the
    // shell lives, like the original patch kept it in a cookie.
    property string currentTab: "wifi"
    // Order used by the edge gesture bars for cycling through tabs.
    property var tabOrder: ["wifi", "bluetooth", "gps", "vol", "bright", "phone"]

    width: Math.min(preferredWidth, Screen.width - Units.gu(1.4))
    height: maxHeight
    state: "hidden"

    // ------------------------------------------------------------
    // External interface, kept identical to SystemMenu.qml so the
    // StatusBar can load either implementation.

    signal showPowerMenu()
    signal closeSystemMenu()
    signal airplaneModeTriggered()
    signal rotationLockTriggered(bool isLocked)
    signal muteToggleTriggered(bool isMuted)

    function isVisible() {
        return state === "visible";
    }

    function toggleState() {
        if (state === "hidden")
            state = "visible";
        else if (state === "visible")
            state = "hidden";
    }

    function setRotationLockText(newText, showLocked) { }
    function setMuteControlText(newText, showMuteOn) { }
    function setAirplaneModeStatus(newText, state) { }
    function updateChangedFields() { }
    function flagMenuReset() { }

    function resetMenu() {
        networkSubMenuOpen = false;
    }

    // ------------------------------------------------------------

    function selectTab(name) {
        if (currentTab === name)
            currentTab = ""; // tapping the active tab collapses its pane
        else
            currentTab = name;
        networkSubMenuOpen = false;
    }

    function cycleTab(step) {
        var index = tabOrder.indexOf(currentTab);
        if (index < 0)
            index = 0;
        else
            index = (index + step + tabOrder.length) % tabOrder.length;
        currentTab = tabOrder[index];
        networkSubMenuOpen = false;
    }

    // ------------------------------------------------------------
    // Service connections and state

    property bool gpsOn: false
    property bool networkLocationOn: false
    property bool flashlightOn: false
    property bool flashlightAvailable: false
    property bool networkSubMenuOpen: false
    // Raw telephonyd radio access mode: any, gsm, umts, lte or unknown when
    // the modem has no RadioSettings interface to ask.
    property string dataNetworkMode: "unknown"
    property string mediaSoundOutput: "pcm_output"

    TelephonyService {
        id: telephonyServiceConnector
    }

    WanService {
        id: wanService
    }

    TechnologyModel {
        id: wifiList
        name: "wifi"
    }

    TechnologyModel {
        id: cellularTechnology
        name: "cellular"
    }

    BluetoothDevicesModel {
        id: bluetoothList
        filterRole: 256 + 109 /*PairedRole*/
        filterRegularExpression: /true/
    }

    UserAgent {
        id: connmanUserAgent
        onUserInputRequested: {
            // Delegate password entry etc. to the wifi prefs app
            var target = {};
            target["servicePath"] = servicePath;
            launcherInstance.launchApplication("org.webosports.app.settings.wifi",{"target":target});
            closeMenuTimer.interval = 300;
            closeMenuTimer.start();
        }
    }

    LunaService {
        id: service
        name: "com.webos.surfacemanager-cardshell"
        onInitialized: {
            // Media volume, kept in sync the same way VolumeElement does it.
            service.subscribe("luna://com.webos.service.audio/master/getVolume",
                 JSON.stringify({"subscribe": true}),
                 function(message) {
                     var payload = JSON.parse(message.payload);
                     var response = payload.hasOwnProperty("volumeStatus") ? payload.volumeStatus : payload;
                     if (response.hasOwnProperty("soundOutput") && response.soundOutput.length > 0)
                         deviceMenu.mediaSoundOutput = response.soundOutput;
                     if (response.hasOwnProperty("volume"))
                         mediaVolumeEntry.sliderValue = response.volume / 100;
                 },
                 function(error) {
                     console.log("Could not retrieve audio: " + error);
                 });

            refreshStatus();
        }
    }

    /*
     * torchd is not installed on every LuneOS device and it can start after the
     * shell does, so the subscription is made whenever it appears on the bus
     * instead of once at startup: subscribing at startup to a service that is
     * not there errors out and never retries, which left the entry reading
     * "Unavailable" for the rest of the session even once torchd was up.
     *
     * Subscribed rather than polled: torchd posts on every change, and the
     * torch can go off without us asking - it does on service stop.
     */
    ServiceStatus {
        serviceName: "org.webosports.service.torch"

        onConnected: {
            service.subscribe("luna://org.webosports.service.torch/getStatus",
                 JSON.stringify({"subscribe": true}),
                 function(message) {
                     var response = JSON.parse(message.payload);
                     if (response.hasOwnProperty("available"))
                         deviceMenu.flashlightAvailable = response.available;
                     if (response.hasOwnProperty("on"))
                         deviceMenu.flashlightOn = response.on;
                 },
                 function(error) {
                     // Present but refusing to answer: no torch on this device.
                     deviceMenu.flashlightAvailable = false;
                 });
        }

        onDisconnected: {
            deviceMenu.flashlightAvailable = false;
            deviceMenu.flashlightOn = false;
        }
    }

    // Everything without a subscription gets re-queried when the menu shows up.
    function refreshStatus() {
        service.call("luna://com.palm.display/control/getProperty",
                     JSON.stringify({"properties":["maximumBrightness"]}),
                     function(message) {
                         var response = JSON.parse(message.payload);
                         if (!response.maximumBrightness)
                             return;
                         var newValue = response.maximumBrightness / 100;
                         brightnessEntry.sliderValue = Math.max(0.0, Math.min(newValue, 1.0));
                     },
                     function(error) { });

        // com.palm.location resolves to com.webos.service.location, but only the
        // OSE API is actually there: getUseGps/getLocationServicePrefs are
        // legacy methods that answer "Unknown method", so these read nothing and
        // both toggles came up showing whatever they defaulted to. The OSE
        // service models the same two things as handlers - "gps" and "network" -
        // queried with getState.
        service.call("luna://com.webos.service.location/getState",
                     JSON.stringify({"Handler": "gps"}),
                     function(message) {
                         var response = JSON.parse(message.payload);
                         if (response.hasOwnProperty("state"))
                             deviceMenu.gpsOn = !!response.state;
                     },
                     function(error) { });

        service.call("luna://com.webos.service.location/getState",
                     JSON.stringify({"Handler": "network"}),
                     function(message) {
                         var response = JSON.parse(message.payload);
                         if (response.hasOwnProperty("state"))
                             deviceMenu.networkLocationOn = !!response.state;
                     },
                     function(error) { });

        service.call("luna://com.palm.audio/ringtone/getVolume", "{}",
                     function(message) {
                         var response = JSON.parse(message.payload);
                         if (response.hasOwnProperty("volume"))
                             ringtoneVolumeEntry.sliderValue = response.volume / 100;
                     },
                     function(error) { });

        service.call("luna://com.palm.audio/system/getVolume", "{}",
                     function(message) {
                         var response = JSON.parse(message.payload);
                         if (response.hasOwnProperty("volume"))
                             systemVolumeEntry.sliderValue = response.volume / 100;
                     },
                     function(error) { });

        // telephonyd answers with the mode strings it also takes back in
        // ratSet, "lte" among them; mapping anything that is not gsm or umts
        // onto "AUTO" claimed the radio was unrestricted when it was pinned to
        // LTE, and hid the fact that a modem without RadioSettings reports
        // "unknown" and cannot be set at all.
        service.call("luna://com.palm.telephony/ratQuery", "{}",
                     function(message) {
                         var response = JSON.parse(message.payload);
                         if (response.extended && response.extended.mode)
                             deviceMenu.dataNetworkMode = response.extended.mode;
                     },
                     function(error) { });
    }

    function dataNetworkModeLabel(mode) {
        switch (mode) {
        case "any":  return "Auto";
        case "gsm":  return "2G";
        case "umts": return "3G";
        case "lte":  return "4G";
        default:     return "Unknown";
        }
    }

    function setDataNetworkMode(mode) {
        service.call("luna://com.palm.telephony/ratSet",
                     JSON.stringify({"mode": mode}),
                     function(message) { refreshStatus(); },
                     function(error) { refreshStatus(); });
        networkSubMenuOpen = false;
    }

    // ------------------------------------------------------------
    // Visuals

    BorderImage {
        source: "../../images/menu-dropdown-bg.png"
        width: parent.width;
        height: Math.min(deviceMenu.height, (mainMenu.height + clipRect.anchors.topMargin + clipRect.anchors.bottomMargin));
        border { left: 30; top: 10; right: 30; bottom: 30 }
    }

    Rectangle { // clipping rect inside the menu border
        id: clipRect
        anchors.fill: parent
        color: "transparent"
        clip: true
        anchors.leftMargin: Units.gu(0.7)
        anchors.topMargin: 0
        // need to be in pixels due to border
        anchors.bottomMargin: 14
        anchors.rightMargin: Units.gu(0.7)

        Flickable {
            id: flickableArea
            width: mainMenu.width;
            height: Math.min(deviceMenu.height - clipRect.anchors.topMargin - clipRect.anchors.bottomMargin, mainMenu.height);
            contentWidth: mainMenu.width; contentHeight: mainMenu.height;
            interactive: !flickableOverride

            Column {
                id: mainMenu
                spacing: 0
                width: clipRect.width

                // ---- Date header ----
                MenuListEntry {
                    selectable: false
                    height: Units.gu(3)
                    menuPosition: 1 // top

                    Timer {
                        interval: 30000
                        repeat: true
                        running: deviceMenu.visible
                        onTriggered: dateText.text = Qt.formatDate(new Date, "ddd MMMM d, yyyy")
                    }

                    content: Text {
                        id: dateText
                        width: mainMenu.width
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.formatDate(new Date, "ddd MMMM d, yyyy")
                        color: "#FFF"
                        font.bold: false
                        font.pixelSize: FontUtils.sizeToPixels("medium")
                        font.family: "Prelude"
                    }
                }

                // ---- Tab bar ----
                Item {
                    id: menuTabs
                    width: mainMenu.width
                    height: Units.gu(4.8)

                    Row {
                        anchors.centerIn: parent
                        spacing: Units.gu(0.6)

                        Repeater {
                            model: [
                                { tab: "wifi",      icon: "tab-wifi.png" },
                                { tab: "bluetooth", icon: "tab-bluetooth.png" },
                                { tab: "gps",       icon: "tab-location.png" },
                                { tab: "vol",       icon: "tab-sound.png" },
                                { tab: "bright",    icon: "tab-screen.png" },
                                { tab: "phone",     icon: "tab-phone.png" }
                            ]

                            delegate: Image {
                                width: Units.gu(3.6)
                                height: Units.gu(3.6)
                                anchors.verticalCenter: parent.verticalCenter
                                source: "../../images/statusbar/devicemenu/" + modelData.icon
                                mipmap: true
                                opacity: currentTab === modelData.tab ? 1.0 : 0.3

                                Behavior on opacity { NumberAnimation { duration: 100 } }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -Units.gu(0.3)
                                    onClicked: selectTab(modelData.tab)
                                }
                            }
                        }
                    }
                }

                // ---- Wi-Fi tab ----
                Column {
                    id: wifiTab
                    spacing: 0
                    width: mainMenu.width
                    visible: currentTab === "wifi"

                    NewMenuToggleEntry {
                        text: "Wi-Fi"
                        statusText: wifiList.powered ? "On" : "Off"
                        // ConnMan refuses to power a technology up while
                        // offline mode is being applied, so do not offer it.
                        active: !airplaneModeService.inProgress
                        showSpinner: true
                        spinning: wifiList.scanning
                        onAction: {
                            wifiList.powered = !wifiList.powered;
                            if (wifiList.powered)
                                wifiList.requestScan();
                        }
                    }

                    MenuDivider { widthOffset: dividerWidthOffset }

                    Repeater {
                        id: wifiListView
                        width: parent.width
                        model: wifiList
                        delegate: wifiListDelegate
                    }

                    NewMenuToggleEntry {
                        text: "Wi-Fi Preferences"
                        onAction: {
                            launcherInstance.launchApplication("org.webosports.app.settings.wifi",{});
                            closeMenuTimer.interval = 300;
                            closeMenuTimer.start();
                        }
                    }
                }

                // ---- Bluetooth tab ----
                Column {
                    id: bluetoothTab
                    spacing: 0
                    width: mainMenu.width
                    visible: currentTab === "bluetooth"

                    NewMenuToggleEntry {
                        text: "Bluetooth"
                        statusText: BluetoothManager.bluetoothOperational ? "On" :
                                    BluetoothManager.initializing ? "Init" : "Off"
                        active: !airplaneModeService.inProgress
                        showSpinner: true
                        spinning: !BluetoothManager.bluetoothOperational && BluetoothManager.powered
                        onAction: {
                            BluetoothManager.powered = !BluetoothManager.powered;
                        }
                    }

                    MenuDivider { widthOffset: dividerWidthOffset }

                    Repeater {
                        id: bluetoothListView
                        width: parent.width
                        model: bluetoothList
                        delegate: bluetoothListDelegate
                    }

                    NewMenuToggleEntry {
                        text: "Bluetooth Preferences"
                        onAction: {
                            launcherInstance.launchApplication("org.webosports.app.settings.bluetooth",{});
                            closeMenuTimer.interval = 300;
                            closeMenuTimer.start();
                        }
                    }
                }

                // ---- Location tab ----
                Column {
                    id: gpsTab
                    spacing: 0
                    width: mainMenu.width
                    visible: currentTab === "gps"

                    NewMenuToggleEntry {
                        text: "GPS"
                        statusText: gpsOn ? "On" : "Off"
                        onAction: {
                            gpsOn = !gpsOn;
                            service.call("luna://com.webos.service.location/setState",
                                         JSON.stringify({"Handler": "gps", "state": gpsOn}),
                                         function(message) { }, function(error) { });
                        }
                    }

                    MenuDivider { widthOffset: dividerWidthOffset }

                    NewMenuToggleEntry {
                        // Named for what it does rather than for who used to
                        // provide it: this is the location service's "network"
                        // handler, position derived from WiFi and cell rather
                        // than from the GNSS chip. Legacy webOS called the same
                        // switch "Google Services" because Google supplied that
                        // lookup; nothing here goes to Google any more.
                        text: "Network Location"
                        statusText: networkLocationOn ? "On" : "Off"
                        onAction: {
                            networkLocationOn = !networkLocationOn;
                            service.call("luna://com.webos.service.location/setState",
                                         JSON.stringify({"Handler": "network", "state": networkLocationOn}),
                                         function(message) { }, function(error) { });
                        }
                    }

                    MenuDivider { widthOffset: dividerWidthOffset }

                    NewMenuToggleEntry {
                        text: "Location Preferences"
                        onAction: {
                            launcherInstance.launchApplication("org.webosports.app.settings.location",{});
                            closeMenuTimer.interval = 300;
                            closeMenuTimer.start();
                        }
                    }
                }

                // ---- Volume tab ----
                Column {
                    id: volTab
                    spacing: 0
                    width: mainMenu.width
                    visible: currentTab === "vol"

                    NewMenuSliderEntry {
                        id: ringtoneVolumeEntry
                        label: "Ringtone"
                        onAdjusted: {
                            service.call("luna://com.palm.audio/ringtone/setVolume",
                                         JSON.stringify({"volume": Math.floor(value * 100)}),
                                         function(message) { }, function(error) { });
                        }
                        onFlickOverride: flickableOverride = override
                    }

                    MenuDivider { widthOffset: dividerWidthOffset }

                    NewMenuSliderEntry {
                        id: mediaVolumeEntry
                        label: "Media"
                        onAdjusted: {
                            // audiod requires soundOutput here (REQUIRED_2 with volume).
                            service.call("luna://com.webos.service.audio/master/setVolume",
                                         JSON.stringify({"soundOutput": deviceMenu.mediaSoundOutput,
                                                         "volume": Math.floor(value * 100)}),
                                         function(message) { }, function(error) { });
                        }
                        onFlickOverride: flickableOverride = override
                    }

                    MenuDivider { widthOffset: dividerWidthOffset }

                    NewMenuSliderEntry {
                        id: systemVolumeEntry
                        label: "System"
                        onAdjusted: {
                            service.call("luna://com.palm.audio/system/setVolume",
                                         JSON.stringify({"volume": Math.floor(value * 100)}),
                                         function(message) { }, function(error) { });
                        }
                        onFlickOverride: flickableOverride = override
                    }
                }

                // ---- Screen tab ----
                Column {
                    id: brightTab
                    spacing: 0
                    width: mainMenu.width
                    visible: currentTab === "bright"

                    NewMenuSliderEntry {
                        id: brightnessEntry
                        label: "Brightness"
                        active: Settings.hasBrightnessControl
                        onAdjusted: {
                            service.call("luna://com.palm.display/control/setProperty",
                                         JSON.stringify({"maximumBrightness": Math.floor(value * 100)}),
                                         function(message) { }, function(error) { });
                        }
                        onFlickOverride: flickableOverride = override
                    }

                    MenuDivider { widthOffset: dividerWidthOffset }

                    NewMenuToggleEntry {
                        text: "Rotation Lock"
                        statusText: preferences.rotationLock ? "On" : "Off"
                        onAction: {
                            if (preferences.rotationLock) {
                                preferences.rotationLockAngle = preferences.rotationInvalid;
                            } else {
                                preferences.rotationLockAngle = orientationHelper.orientationAngle;
                                orientationHelper.__lockedRotationAngle = preferences.rotationLockAngle;
                            }
                            rotationLockTriggered(preferences.rotationLock);
                        }
                    }

                    MenuDivider { widthOffset: dividerWidthOffset }

                    NewMenuToggleEntry {
                        text: "Flashlight"
                        // Distinguishes "no torch here" from "torch is off", which
                        // the old homebrew call could not: it reported Off either way.
                        statusText: !flashlightAvailable ? "Unavailable"
                                                        : (flashlightOn ? "On" : "Off")
                        active: flashlightAvailable
                        onAction: {
                            if (!flashlightAvailable)
                                return;
                            // No optimistic update: the subscription above carries the
                            // new state back, so the menu never claims a toggle worked
                            // when the device refused it.
                            service.call("luna://org.webosports.service.torch/toggle", "{}",
                                         function(message) { },
                                         function(error) {
                                             console.log("Flashlight toggle failed: " + error);
                                         });
                        }
                    }
                }

                // ---- Phone tab ----
                Column {
                    id: phoneTab
                    spacing: 0
                    width: mainMenu.width
                    visible: currentTab === "phone"

                    NewMenuToggleEntry {
                        text: "Phone Radio"
                        statusText: telephonyServiceConnector.powered ? "On" : "Off"
                        // telephonyd owns the modem while airplane mode is on
                        // and answers powerSet with "Airplane mode is enabled",
                        // so do not offer a switch that cannot do anything.
                        active: !airplaneModeService.active && !airplaneModeService.inProgress
                        onAction: {
                            service.call("luna://com.palm.telephony/powerSet",
                                         JSON.stringify({"state": telephonyServiceConnector.powered ? "off" : "on", "save": true}),
                                         function(message) { }, function(error) { });
                        }
                    }

                    MenuDivider { widthOffset: dividerWidthOffset }

                    NewMenuToggleEntry {
                        text: "Data Usage"
                        statusText: cellularTechnology.powered ? "On" : "Off"
                        onAction: {
                            cellularTechnology.powered = !cellularTechnology.powered;
                        }
                    }

                    MenuDivider { widthOffset: dividerWidthOffset }

                    NewMenuToggleEntry {
                        text: "Data Network"
                        statusText: dataNetworkModeLabel(dataNetworkMode)
                        // A modem that reports "unknown" has no RadioSettings
                        // interface, so ratSet has nothing to write to.
                        active: dataNetworkMode !== "unknown"
                        onAction: networkSubMenuOpen = !networkSubMenuOpen
                    }

                    Column {
                        spacing: 0
                        width: parent.width
                        visible: networkSubMenuOpen

                        Repeater {
                            model: [
                                { mode: "any",  label: "Automatic" },
                                { mode: "gsm",  label: "Only 2G" },
                                { mode: "umts", label: "Only 3G" },
                                { mode: "lte",  label: "Only 4G" }
                            ]

                            delegate: Column {
                                spacing: 0
                                width: mainMenu.width

                                MenuDivider { widthOffset: dividerWidthOffset }

                                NewMenuToggleEntry {
                                    text: modelData.label
                                    indent: subIdent
                                    statusText: dataNetworkMode === modelData.mode ? "On" : ""
                                    onAction: setDataNetworkMode(modelData.mode)
                                }
                            }
                        }
                    }

                    MenuDivider { widthOffset: dividerWidthOffset }

                    NewMenuToggleEntry {
                        /*
                         * The legacy patch called com.palm.telephony/roamModeSet
                         * here, which telephonyd has never implemented - the
                         * entry read "Off" whatever the setting was and toggling
                         * it answered "Unknown method". What LuneOS does have is
                         * the WAN roam guard, so this drives that instead, said
                         * the way round a user reads it: guard on means data
                         * roaming off.
                         */
                        text: "Data Roaming"
                        statusText: wanService.roamGuard ? "Off" : "On"
                        onAction: wanService.setRoamGuard(!wanService.roamGuard)
                    }

                    MenuDivider { widthOffset: dividerWidthOffset }

                    NewMenuToggleEntry {
                        text: "Airplane Mode"
                        // Reflects what the radios are doing, not what was
                        // last written to the airplaneMode preference.
                        statusText: airplaneModeService.inProgress ? "..."
                                                                   : airplaneModeService.active ? "On" : "Off"
                        active: !airplaneModeService.inProgress
                        showSpinner: true
                        spinning: airplaneModeService.inProgress
                        onAction: {
                            airplaneModeTriggered();
                            closeMenuTimer.interval = 250;
                            closeMenuTimer.start();
                        }
                    }
                }
            }
        }

        // Invisible gesture bars along both edges, like the legacy
        // patch: tapping/swiping them cycles through the tabs.
        MouseArea {
            id: gestureBarLeft
            width: Units.gu(1.8)
            height: flickableArea.height
            onPressed: cycleTab(1)
        }

        MouseArea {
            id: gestureBarRight
            width: Units.gu(1.8)
            height: flickableArea.height
            anchors.right: parent.right
            onPressed: cycleTab(-1)
        }
    }

    Component {
        id: wifiListDelegate
        Column {
            spacing: 0
            width: mainMenu.width

            property NetworkService delegateService: modelData

            MenuListEntry {
                id: entry
                selectable: true
                height: Units.gu(5.2)
                forceSelected: delegateService.connected

                content: WifiEntry {
                            id: wifiNetworkData
                            x: ident;
                            width: mainMenu.width - x;
                            name:         delegateService.name;
                            strength:     delegateService.strength;
                            securityType: delegateService.securityType;
                            status:       delegateService.state;
                            connected:    delegateService.connected;
                         }
                onAction: {
                    if (delegateService.connected) {
                        delegateService.requestDisconnect();
                    }
                    else {
                        // if this service needs a password and we don't have it yet,
                        // connman will ask the user through the UserAgent
                        delegateService.requestConnect();
                    }
                    closeMenuTimer.interval = 300;
                    closeMenuTimer.start();
                }
            }

            MenuDivider { widthOffset: dividerWidthOffset }
        }
    }

    Component {
        id: bluetoothListDelegate
        Column {
            spacing: 0
            width: mainMenu.width

            property variant delegateDevice: model

            MenuListEntry {
                id: entry
                selectable: true
                height: Units.gu(5.2)
                forceSelected: btDeviceData.connecting

                content: BluetoothEntry {
                            id: btDeviceData
                            x: ident
                            width: mainMenu.width - x
                            name:         delegateDevice.FriendlyName || delegateDevice.Name
                            connected:    delegateDevice.Connected
                            connecting:   BluetoothManager.connectingDevice && BluetoothManager.connectingDevice.address === delegateDevice.Address
                            lastConnectFailed: false
                         }

                onAction: {
                    if (delegateDevice.Connected ||
                        (BluetoothManager.connectingDevice &&
                         BluetoothManager.connectingDevice.address === delegateDevice.Address))
                    {
                        BluetoothManager.disconnectDeviceAddress(delegateDevice.Address);
                        closeMenuTimer.interval = 350;
                        closeMenuTimer.start();
                    }
                    else
                    {
                        var pendingCall = BluetoothManager.connectDeviceAddress(delegateDevice.Address);
                        if (pendingCall) {
                            pendingCall.finished.connect(function(call) {
                                if (call.error !== 0)
                                {
                                    btDeviceData.lastConnectFailed = true;
                                }
                            });
                        }
                    }
                }
            }

            MenuDivider { widthOffset: dividerWidthOffset }
        }
    }

    Item {
        id: maskTop
        z: 10
        // 10 + 10 -- transparent pixels on left and right side of image
        // + 2 -- minimal offset(like on legacy)
        width: parent.width - 22
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        opacity: !flickableArea.atYBeginning ? 1.0 : 0.0

        BorderImage {
            width: parent.width
            height: Units.gu(3)
            source: "../../images/menu-dropdown-scrollfade-top.png"
            border { left: 20; top: 0; right: 20; bottom: 0 }
        }

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            width: Units.gu(2.1)
            height: Units.gu(2.1)
            source: "../../images/menu-arrow-up.png"
        }

        Behavior on opacity { NumberAnimation{ duration: 70} }
    }

    Item {
        id: maskBottom
        z: 10
        width: parent.width - 22
        anchors.horizontalCenter: parent.horizontalCenter
        y: flickableArea.height - scrollfadeBottom.height + 1
        opacity: !flickableArea.atYEnd ? 1.0 : 0.0

        BorderImage {
            id: scrollfadeBottom
            width: parent.width
            height: Units.gu(3)
            source: "../../images/menu-dropdown-scrollfade-bottom.png"
            border { left: 20; top: 0; right: 20; bottom: 0 }
        }

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Units.gu(0.9)
            width: Units.gu(2.1)
            height: Units.gu(2.1)
            source: "../../images/menu-arrow-down.png"
        }

        Behavior on opacity { NumberAnimation{ duration: 70} }
    }

    InverseMouseArea {
        width: mainMenu.width;
        height: Math.min(deviceMenu.height - clipRect.anchors.topMargin - clipRect.anchors.bottomMargin, mainMenu.height);
        sensingArea: root
        onClicked: {
            resetMenu()
            toggleState()
        }
    }

    Timer {
        id: closeMenuTimer
        repeat: false;
        running: false;

        onTriggered: closeSystemMenu()
    }

    onVisibleChanged: {
        if (visible) {
            refreshStatus();
            if (wifiList.powered)
                wifiList.requestScan();
        } else {
            networkSubMenuOpen = false;
        }
    }

    states: [
        State { name: "hidden" },
        State { name: "visible" }
    ]

    transitions: [
        Transition {
            from: "hidden"
            to: "visible"
            ScriptAction { script: deviceMenu.visible = true }
            NumberAnimation { target: deviceMenu; property: "opacity"; from: 0; to: 1; duration: 300 }
        },
        Transition {
            from: "visible"
            to: "hidden"
            NumberAnimation { target: deviceMenu; property: "opacity"; from: 1; to: 0; duration: 300 }
            ScriptAction { script: deviceMenu.visible = false }
        }
    ]
}
