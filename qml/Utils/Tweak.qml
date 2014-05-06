/*
 * Copyright (C) 2014 Simon Busch <morphis@gravedo.de>
 * Copyright (C) 2014 Christophe Chapuis <chris.chapuis@gmail.com>
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
import LunaNext.Common 0.1

Item {
    id: tweak

    property string owner: ""
    property string key: ""
    property variant value
    property variant defaultValue

    LunaService {
        id: service
        name: "org.webosports.luna"
        onInitialized: {
            service.call("palm://org.webosinternals.tweaks.prefs/get",
                         JSON.stringify({owner: tweak.owner, keys: [tweak.key]}),
                         handleResult, handleError)
        }

        function handleResult(message) {
            var response = JSON.parse(message.payload);
            tweak.value = response[tweak.key];
        }

        function handleError(message) {
            tweak.value = tweak.defaultValue;
        }
    }
    Component.onCompleted: value = defaultValue;
}
