/*
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2013 Simon Busch <morphis@gravedo.de>
 * Copyright (C) 2015 Herman van Hazendonk <github.com@herrie.org>
 * Copyright (C) 2015 Nikolay Nizov <nizovn@gmail.com>
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
pragma Singleton

import QtQuick 2.0
import Connman 0.2
import org.nemomobile.dbus 2.0

Item {
    id: bluetoothService

    property bool powered: bluetoothTech.available?bluetoothTech.powered:false
    property bool connected: bluetoothTech.available?bluetoothTech.connected:false
    property var devicesList: []
    property bool isTurningOn: (bluetoothTech.available && bluetoothTech.powered) && (btAdapter.path === "/")
    property ListModel deviceModel: ListModel {}

    signal clearBtList()
    signal addBtEntry(string name, string address, int cod, string connStatus, bool connected)
    signal updateBtEntry(string address, string connStatus, bool connected)
    signal setBtState(bool isOn, bool turningOn, string state)

    TechnologyModel {
        id: bluetoothTech
        name: "bluetooth"
    }

    DBusInterface {
        id: btManager
        service: "org.bluez"
        path: "/"
        iface: "org.bluez.Manager"
        bus: DBus.SystemBus
        signalsEnabled: true

        Component.onCompleted: {
            btManager.typedCall('DefaultAdapter', [], function (result) {
                btAdapter.path = result;
                btAdapter.signalsEnabled = true;
            });
        }

        function adapterRemoved(adapter) {
            if (btAdapter.path === adapter) {
                btAdapter.signalsEnabled = false;
                btAdapter.path = "/"
            }
        }

        function defaultAdapterChanged(adapter) {
            btAdapter.path = adapter;
            btAdapter.signalsEnabled = true;
        }
    }

    DBusInterface {
        id: btAdapter
        service: "org.bluez"
        path: "/"
        iface: "org.bluez.Adapter"
        bus: DBus.SystemBus
        signalsEnabled: false

        function propertyChanged(name, value) {
            if (name !== "Devices")
                return;

            bluetoothService.devicesList = value;
        }

        /*
        function deviceCreated(path) {
            console.log("deviceCreated",path);
        }

        function deviceFound(address,values) {
            console.log("deviceFound",address,values);
        }
        */

        onPathChanged: {
            if (btAdapter.path === "/")
            return;

            btAdapter.typedCall('GetProperties', [], function (result) {
                bluetoothService.devicesList = result.Devices;
            });

        }

    }

    function setPowered(powered) {
        if (!bluetoothTech.available) return;

        if (bluetoothTech.powered !== powered)
            bluetoothTech.powered = powered;
    }

    function disconnectAllBtMenuProfiles(address) {
        for (var i=0;i<deviceModel.count;i++) {
            var device = deviceModel.get(i).device;
            if (device.address === address) {
                device.disconnectDevice();
            }
        }
    }

    function connectBtDevice(address, cod) {
        for (var i=0;i<deviceModel.count;i++) {
            var device = deviceModel.get(i).device;
            if (device.address === address) {
                device.connectDevice();
            }
        }
    }

    function createBtDevice(path) {
        var deviceComponent = Qt.createComponent("BluetoothDevice.qml");
        if (deviceComponent.status === Component.Ready) {
            var device = deviceComponent.createObject(bluetoothService, {path: path});
            device.addBluetoothEntry.connect(addBtEntry);
            device.updateBluetoothEntry.connect(updateBtEntry);
            deviceModel.append({device: device});
        }
        else {
            console.error("Error during instantiation of BluetoothDevice.qml!");
            console.error(deviceComponent.errorString());
        }
    }

    function _clearBtList() {
        for (var i=0;i<deviceModel.count;i++) {
            var item = deviceModel.get(i).device;
            item.destroy();
        }
        deviceModel.clear();
        clearBtList();
    }

    onDevicesListChanged: {
        _clearBtList();
        for (var i=0;i<devicesList.length;i++) {
            createBtDevice(devicesList[i]);
        }
    }

    function updateBtState() {
        var state = powered?"ON":"OFF";
        if (isTurningOn) state = "INIT";
        setBtState(powered, isTurningOn, state);
    }

    onIsTurningOnChanged: {
        updateBtState();
    }

    onPoweredChanged: {
        if (!powered)
            _clearBtList();
        updateBtState();
    }

    Component.onCompleted: {
        updateBtState();
    }
}
