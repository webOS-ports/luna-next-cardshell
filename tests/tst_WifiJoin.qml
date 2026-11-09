import QtQuick 2.0
import QtTest 1.0
import Connman 0.2

import "../qml/StatusBar/SystemMenu"

/*
 * Joining a Wi-Fi network from the system menu. connman asks the agent of
 * whoever called Connect for a passphrase, and the menu has nowhere to type
 * one, so a secured network the device has never joined goes to the Wi-Fi
 * app with {"target": {"servicePath": ...}} and the app connects. A saved
 * or open network is connected from the menu. Both menus, the classic one
 * and the new one, against luneos-components' Connman stand-in.
 */
Item {
    id: root
    width: 480
    height: 800

    // Every app the menus launched, in order.
    property var launches: []

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
    property QtObject launcherInstance: QtObject {
        function launchApplication(id, params) {
            root.launches.push({"id": id, "params": params});
        }
    }

    Component {
        id: newMenuComponent
        NewDeviceMenu { currentTab: "wifi" }
    }

    Component {
        id: elementComponent
        WiFiElement { width: 400; maxViewHeight: 600 }
    }

    SignalSpy {
        id: connectSpy
        signalName: "serviceConnectionStarted"
    }

    SignalSpy {
        id: delegateSpy
        signalName: "userInputRequested"
    }

    SignalSpy {
        id: detailsSpy
        signalName: "detailsRequested"
    }

    Component {
        id: entryComponent
        MenuListEntry {
            width: 300
            content: Item { width: 300; height: 20 }
        }
    }

    SignalSpy {
        id: actionSpy
        signalName: "action"
    }

    SignalSpy {
        id: heldSpy
        signalName: "held"
    }

    TestCase {
        name: "WifiJoin"
        when: windowShown

        readonly property string securedName: "Someone else's wifi"
        readonly property string openName: "OpenBar Wifi"

        function init() {
            root.launches = [];
            connectSpy.clear();
            delegateSpy.clear();
            detailsSpy.clear();
            actionSpy.clear();
            heldSpy.clear();
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

        // The entry for a network, with connectSpy on its service.
        function entryFor(menu, name, favorite) {
            var entry = null;
            tryVerify(function () { entry = findEntry(menu, name); return entry !== null; }, 2000);
            var service = entry.parent.delegateService;
            verify(service, "no service behind " + name);
            verify(!service.connected);
            service.favorite = favorite;
            connectSpy.target = service;
            connectSpy.clear();
            return entry;
        }

        function makeElement() {
            var element = createTemporaryObject(elementComponent, root);
            verify(element !== null, "WiFiElement did not load");
            delegateSpy.target = element;
            detailsSpy.target = element;
            return element;
        }

        function makeNewMenu() {
            var menu = createTemporaryObject(newMenuComponent, root);
            verify(menu !== null, "NewDeviceMenu did not load");
            return menu;
        }

        function compareJoinLaunch(service) {
            compare(root.launches.length, 1, "the Wi-Fi app was not launched");
            compare(root.launches[0].id, "org.webosports.app.settings.wifi");
            compare(root.launches[0].params.target.servicePath, service.path);
        }

        // --- a menu row: a hold is not also a tap

        function test_entryHoldIsNotATap() {
            var entry = createTemporaryObject(entryComponent, root);
            actionSpy.target = entry;
            heldSpy.target = entry;
            mousePress(entry);
            tryCompare(heldSpy, "count", 1, 3000);
            mouseRelease(entry);
            compare(heldSpy.count, 1);
            compare(actionSpy.count, 0, "the hold also tapped the row");
        }

        function test_entryTapIsNotAHold() {
            var entry = createTemporaryObject(entryComponent, root);
            actionSpy.target = entry;
            heldSpy.target = entry;
            mouseClick(entry);
            compare(actionSpy.count, 1);
            compare(heldSpy.count, 0);
        }

        // --- how many networks are listed: the first ones in connman's order

        // The rows of the networks the menu lists, by name, in order.
        function listedNames(menu) {
            var names = [];
            ["My Own Wifi", securedName, openName].forEach(function (name) {
                var entry = null;
                tryVerify(function () { entry = findEntry(menu, name); return entry !== null; }, 2000);
                if (entry.parent.visible)
                    names.push(name);
            });
            return names;
        }

        function test_newMenuListsSixByDefault() {
            var menu = makeNewMenu();
            compare(menu.maxListedNetworks, 6);
            compare(listedNames(menu).length, 3);
        }

        function test_newMenuListsNoMoreThanTheCap() {
            var menu = makeNewMenu();
            menu.maxListedNetworks = 2;
            compare(listedNames(menu), ["My Own Wifi", securedName]);
        }

        function test_classicMenuListsNoMoreThanTheCap() {
            var element = makeElement();
            compare(element.maxListedNetworks, 6);
            element.maxListedNetworks = 2;
            compare(listedNames(element), ["My Own Wifi", securedName]);
        }

        // --- the new menu

        // Held: the network's details in the Wi-Fi app, without connecting.
        function test_newMenuHoldShowsDetails() {
            var menu = makeNewMenu();
            var entry = entryFor(menu, securedName, false);
            entry.held();
            compare(connectSpy.count, 0);
            compare(root.launches.length, 1);
            compare(root.launches[0].id, "org.webosports.app.settings.wifi");
            compare(root.launches[0].params.target.servicePath, entry.parent.delegateService.path);
            compare(root.launches[0].params.target.view, "details");
        }

        // A tap carries no view, so the app connects.
        function test_newMenuTapHasNoView() {
            var menu = makeNewMenu();
            var entry = entryFor(menu, securedName, false);
            entry.action();
            compare(root.launches.length, 1);
            verify(root.launches[0].params.target.view === undefined);
        }

        function test_newMenuSecuredUnsavedGoesToTheApp() {
            var menu = makeNewMenu();
            var entry = entryFor(menu, securedName, false);
            entry.action();
            compare(connectSpy.count, 0, "the menu connected, so connman would ask the menu's agent");
            compareJoinLaunch(entry.parent.delegateService);
        }

        function test_newMenuSecuredSavedConnects() {
            var menu = makeNewMenu();
            var entry = entryFor(menu, securedName, true);
            entry.action();
            compare(connectSpy.count, 1);
            compare(root.launches.length, 0);
        }

        function test_newMenuOpenNetworkConnects() {
            var menu = makeNewMenu();
            var entry = entryFor(menu, openName, false);
            entry.action();
            compare(connectSpy.count, 1);
            compare(root.launches.length, 0);
        }

        // connman still asks the menu's agent when a saved network wants
        // something new: the request goes to the app.
        function test_newMenuAgentRequestGoesToTheApp() {
            var menu = makeNewMenu();
            var agent = findChild(menu, "connmanUserAgent");
            verify(agent !== null);
            agent.userInputRequested("/net/connman/service/wifi_x_managed_psk", {"Passphrase": {}});
            compare(root.launches.length, 1);
            compare(root.launches[0].id, "org.webosports.app.settings.wifi");
            compare(root.launches[0].params.target.servicePath, "/net/connman/service/wifi_x_managed_psk");
        }

        // --- the classic menu (SystemMenu.qml turns userInputRequested into the launch)

        function test_classicMenuSecuredUnsavedGoesToTheApp() {
            var element = makeElement();
            var entry = entryFor(element, securedName, false);
            entry.action();
            compare(connectSpy.count, 0, "the menu connected, so connman would ask the menu's agent");
            compare(delegateSpy.count, 1);
            compare(delegateSpy.signalArguments[0][0], entry.parent.delegateService.path);
        }

        function test_classicMenuSecuredSavedConnects() {
            var element = makeElement();
            var entry = entryFor(element, securedName, true);
            entry.action();
            compare(connectSpy.count, 1);
            compare(delegateSpy.count, 0);
        }

        function test_classicMenuOpenNetworkConnects() {
            var element = makeElement();
            var entry = entryFor(element, openName, false);
            entry.action();
            compare(connectSpy.count, 1);
            compare(delegateSpy.count, 0);
        }

        function test_classicMenuHoldShowsDetails() {
            var element = makeElement();
            var entry = entryFor(element, openName, false);
            entry.held();
            compare(connectSpy.count, 0);
            compare(delegateSpy.count, 0);
            compare(detailsSpy.count, 1);
            compare(detailsSpy.signalArguments[0][0], entry.parent.delegateService.path);
        }

        function test_classicMenuAgentRequestGoesToTheApp() {
            var element = makeElement();
            var agent = findChild(element, "connmanUserAgent");
            verify(agent !== null);
            agent.userInputRequested("/net/connman/service/wifi_x_managed_psk", {"Passphrase": {}});
            compare(delegateSpy.count, 1);
            compare(delegateSpy.signalArguments[0][0], "/net/connman/service/wifi_x_managed_psk");
        }
    }
}
