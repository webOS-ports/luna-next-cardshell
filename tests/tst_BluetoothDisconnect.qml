import QtQuick 2.0
import QtTest 1.0

import "../qml/StatusBar/SystemMenu"

/*
 * A device disconnected from the system menu is forgotten by bluetooth2
 * first (autoReconnect/forget), so it is not connected again by itself when
 * Bluetooth next comes on. Both menus, the classic one and the new one,
 * against stand-ins for bluetooth2 and BluetoothManager.
 */
Item {
    id: root
    width: 480
    height: 800

    // Everything asked of bluetooth2 and of BlueZ, in order.
    property var events: []

    // What the status bar gives NewDeviceMenu.
    property int availableHeight: 800
    property QtObject airplaneModeService: QtObject {
        property bool active: false
        property bool inProgress: false
    }
    property QtObject preferences: QtObject {
        property bool rotationLock: false
        property bool rotationInvalid: false
        property int rotationLockAngle: 0
    }

    Component {
        id: fakeLunaComponent
        QtObject {
            property bool answers: true
            function call(uri, args, ok, err) {
                root.events.push({"what": "luna", "uri": uri, "args": JSON.parse(args)});
                var reply = answers ? ok : err;
                if (reply)
                    reply({"payload": JSON.stringify({"returnValue": answers})});
            }
        }
    }

    // What the disconnect needs of BluetoothManager: the device's adapter,
    // and the disconnect itself.
    Component {
        id: fakeManagerComponent
        QtObject {
            id: fakeManager
            property string adapterAddress: "00:11:22:33:44:55"
            property bool knowsDevice: true
            property QtObject btManager: QtObject {
                function deviceForAddress(address) {
                    if (!fakeManager.knowsDevice)
                        return null;
                    return {"address": address,
                            "adapter": fakeManager.adapterAddress ? {"address": fakeManager.adapterAddress} : null};
                }
            }
            property QtObject connectingDevice: null
            function disconnectDeviceAddress(address) {
                root.events.push({"what": "disconnect", "address": address});
                return "pending";
            }
            function connectDeviceAddress(address) {
                root.events.push({"what": "connect", "address": address});
                return null;
            }
        }
    }

    Component {
        id: disconnectComponent
        BluetoothDisconnect { }
    }

    Component {
        id: newMenuComponent
        NewDeviceMenu { currentTab: "bluetooth" }
    }

    Component {
        id: elementComponent
        BluetoothElement { width: 400; maxViewHeight: 600 }
    }

    TestCase {
        name: "BluetoothDisconnect"
        when: windowShown

        readonly property string forgetUri: "luna://com.webos.service.bluetooth2/autoReconnect/forget"

        function init() {
            root.events = [];
        }

        function make() {
            var d = createTemporaryObject(disconnectComponent, root);
            d.luna = createTemporaryObject(fakeLunaComponent, root);
            d.manager = createTemporaryObject(fakeManagerComponent, root);
            return d;
        }

        function test_forgetsBeforeDisconnecting() {
            var d = make();
            compare(d.disconnect("33:BB:CC:00:11:22"), "pending");
            compare(root.events.length, 2);
            compare(root.events[0].what, "luna");
            compare(root.events[0].uri, forgetUri);
            compare(root.events[0].args.address, "33:BB:CC:00:11:22");
            compare(root.events[0].args.adapterAddress, "00:11:22:33:44:55");
            compare(root.events[1].what, "disconnect");
            compare(root.events[1].address, "33:BB:CC:00:11:22");
        }

        // bluetooth2 then forgets the device on every adapter.
        function test_noAdapterAddressWhenBluezQtHasNone() {
            var d = make();
            d.manager.adapterAddress = "";
            d.disconnect("33:BB:CC:00:11:22");
            compare(root.events[0].uri, forgetUri);
            verify(!root.events[0].args.hasOwnProperty("adapterAddress"));

            root.events = [];
            d.manager.knowsDevice = false;
            d.disconnect("33:BB:CC:00:11:22");
            compare(root.events[0].uri, forgetUri);
            verify(!root.events[0].args.hasOwnProperty("adapterAddress"));
            compare(root.events[1].what, "disconnect");
        }

        // No bluetooth2, or one without autoReconnect: still disconnect.
        function test_disconnectsWhenForgetFails() {
            var d = make();
            d.luna.answers = false;
            d.disconnect("33:BB:CC:00:11:22");
            compare(root.events.length, 2);
            compare(root.events[1].what, "disconnect");
        }

        function test_onlyForgetIsAsked() {
            var d = make();
            d.disconnect("33:BB:CC:00:11:22");
            var luna = root.events.filter(function (e) { return e.what === "luna"; });
            compare(luna.length, 1);
            compare(luna[0].uri, forgetUri);
        }

        function findEntry(item, name) {
            if (item.content !== undefined && item.content && item.content.name === name)
                return item;
            for (var i = 0; i < item.children.length; ++i) {
                var found = findEntry(item.children[i], name);
                if (found)
                    return found;
            }
            if (item.contentItem) {
                var inList = findEntry(item.contentItem, name);
                if (inList)
                    return inList;
            }
            return null;
        }

        function makeElement() {
            var element = createTemporaryObject(elementComponent, root);
            verify(element !== null, "BluetoothElement did not load");
            element.bluetoothDisconnect.luna = createTemporaryObject(fakeLunaComponent, root);
            element.bluetoothDisconnect.manager = createTemporaryObject(fakeManagerComponent, root);
            return element;
        }

        // The classic system menu: tapping a connected device used to throw
        // a ReferenceError (btDevice) and disconnect nothing.
        function test_classicMenuForgetsAndDisconnects() {
            failOnWarning(/ReferenceError/);
            var element = makeElement();
            var entry = null;
            tryVerify(function () { entry = findEntry(element, "Fake Paired Connected"); return entry !== null; }, 2000);
            entry.action();
            compare(root.events.length, 2);
            compare(root.events[0].uri, forgetUri);
            compare(root.events[0].args.address, "33-BB-CC-00-11-22");
            compare(root.events[1].what, "disconnect");
            compare(root.events[1].address, "33-BB-CC-00-11-22");
        }

        // Connecting forgets nothing, and no longer throws either.
        function test_classicMenuConnectForgetsNothing() {
            failOnWarning(/ReferenceError/);
            var element = makeElement();
            var entry = null;
            tryVerify(function () { entry = findEntry(element, "Fake Paired"); return entry !== null; }, 2000);
            entry.action();
            compare(root.events.filter(function (e) { return e.what === "luna"; }).length, 0);
        }
    
        // The new system menu's Bluetooth tab.
        function test_newMenuForgetsAndDisconnects() {
            failOnWarning(/ReferenceError/);
            var menu = createTemporaryObject(newMenuComponent, root);
            verify(menu !== null, "NewDeviceMenu did not load");
            menu.bluetoothDisconnect.luna = createTemporaryObject(fakeLunaComponent, root);
            menu.bluetoothDisconnect.manager = createTemporaryObject(fakeManagerComponent, root);
            var entry = null;
            tryVerify(function () { entry = findEntry(menu, "Fake Paired Connected"); return entry !== null; }, 2000);
            entry.action();
            compare(root.events.length, 2);
            compare(root.events[0].uri, forgetUri);
            compare(root.events[0].args.address, "33-BB-CC-00-11-22");
            compare(root.events[1].what, "disconnect");
            compare(root.events[1].address, "33-BB-CC-00-11-22");
        }
    }
}
