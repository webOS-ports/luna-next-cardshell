/*
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
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

Item {
    id: compositor
    visible: false

    signal windowAdded(Item window);
    signal windowRemoved(Item window);
    signal windowShown(Item window);
    signal windowHidden(Item window);

    signal windowAddedInListModel(Item window);
    signal windowRemovedFromListModel(Item window);

    property Item statusBarServicesConnector: StatusBarServicesConnector {}

    QtObject {
        id: localProperties

        property int nextWinId: 0;

        function getNextWinId() {
            nextWinId++;
            return nextWinId;
        }
    }
    ListModel {
        // This model contains the list of the windows that are managed by the compositor.
        id: listWindowsModel

        function getIndexFromProperty(modelProperty, propertyValue) {
            var i=0;
            for(i=0; i<listWindowsModel.count;i++) {
                var item=get(i);
                if(item && item[modelProperty] === propertyValue) {
                    return i;
                }
            }

            console.log("Couldn't find window!");
            return -1;
        }
    }

    Component.onCompleted: {
        createFakeWindow("FakeJustTypeLauncherWindow", {});
    }

    function show() {
        visible = true;
        console.log("Compositor: show()");
    }
    function clearKeyboardFocus() {
        console.log("Compositor: cleared keyboard focus.");
    }

    function createFakeWindow(name, options) {
        console.log("createFakeWindow: Creating " + name + " window");
        var windowComponent = Qt.createComponent("../../" + name + ".qml");
        var window = windowComponent.createObject(compositor, options);
        window.winId = localProperties.getNextWinId();

        listWindowsModel.append({"window": window, "winId": window.winId});
        compositor.windowAddedInListModel(window);

        compositor.windowAdded(window);
    }

    function closeWindowWithId(winId) {
        console.log("Compositor: closeWindowWithId (winId:" + winId + ")");

        var indexWindow = listWindowsModel.getIndexFromProperty("winId", winId);
        var window = listWindowsModel.get(indexWindow).window;

        if( window )
        {
            console.log("About to destroy window: " + window);

            listWindowsModel.remove(indexWindow); // this will delete the userData
            compositor.windowRemovedFromListModel(window);

            windowRemoved(window); // I do hope this is synchronous ?

            window.destroy();
        }
    }
}

