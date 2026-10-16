/* @@@LICENSE
*
*      Copyright (c) 2009-2013 LG Electronics, Inc.
*      Copyright (c) 2026 Herman van Hazendonk <github.com@herrie.org>
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

import QtQuick 2.12
import QtQuick.Controls.LuneOS 2.0 as LuneOS
import LunaNext.Common 0.1

/*
 * The shell's dialog button - the lock screen's Cancel and Done, the power
 * and e-ink menus, notification alerts and message dialogs - as
 * luneos-components' styled Button, the one Settings and the apps use.
 *
 * It used to be drawn from 208-pixel Palm images sliced a grid unit in, so
 * the rounded corners were cut from the tip of the curve and stretched; and
 * "negative" pointed at images that never existed, so red buttons had no
 * background at all.
 *
 * The style is imported by name: the shell does not run with
 * QT_QUICK_CONTROLS_STYLE set, and a plain QtQuick.Controls Button would be
 * Qt's Basic one. The interface is the one the callers already use, kept on
 * an Item around the Button: Button has an "action" property of its own
 * (QtQuick Controls' Action), so it could not also carry the action()
 * signal they connect to with onAction.
 */
Item {
    id: actionButton

    property string caption: "Button"
    property bool   active: true
    property bool   affirmative: false
    property bool   negative: false
    property real   inactiveOpacity: 1.0

    signal action()

    width:  Units.gu(200/10)
    height: Units.gu(40/10)

    LuneOS.Button {
        anchors.fill: parent

        text: actionButton.caption
        // Bold, as the shell's buttons always were: the style's Light
        // reads too faint over the translucent dark cards.
        font.bold: true

        // Not "enabled: active": the style draws a disabled button at 0.4,
        // background and text each, and on the shell's dark cards a
        // disabled Done all but disappeared. An inactive button is drawn
        // whole at inactiveOpacity, as before, and neither looks pressed nor
        // acts.
        opacity: actionButton.active ? 1.0 : actionButton.inactiveOpacity
        down: actionButton.active && pressed

        // Neutral is the style's opaque gray. Its translucent primaryColor
        // let the button's outer row of pixels vanish into the dark cards,
        // so a neutral button looked a pixel shorter at the top and at the
        // bottom than a green or red one beside it. Settings' light popups
        // use secondaryColor.
        LuneOS.LuneOSButton.mainColor: actionButton.affirmative ? LuneOS.LuneOSButton.affirmativeColor
                                     : actionButton.negative ? LuneOS.LuneOSButton.negativeColor
                                     : LuneOS.LuneOSButton.grayColor

        onClicked: {
            if (actionButton.active)
                actionButton.action();
        }
    }
}
