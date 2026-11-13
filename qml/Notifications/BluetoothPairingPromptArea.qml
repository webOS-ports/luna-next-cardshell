/*
 * Copyright (C) 2026 Herman van Hazendonk <github.com@herrie.org>
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

import QtQuick 2.0
import LuneOS.Bluetooth 0.2

/*
 * Pairings a device starts (a computer, a headset in pairing mode), asked
 * by the shell whatever app is open, Settings or none.
 *
 * com.webos.service.bluetooth2 puts those questions to the one client
 * subscribed to adapter/awaitPairingRequests, and refuses the pairing while
 * there is none: LuneOS.Bluetooth's agent subscribes here for as long as
 * Bluetooth is up. The subscription goes with the adapter, so the agent
 * registers again when Bluetooth comes back; and every retryIntervalMs while
 * another client holds it (bluetooth2 says 104 and keeps that one), so the
 * shell takes over once it lets go.
 *
 * Pairings Settings starts are asked by Settings itself (through its own
 * adapter/pair); a pairing the shell's BluetoothManager starts (a device
 * picked in the system menu) is asked here too. A pairing that did not work
 * is said here as well (LuneOSBluetoothAgent's pairingFailed).
 *
 * The calls go out under the shell's name, which holds bluetooth2's
 * bluetooth.operation group.
 */
Item {
    id: area

    //! What is asked now, BluetoothPairingPrompt's kind ("" when nothing).
    readonly property string kind: prompt.kind
    //! How often to try again while the subscription is not ours.
    property int retryIntervalMs: 10000
    readonly property bool registered: agent.registered === true

    // Dialog dims all of it, and takes the presses on it, while asking.
    anchors.fill: parent

    function register() {
        if (BluetoothManager.bluetoothOperational && !registered)
            agent.registerToManager(BluetoothManager.btManager);
    }

    LuneOSBluetoothAgent {
        id: agent
        objectName: "bluetoothPairingAgent"

        onRequestConfirmationFromUser: (device, passkey, request) => prompt.ask("confirmation", device, passkey, request)
        onRequestAuthorizationFromUser: (device, request) => prompt.ask("authorization", device, "", request)
        onRequestPinCodeFromUser: (device, request) => prompt.ask("pinCode", device, "", request)
        onRequestPasskeyFromUser: (device, request) => prompt.ask("passkey", device, "", request)
        onDisplayPasskeyToUser: (device, passkey, entered) => prompt.ask("displayPasskey", device, passkey, null)
        onDisplayPinCodeToUser: (device, pinCode) => prompt.ask("displayPinCode", device, pinCode, null)
        onCancel: prompt.withdraw()
        onPairingFailed: (device, reason) => prompt.fail(device)
    }

    Connections {
        target: BluetoothManager
        function onBluetoothOperationalChanged() {
            area.register();
        }
    }

    Component.onCompleted: register()

    Timer {
        interval: area.retryIntervalMs
        repeat: true
        running: BluetoothManager.bluetoothOperational && !area.registered
        onTriggered: area.register()
    }

    BluetoothPairingPrompt {
        id: prompt
        objectName: "bluetoothPairingPrompt"
    }
}
