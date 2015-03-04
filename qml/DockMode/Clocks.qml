import QtQuick 2.0
import LunaNext.Common 0.1
import LunaNext.Compositor 0.1

Rectangle {
    id: clock

    property bool mainTimerRunning: false
    property bool isLandscape: width > height ? true : false //(runtime.orientation+1)%2

    Image {
        id: bg
        source: "../images/dockmode/time/clock_bg.png"
        height: parent.height
        width: parent.width
        fillMode: Image.Stretch
    }

    VisualItemModel{
        id: clockList
        AnalogClock{
            width: flickable.width; height: flickable.height
            glass: 1; timerRunning: mainTimerRunning
        }
        DigitalClock{
            width: flickable.width; height: flickable.height
            timerRunning: mainTimerRunning
        }
        AnalogClock{
            width: flickable.width; height: flickable.height
            glass: 0; timerRunning: mainTimerRunning
        }
    }

    ListView {
        id: flickable
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
			source: "../images/dockmode/time/indicator/"+(flickable.currentIndex==0 ? "on" : "off") + ".png" 
		}
        Image { 
			id: clockdot2; 
			height: Units.gu(1.0); 
			width: Units.gu(1.0); 
			fillMode: Image.Stretch; 
			source: "../images/dockmode/time/indicator/"+(flickable.currentIndex==1 ? "on" : "off") + ".png" 
		}
        Image { 
			id: clockdot3; 
			height: Units.gu(1.0); 
			width: Units.gu(1.0); 
			fillMode: Image.Stretch; 
			source: "../images/dockmode/time/indicator/"+(flickable.currentIndex==2 ? "on" : "off") + ".png" 
		}
    }
}



