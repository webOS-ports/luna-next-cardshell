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

MenuListEntry {
    property int ident: 0

    Timer {
        id: updateTimer
        interval: 30000
        repeat: true
        running: true
        onTriggered: {
            dateText.text = Qt.formatDate(new Date, Qt.DefaultLocaleLongDate);
        }
    }

    selectable: false
    content:
        Text {
            id: dateText
            x: ident;
            text: Qt.formatDate(new Date, Qt.DefaultLocaleLongDate);
            color: "#AAA";
            font.bold: false;
            font.pixelSize: 16
            font.family: "Prelude"
        }
}
