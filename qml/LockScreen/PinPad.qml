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
import LunaNext.Common 0.1

Item {
    id: pinPad;

    width: Units.gu(320/10)
    height: gridDividers.height

    Image {
        id: gridDividers
		width: pinPad.width
		fillMode: Image.PreserveAspectFit
        source: "../images/pin/pin-grid.png"
        property int topOffset: Units.gu(4/10)
        property int bottomOffset: Units.gu(6/10)
		smooth: true
    }

    Grid {
        id: buttonGrid

        width: gridDividers.width
        height: gridDividers.height - gridDividers.topOffset - gridDividers.bottomOffset
        y: gridDividers.topOffset
        x:0
        columns: 3
        rows: 4
        spacing: 0

        PinButton { caption: "1"; width: buttonGrid.width/buttonGrid.columns; height:buttonGrid.height/buttonGrid.rows; onAction: keyAction(text);}
        PinButton { caption: "2"; width: buttonGrid.width/buttonGrid.columns + 1; height:buttonGrid.height/buttonGrid.rows; onAction: keyAction(text);}
        PinButton { caption: "3"; width: buttonGrid.width/buttonGrid.columns + 1; height:buttonGrid.height/buttonGrid.rows; onAction: keyAction(text);}
        PinButton { caption: "4"; width: buttonGrid.width/buttonGrid.columns; height:buttonGrid.height/buttonGrid.rows; onAction: keyAction(text);}
        PinButton { caption: "5"; width: buttonGrid.width/buttonGrid.columns + 1; height:buttonGrid.height/buttonGrid.rows; onAction: keyAction(text);}
        PinButton { caption: "6"; width: buttonGrid.width/buttonGrid.columns + 1; height:buttonGrid.height/buttonGrid.rows; onAction: keyAction(text);}
        PinButton { caption: "7"; width: buttonGrid.width/buttonGrid.columns; height:buttonGrid.height/buttonGrid.rows; onAction: keyAction(text);}
        PinButton { caption: "8"; width: buttonGrid.width/buttonGrid.columns + 1; height:buttonGrid.height/buttonGrid.rows; onAction: keyAction(text);}
        PinButton { caption: "9"; width: buttonGrid.width/buttonGrid.columns + 1; height:buttonGrid.height/buttonGrid.rows; onAction: keyAction(text);}
        Rectangle { color: "transparent"; width: buttonGrid.width/buttonGrid.columns; height:buttonGrid.height/buttonGrid.rows;}
        PinButton { caption: "0"; width: buttonGrid.width/buttonGrid.columns + 1; height:buttonGrid.height/buttonGrid.rows; onAction: keyAction(text);}
        PinButton { imgSource: "../images/pin/icon-delete.png"; caption: "\b"; width: buttonGrid.width/buttonGrid.columns+1; height:buttonGrid.height/buttonGrid.rows; onAction: keyAction(text);}
		//PinButton { imgSource: "../images/pin/icon-delete.png"; caption: "\b"; onAction: keyAction(text);}
    }

    signal keyAction(string keyText);
}
