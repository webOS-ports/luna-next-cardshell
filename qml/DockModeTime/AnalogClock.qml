import QtQuick 2.0
import LunaNext.Common 0.1
import LunaNext.Compositor 0.1

Item {
    id: analogclock
    width: Settings.displayWidth;
    height: Settings.displayHeight

    property int glass: 1
    property variant type: ["matte","glass"]
    property bool timerRunning: false

    function getHours() {
        var date = new Date
        return date.getHours()
    }

    function getMinutes(){
        var date = new Date
        return date.getMinutes()
    }

    function getSeconds(){
        var date = new Date
        return date.getSeconds()
    }

    function getDay(){
        var date = new Date 
        var dateString=glass ? Qt.formatDate(date, Qt.DefaultLocaleLongDate) : date.getDate();
        return dateString;
    }

    function getWeekDay(){
        var date = new Date
        var days = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat']
        return days[ date.getDay() ]
        //return runtime.getLocalizedDay();
    }

    property int hours: getHours()
    property int minutes: getMinutes()
    property int seconds: getSeconds()
    property int milliseconds
    property int secondAdjustment
    property string day:getDay()
    property string weekday:getWeekDay()

    function timeChanged() {
        var date = new Date;
        hours = getHours();
        minutes = getMinutes();
        seconds = getSeconds();
        day = getDay();
        weekday = getWeekDay();
    }

    Timer {
        interval: 100; running: timerRunning; repeat: true;
        onTriggered: analogclock.timeChanged()
    }

     Image {
         id: face
         source: "../images/dockmode/time/analog/"+type[glass]+"/base.png"
         anchors.centerIn: parent
         width: (Settings.displayWidth > Settings.displayHeight) ? Settings.displayHeight * 0.75 : parent.width * 0.75
         height: (Settings.displayHeight > Settings.displayWidth) ? parent.width * 0.75 : Settings.displayHeight * 0.75 //parent.width * 0.75
     }

     Text {
         id: dayText
         text: day
         parent: face
         anchors.centerIn: parent
         anchors.horizontalCenterOffset: glass ? 0 : Units.gu(7) //108
         anchors.verticalCenterOffset: glass ? Units.gu(18) : Units.gu(0) //300 : -2
         font.family: "prelude"
         font.pointSize: glass ? 10 : 10//Units.gu(3.0) : Units.gu(3.0) //30 : 30
         color: "#e1e1e1"
     }

     Text {
         id: dayofWeekText
         text: weekday
         visible: !glass
         parent: face
         anchors.centerIn: parent
         anchors.horizontalCenterOffset: glass ? 0 : Units.gu(-7) //-108
         anchors.verticalCenterOffset: glass ? Units.gu(10.0) : Units.gu(0) //260 : -2
         font.family: "prelude"
         font.pointSize: glass ? 6 : 10 //Units.gu(1.6): Units.gu(3.0) //16 : 30
         color: "#e1e1e1"
     }

     Image {
         id: hourHand
         source: "../images/dockmode/time/analog/"+type[glass]+"/hour.png"
         anchors.centerIn: parent
         parent: face
         smooth: true
         transform: Rotation {
             id: hourRotation
             origin.x: hourHand.width/2; origin.y: hourHand.height/2;
             angle: (analogclock.hours * 30) + (analogclock.minutes * 0.5)
             Behavior on angle {
                 RotationAnimation{ direction: RotationAnimation.Clockwise }
             }
         }
     }

     Image {
         id: minuteHand
         source: "../images/dockmode/time/analog/"+type[glass]+"/minute.png"
         anchors.centerIn: parent
         parent: face
         smooth: true
         transform: Rotation {
             id: minuteRotation
             origin.x: minuteHand.width/2; origin.y: minuteHand.height/2;
             angle: analogclock.minutes * 6
             Behavior on angle {
                 RotationAnimation{ direction: RotationAnimation.Clockwise }
             }
         }

     }

     Image {
         id: secondHand
         source: glass ? "" : "../images/dockmode/time/analog/"+type[glass]+"/second.png"
         anchors.centerIn: parent
         parent: face
         smooth: true
         transform: Rotation {
             id: secondRotation
             origin.x: secondHand.width/2; origin.y: secondHand.height/2;
             angle: analogclock.seconds * 6
             Behavior on angle {
                 RotationAnimation{ direction: RotationAnimation.Clockwise; easing.type: Easing.OutBack; duration: 300 }
             }
         }
     }
 }
