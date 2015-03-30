import QtQuick 2.0
import LunaNext.Common 0.1
import LunaNext.Compositor 0.1

Item {
    id: digitalclock

    //constants
    property int timeOffset: Units.gu(-0.4) 
    property int dateOffset: Units.gu(-0.4) 
    property int timeLandSize: Units.gu(15.8)
    property int timePortSize: Units.gu(12) 
    property int dateLandSize: Units.gu(5.2)
    property int datePortSize: Units.gu(3) 
    property bool timerRunning: false

    function setHours() {
        var d = new Date
        return d.getHours(
                    ) //runtime.twelveHourClock ? (d.getHours() > 12 ? d.getHours()-12: d.getHours() == 0 ? 12 : d.getHours()) : d.getHours();
    }

    function setMinutes() {
        var d = new Date
        return d.getMinutes()
    }

    function setDate() {
        var d = new Date
        return d.getDate()
    }

    function setYear() {
        var d = new Date
        return d.getFullYear()
    }

    function setMonth() {
        var d = new Date
        var monthString = Qt.formatDate(d, "MMM")
        return monthString //runtime.getLocalizedMonth();
    }

    function setAMPM() {
        var d = new Date
        var ampmString = Qt.formatTime(d, "AP")
        return "AM" //runtime.getLocalizedAMPM();
    }

    property int hours: setHours()
    property int minutes: setMinutes()
    property int date: setDate()
    property int year: setYear()
    property string month: setMonth()
    property string ampm: setAMPM()
    property int isLandscape: (digitalclock.width
                               > digitalclock.height) ? 1 : 0 //(runtime.orientation+1)%2
    property variant orientation: ["portrait", "landscape"]

    function timeChanged() {
        var d = new Date
        hours = setHours()
        minutes = setMinutes()

        date = setDate()
        year = setYear()
        month = setMonth()
        ampm = setAMPM()
    }

    Timer {
        interval: 100
        running: timerRunning
        repeat: true
        onTriggered: digitalclock.timeChanged()
    }

    Row {
        spacing: 0
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Units.gu(-4.8)
        Image {
            id: bgHour1
            source: "../images/dockmode/time/digital/"
                    + orientation[isLandscape] + "/flippers-time.png"
        }
        Item {
            width: Units.gu(0.4)
            height: Units.gu(5.0)
        }
        Image {
            id: bgHour2
            source: "../images/dockmode/time/digital/"
                    + orientation[isLandscape] + "/flippers-time.png"
        }
        Item {
            width: Units.gu(2.2)
            height: Units.gu(5.0)
        }
        Image {
            id: dots
            source: "../images/dockmode/time/digital/" + orientation[isLandscape] + "/dots.png"
        }
        Item {
            width: Units.gu(2.2)
            height: Units.gu(5.0)
        }
        Image {
            id: bgMin1
            source: "../images/dockmode/time/digital/"
                    + orientation[isLandscape] + "/flippers-time.png"
        }
        Item {
            width: Units.gu(0.4)
            height: Units.gu(5.0)
        }
        Image {
            id: bgMin2
            source: "../images/dockmode/time/digital/"
                    + orientation[isLandscape] + "/flippers-time.png"
        }
    }

    Row {
        spacing: 2
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Units.gu(13.6)
        Image {
            id: bgMonth1
            source: "../images/dockmode/time/digital/"
                    + orientation[isLandscape] + "/flippers-date.png"
        }
        Image {
            id: bgMonth2
            source: "../images/dockmode/time/digital/"
                    + orientation[isLandscape] + "/flippers-date.png"
        }
        Image {
            id: bgMonth3
            source: "../images/dockmode/time/digital/"
                    + orientation[isLandscape] + "/flippers-date.png"
        }
        Image {
            id: bgBlank1
            source: "../images/dockmode/time/digital/"
                    + orientation[isLandscape] + "/flippers-date.png"
        }
        Image {
            id: bgDay1
            source: "../images/dockmode/time/digital/"
                    + orientation[isLandscape] + "/flippers-date.png"
        }
        Image {
            id: bgDay2
            source: "../images/dockmode/time/digital/"
                    + orientation[isLandscape] + "/flippers-date.png"
        }
        Image {
            id: bgBlank2
            source: "../images/dockmode/time/digital/"
                    + orientation[isLandscape] + "/flippers-date.png"
        }
        Image {
            id: bgYear1
            source: "../images/dockmode/time/digital/"
                    + orientation[isLandscape] + "/flippers-date.png"
        }
        Image {
            id: bgYear2
            source: "../images/dockmode/time/digital/"
                    + orientation[isLandscape] + "/flippers-date.png"
        }
        Image {
            id: bgYear3
            source: "../images/dockmode/time/digital/"
                    + orientation[isLandscape] + "/flippers-date.png"
        }
        Image {
            id: bgYear4
            source: "../images/dockmode/time/digital/"
                    + orientation[isLandscape] + "/flippers-date.png"
        }
    }

    Text {
        id: ampmText
        text: "" //runtime.twelveHourClock ? ampm : ""
        anchors.verticalCenterOffset: isLandscape === 1 ? Units.gu(
                                                              -9.5) : Units.gu(
                                                              -8.0)
        anchors.horizontalCenterOffset: isLandscape === 1 ? Units.gu(
                                                                -4.2) : Units.gu(
                                                                -3.8)
        anchors.centerIn: parent
        font.family: "prelude"
        font.pixelSize: isLandscape === 1 ? Units.gu(2.0) : Units.gu(1.5)
        color: "#e1e1e1"
        layer.mipmap: true
        parent: bgHour1
    }

    Text {
        id: hourTens
        text: parseInt(hours / 10)
        anchors.verticalCenterOffset: timeOffset
        anchors.centerIn: parent
        font.family: "prelude"
        font.pixelSize: isLandscape === 1 ? timeLandSize : timePortSize
        color: "#e1e1e1"
        layer.mipmap: true
        parent: bgHour1
    }

    Text {
        id: hourOnes
        text: hours % 10
        anchors.verticalCenterOffset: timeOffset
        anchors.centerIn: parent
        font.family: "prelude"
        font.pixelSize: isLandscape === 1 ? timeLandSize : timePortSize
        color: "#e1e1e1"
        layer.mipmap: true
        parent: bgHour2
    }

    Text {
        id: minuteTens
        text: parseInt(minutes / 10)
        anchors.verticalCenterOffset: timeOffset
        anchors.centerIn: parent
        font.family: "prelude"
        font.pixelSize: isLandscape === 1 ? timeLandSize : timePortSize
        color: "#e1e1e1"
        layer.mipmap: true
        parent: bgMin1
    }
    Text {
        id: minuteOnes
        text: minutes % 10
        anchors.verticalCenterOffset: timeOffset
        anchors.centerIn: parent
        font.family: "prelude"
        font.pixelSize: isLandscape === 1 ? timeLandSize : timePortSize
        color: "#e1e1e1"
        layer.mipmap: true
        parent: bgMin2
    }

    Text {
        id: monthFirst
        text: month.substring(0, 1).toUpperCase()
        anchors.verticalCenterOffset: dateOffset
        anchors.centerIn: parent
        font.family: "prelude"
        font.pixelSize: isLandscape === 1 ? dateLandSize : datePortSize
        color: "#e1e1e1"
        layer.mipmap: true
        parent: bgMonth1
    }
    Text {
        id: monthSecond
        text: month.substring(1, 2).toUpperCase()
        anchors.verticalCenterOffset: dateOffset
        anchors.centerIn: parent
        font.family: "prelude"
        font.pixelSize: isLandscape === 1 ? dateLandSize : datePortSize
        color: "#e1e1e1"
        layer.mipmap: true
        parent: bgMonth2
    }

    Text {
        id: monthThird
        text: month.substring(2, 3).toUpperCase()
        anchors.verticalCenterOffset: dateOffset
        anchors.centerIn: parent
        font.family: "prelude"
        font.pixelSize: isLandscape === 1 ? dateLandSize : datePortSize
        color: "#e1e1e1"
        layer.mipmap: true
        parent: bgMonth3
    }

    Text {
        id: dayTens
        text: parseInt(date / 10)
        anchors.verticalCenterOffset: dateOffset
        anchors.centerIn: parent
        font.family: "prelude"
        font.pixelSize: isLandscape === 1 ? dateLandSize : datePortSize
        color: "#e1e1e1"
        layer.mipmap: true
        parent: bgDay1
    }
    Text {
        id: dayOnes
        text: date % 10
        anchors.verticalCenterOffset: dateOffset
        anchors.centerIn: parent
        font.family: "prelude"
        font.pixelSize: isLandscape === 1 ? dateLandSize : datePortSize
        color: "#e1e1e1"
        layer.mipmap: true
        parent: bgDay2
    }

    Text {
        id: yearThousands
        text: parseInt(year / 1000)
        anchors.verticalCenterOffset: dateOffset
        anchors.centerIn: parent
        font.family: "prelude"
        font.pixelSize: isLandscape === 1 ? dateLandSize : datePortSize
        color: "#e1e1e1"
        layer.mipmap: true
        parent: bgYear1
    }
    Text {
        id: yearHundreads
        text: parseInt(year / 100) % 10
        anchors.verticalCenterOffset: dateOffset
        anchors.centerIn: parent
        font.family: "prelude"
        font.pixelSize: isLandscape === 1 ? dateLandSize : datePortSize
        color: "#e1e1e1"
        layer.mipmap: true
        parent: bgYear2
    }

    Text {
        id: yearTens
        text: parseInt(year / 10) % 10
        anchors.verticalCenterOffset: dateOffset
        anchors.centerIn: parent
        font.family: "prelude"
        font.pixelSize: isLandscape === 1 ? dateLandSize : datePortSize
        color: "#e1e1e1"
        layer.mipmap: true
        parent: bgYear3
    }
    Text {
        id: yearOnes
        text: year % 10
        anchors.verticalCenterOffset: dateOffset
        anchors.centerIn: parent
        font.family: "prelude"
        font.pixelSize: isLandscape === 1 ? dateLandSize : datePortSize
        color: "#e1e1e1"
        layer.mipmap: true
        parent: bgYear4
    }

    Row {
        spacing: 0
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Units.gu(-4.8)
        Image {
            id: bgHour1Mask
            source: "../images/dockmode/time/digital/"
                    + orientation[isLandscape] + "/flippers-time-mask.png"
        }
        Item {
            width: Units.gu(0.4)
            height: Units.gu(5.0)
        }
        Image {
            id: bgHour2Mask
            source: "../images/dockmode/time/digital/"
                    + orientation[isLandscape] + "/flippers-time-mask.png"
        }
        Item {
            width: Units.gu(7.2)
            height: Units.gu(5.0)
        }
        Image {
            id: bgMin1Mask
            source: "../images/dockmode/time/digital/"
                    + orientation[isLandscape] + "/flippers-time-mask.png"
        }
        Item {
            width: Units.gu(0.4)
            height: Units.gu(5.0)
        }
        Image {
            id: bgMin2Mask
            source: "../images/dockmode/time/digital/"
                    + orientation[isLandscape] + "/flippers-time-mask.png"
        }
    }

    Row {
        spacing: Units.gu(0.2)
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Units.gu(13.6) 
        Image {
            id: bgMonth1Mask
            source: "../images/dockmode/time/digital/"
                    + orientation[isLandscape] + "/flippers-date-mask.png"
        }
        Image {
            id: bgMonth2Mask
            source: "../images/dockmode/time/digital/"
                    + orientation[isLandscape] + "/flippers-date-mask.png"
        }
        Image {
            id: bgMonth3Mask
            source: "../images/dockmode/time/digital/"
                    + orientation[isLandscape] + "/flippers-date-mask.png"
        }
        Image {
            id: bgBlank1Mask
            source: "../images/dockmode/time/digital/"
                    + orientation[isLandscape] + "/flippers-date-mask.png"
        }
        Image {
            id: bgDay1Mask
            source: "../images/dockmode/time/digital/"
                    + orientation[isLandscape] + "/flippers-date-mask.png"
        }
        Image {
            id: bgDay2Mask
            source: "../images/dockmode/time/digital/"
                    + orientation[isLandscape] + "/flippers-date-mask.png"
        }
        Image {
            id: bgBlank2Mask
            source: "../images/dockmode/time/digital/"
                    + orientation[isLandscape] + "/flippers-date-mask.png"
        }
        Image {
            id: bgYear1Mask
            source: "../images/dockmode/time/digital/"
                    + orientation[isLandscape] + "/flippers-date-mask.png"
        }
        Image {
            id: bgYear2Mask
            source: "../images/dockmode/time/digital/"
                    + orientation[isLandscape] + "/flippers-date-mask.png"
        }
        Image {
            id: bgYear3Mask
            source: "../images/dockmode/time/digital/"
                    + orientation[isLandscape] + "/flippers-date-mask.png"
        }
        Image {
            id: bgYear4Mask
            source: "../images/dockmode/time/digital/"
                    + orientation[isLandscape] + "/flippers-date-mask.png"
        }
    }
}
