/* @@@LICENSE
*
*      Copyright (c) 2009-2013 LG Electronics, Inc.
*      Copyright (c) 2015-2016 Herman van Hazendonk <github.com@herrie.org>
*      Copyright (c) 2015-2016 Christophe Chapuis <chris.chapuis@gmail.com>
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
import QtQml.Models 2.2

import LunaNext.Common 0.1
import WebOSCompositorBase 1.0

Rectangle {
    id: clock

    property bool isLandscape: width > height ? true : false //(runtime.orientation+1)%2

    Image {
        id: bg
        source: "../images/dockmode/time/clock_bg.png"
        height: parent.height
        width: parent.width
        fillMode: Image.Stretch
    }

    ObjectModel{
        id: clockList
        AnalogClock{
            width: clocksListView.width; height: clocksListView.height
            glass: 1; timerRunning: ListView.isCurrentItem
        }
        DigitalClock{
            width: clocksListView.width; height: clocksListView.height
            timerRunning: ListView.isCurrentItem
        }
        AnalogClock{
            width: clocksListView.width; height: clocksListView.height
            glass: 0; timerRunning: ListView.isCurrentItem
        }
    }

    ListView {
        id: clocksListView
        anchors.fill: parent
        focus: true
        highlightRangeMode: ListView.StrictlyEnforceRange
        orientation: ListView.Horizontal
        snapMode: ListView.SnapOneItem
        model: clockList
        boundsBehavior: Flickable.DragOverBounds
    }

    Row {
        spacing: Units.gu(1)
        anchors.centerIn: parent
        anchors.verticalCenterOffset: isLandscape ? Units.gu(-40) : Units.gu(-30)
        Image { 
			id: clockdot1; 
			height: Units.gu(1.0); 
			width: Units.gu(1.0); 
			fillMode: Image.Stretch; 
            source: "../images/dockmode/time/indicator/"+(clocksListView.currentIndex==0 ? "on" : "off") + ".png"
		}
        Image { 
			id: clockdot2; 
			height: Units.gu(1.0); 
			width: Units.gu(1.0); 
			fillMode: Image.Stretch; 
            source: "../images/dockmode/time/indicator/"+(clocksListView.currentIndex==1 ? "on" : "off") + ".png"
		}
        Image { 
			id: clockdot3; 
			height: Units.gu(1.0); 
			width: Units.gu(1.0); 
			fillMode: Image.Stretch; 
            source: "../images/dockmode/time/indicator/"+(clocksListView.currentIndex==2 ? "on" : "off") + ".png"
		}
    }
}



