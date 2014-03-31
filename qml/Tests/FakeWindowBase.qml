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
import LunaNext 0.1

// this should be a plugin import
import "../WindowManager/WindowManagerServices.js" as WindowManagerServices

Item {
    id: fakeWindowBase
    property int winId: 0
    property string appId: "org.webosports.tests.fakewindowbase"
    property int windowType: WindowType.Card

    property Item userData

    property QtObject lunaNextLS2Service: LunaService {
        id: lunaNextLS2Service
        name: "org.webosports.luna"
        usePrivateBus: true
    }

    height: 200
    width: 200

    function takeFocus() {
        console.log(fakeWindowBase + ": takeFocus()");
    }
    function changeSize(size) {
        console.log(fakeWindowBase + ": changeSize(" + size + ")");
        width = size.width;
        height = size.height;
    }
    function postEvent(event) {
        console.log(fakeWindowBase + ": postEvent("+event+")");
    }
}
