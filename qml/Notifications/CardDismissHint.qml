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
import LunaNext.Common 0.1
import LuneOS.Components 1.0

/*
 * "Dismissing Cards": the note webOS 3.0 showed the first time a card went
 * to Card View, saying how to close an app. In LunaSysMgr it was
 * uiComponents/DismissCardTutorial/dismissDialog.qml, a title, one line and
 * OK, put up by WindowServerLuna::createDismissCardWindow. GestureTutorial
 * decides when; this is only the dialog.
 *
 * Built like UsbDebuggingPrompt, from LuneOS.Components' Dialog, and sized
 * as the shell's own system dialog: the title "large", the words "medium".
 */
Dialog {
    id: hint

    title: "Dismissing Cards"
    titlePixelSize: FontUtils.sizeToPixels("large")
    message: "To close an app, flick its card up and off the screen while in Card View."
    messagePixelSize: FontUtils.sizeToPixels("medium")
    dialogWidth: Math.min(Units.gu(36), parent ? parent.width - Units.gu(2) : Units.gu(36))
    dialogHeight: fittedHeight
    visible: false

    // AlertDialog's OK: a dark button, as wide as the other dialogs' buttons
    // where there is room.
    DialogButton {
        objectName: "cardDismissHintOk"
        text: "OK"
        color: "#4B4B4B"
        fontcolor: "white"
        buttonWidth: Math.min(Units.gu(26.0), hint.contentWidth)
        anchors.horizontalCenter: parent.horizontalCenter
        onClicked: hint.close()
    }
}
