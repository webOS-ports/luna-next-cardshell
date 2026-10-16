/*
 * Copyright (c) 2026 Herman van Hazendonk <github.com@herrie.org>
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.0
import QtTest 1.2

/*
 * The gesture area's gestures in the whole shell (mainDesktop.qml), against the
 * luneos-components stubs: what each one does with the launcher, the system
 * menu or the notification list open, and legacy's swipe down - a drag from
 * the screen into the gesture area - with real presses and moves.
 */
Item {
    id: root
    width: 10; height: 10

    property var shellWindow: null
    property var output: null
    property var cardsArea: null
    property var compositor: null

    function findItem(item, pred) {
        if (!item)
            return null;
        if (pred(item))
            return item;
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++) {
            var r = findItem(kids[i], pred);
            if (r)
                return r;
        }
        return null;
    }

    TestCase {
        id: tc
        name: "Gestures"
        when: windowShown

        function initTestCase() {
            var comp = Qt.createComponent(Qt.resolvedUrl("../qml/mainDesktop.qml"));
            verify(comp.status === Component.Ready, comp.errorString());
            shellWindow = comp.createObject(root);
            verify(shellWindow);
            for (var i = 0; i < shellWindow.data.length; i++)
                if (shellWindow.data[i].outputWindow !== undefined)
                    compositor = shellWindow.data[i];
            verify(compositor);
            output = compositor.outputWindow;
            tryVerify(function() {
                cardsArea = findItem(output.contentItem, it => it.gestureShellFirst !== undefined);
                return cardsArea !== null;
            }, 15000, "CardsArea never appeared");
            // The stub's display service reports the screen locked; the gesture
            // area is hidden and gestures are off until it is not.
            var lock = findItem(cardsArea, it => it.padUnlock !== undefined);
            verify(lock);
            lock.state = "none";
            tryVerify(function() { return gesture.visible && cardsArea.gesturesEnabled; }, 5000,
                      "gesture area still hidden after unlocking");
            // Two app cards, so there is a card view to work with.
            compositor.createFakeWindow("DummyWindow", { id: "org.test.one" });
            compositor.createFakeWindow("DummyWindow", { id: "org.test.two" });
            wait(500);
        }

        property var gesture: cardsArea ? findItem(cardsArea, it => it.shellFirst !== undefined && it.tap !== undefined) : null
        property var launcher: cardsArea ? findItem(cardsArea, it => it.launcherActive !== undefined && it.fullLauncherVisible !== undefined) : null
        property var cardView: cardsArea ? findItem(cardsArea, it => it.isCurrentCardActive !== undefined) : null
        property var statusBar: cardsArea ? findItem(cardsArea, it => it.closeSystemMenu !== undefined) : null

        // Card view, and still card view half a second later: a freshly
        // created card maximizes itself shortly after it maps.
        function toCardView() {
            for (var attempt = 0; attempt < 10; attempt++) {
                if (launcher.launcherActive)
                    launcher.state = "launchbar";
                if (cardView.isCurrentCardActive())
                    cardView.setCurrentCardState(1 /* WindowState.Carded */);
                tryCompare(cardView, "state", "cardList");
                statusBar.closeSystemMenu();
                cardsArea.closeNotificationList();
                while (cardsArea.nbRegisteredTapActions() > 0)
                    cardsArea.doNextTapAction();
                wait(500);
                if (cardView.state === "cardList" && !launcher.launcherActive)
                    return;
            }
            fail("card view does not stay put: " + cardView.state);
        }

        function maximize() {
            toCardView();
            cardView.setCurrentCardState(2 /* WindowState.Maximized */);
            tryCompare(cardView, "state", "maximizedCard");
        }

        function openSystemMenu() {
            statusBar.systemMenu.toggleState();
            verify(statusBar.isSystemMenuOpen());
        }

        function openNotificationList() {
            var list = cardsArea.notificationList();
            verify(list, "no phone notification area");
            list.state = "open";
            cardsArea.addTapAction("minimizeNotificationArea", list.minimizeNotificationArea, null);
        }

        function test_tapInCardViewOpensLauncherAndClosesIt() {
            toCardView();
            gesture.tap();
            compare(launcher.state, "fullLauncher");
            gesture.tap();
            compare(launcher.state, "launchbar");
            compare(cardView.state, "cardList");
        }

        function test_tapMaximizedGoesToCardView() {
            maximize();
            gesture.tap();
            tryCompare(cardView, "state", "cardList");
            compare(launcher.state, "launchbar");
        }

        function test_upTogglesLauncherInCardView() {
            toCardView();
            gesture.swipeUp(0);
            compare(launcher.state, "fullLauncher");
            gesture.swipeUp(0);
            compare(launcher.state, "launchbar");
        }

        function test_upMinimizesMaximized() {
            maximize();
            gesture.swipeUp(0);
            tryCompare(cardView, "state", "cardList");
        }

        function test_tapClosesSystemMenuFirst() {
            toCardView();
            openSystemMenu();
            gesture.tap();
            verify(!statusBar.isSystemMenuOpen());
            compare(launcher.state, "launchbar");
        }

        function test_backClosesSystemMenuOnly() {
            maximize();
            openSystemMenu();
            gesture.back(0);
            verify(!statusBar.isSystemMenuOpen());
            compare(cardView.state, "maximizedCard");
        }

        function test_upClosesMenuAndCarriesOn() {
            toCardView();
            openSystemMenu();
            gesture.swipeUp(0);
            verify(!statusBar.isSystemMenuOpen());
            compare(launcher.state, "fullLauncher");
        }

        function test_backClosesNotificationListAndItsTapAction() {
            maximize();
            openNotificationList();
            compare(cardsArea.nbRegisteredTapActions(), 1);
            gesture.back(0);
            compare(cardsArea.notificationList().state, "minimized");
            compare(cardsArea.nbRegisteredTapActions(), 0);
            compare(cardView.state, "maximizedCard");
        }

        function test_tapRunsNewestTapActionOnly() {
            maximize();
            openNotificationList();
            gesture.tap();
            compare(cardsArea.notificationList().state, "minimized");
            // The tap closed the list and did nothing else.
            compare(cardView.state, "maximizedCard");
        }

        function test_backSendsEscapeToTheApp() {
            maximize();
            compositor.defaultSeat.sentKeys = [];
            gesture.back(0);
            compare(compositor.defaultSeat.sentKeys, [[Qt.Key_Escape, true], [Qt.Key_Escape, false]]);
        }

        function test_forwardSendsForwardToTheApp() {
            maximize();
            compositor.defaultSeat.sentKeys = [];
            gesture.forward(0);
            compare(compositor.defaultSeat.sentKeys, [[Qt.Key_Forward, true], [Qt.Key_Forward, false]]);
        }

        function test_forwardClosesMenuAndCarriesOn() {
            maximize();
            openSystemMenu();
            compositor.defaultSeat.sentKeys = [];
            gesture.forward(0);
            verify(!statusBar.isSystemMenuOpen());
            compare(compositor.defaultSeat.sentKeys.length, 2);
        }

        function test_backWithMenuOpenSendsNothing() {
            maximize();
            openSystemMenu();
            compositor.defaultSeat.sentKeys = [];
            gesture.back(0);
            compare(compositor.defaultSeat.sentKeys.length, 0);
        }

        function test_forwardInCardViewSendsNothing() {
            toCardView();
            compositor.defaultSeat.sentKeys = [];
            gesture.forward(0);
            compare(compositor.defaultSeat.sentKeys.length, 0);
        }

        function test_backClosesLauncher() {
            toCardView();
            launcher.state = "fullLauncher";
            gesture.back(0);
            compare(launcher.state, "launchbar");
        }

        function test_downOpensCentredCard() {
            toCardView();
            gesture.swipeDown(0);
            tryCompare(cardView, "state", "maximizedCard");
        }

        function test_downIgnoredWithLauncherOpen() {
            toCardView();
            launcher.state = "fullLauncher";
            gesture.swipeDown(0);
            wait(200);
            compare(cardView.state, "cardList");
            compare(launcher.state, "fullLauncher");
        }

        function test_downIgnoredWithMenuOpen() {
            toCardView();
            openSystemMenu();
            gesture.swipeDown(0);
            wait(200);
            compare(cardView.state, "cardList");
        }

        // Real touches through the window: drag from the screen into the area.
        function areaTop() {
            return gesture.mapToItem(output.contentItem, 0, 0).y;
        }

        function test_zz_watcherDownFromEmptySpace() {
            toCardView();
            var it = output.contentItem;
            var x = Math.round(it.width * 0.05);   // left margin, outside the centred card
            var top = areaTop();
            mousePress(it, x, top - 150);
            mouseMove(it, x, top - 100, 10);
            mouseMove(it, x, top - 30, 10);
            mouseMove(it, x, top + 5, 10);
            mouseRelease(it, x, top + 5);
            tryCompare(cardView, "state", "maximizedCard");
        }

        function test_zz_watcherCountsTheLiftPoint() {
            toCardView();
            var it = output.contentItem;
            var x = Math.round(it.width * 0.05);
            var top = areaTop();
            mousePress(it, x, top - 150);
            mouseMove(it, x, top - 60, 10);
            // Lifts inside the area with no move reported there first.
            mouseRelease(it, x, top + 5);
            tryCompare(cardView, "state", "maximizedCard");
        }

        function test_zz_watcherShortDropIgnored() {
            toCardView();
            var it = output.contentItem;
            var x = Math.round(it.width * 0.05);
            var top = areaTop();
            // Less than 10 legacy px down.
            mousePress(it, x, top - 3);
            mouseMove(it, x, top + 2, 10);
            mouseRelease(it, x, top + 2);
            wait(200);
            compare(cardView.state, "cardList");
        }

        function test_zz_watcherSidewaysIgnored() {
            toCardView();
            var it = output.contentItem;
            var top = areaTop();
            mousePress(it, 20, top - 40);
            mouseMove(it, 140, top + 5, 10);
            mouseRelease(it, 140, top + 5);
            wait(200);
            compare(cardView.state, "cardList");
        }

        function test_zz_watcherStaysOutOfCardDrags() {
            toCardView();
            var it = output.contentItem;
            // The middle of a card that can be dragged.
            var sc = findItem(cardView, i => i.objectName === "swipeableCard" && i.interactive && i.cardItem);
            verify(sc, "no interactive card");
            var c = sc.cardItem.mapToItem(it, sc.cardItem.width / 2, sc.cardItem.height / 2);
            var x = Math.round(c.x);
            var y = Math.round(c.y);
            var top = areaTop();
            verify(y < top - 40, "card centre too close to the gesture area: " + y);
            mousePress(it, x, y);
            for (var yy = y + 20; yy < top + 5; yy += 20)
                mouseMove(it, x, yy, 10);
            mouseMove(it, x, top + 5, 10);
            mouseRelease(it, x, top + 5);
            wait(400);
            compare(cardView.state, "cardList");
        }
    }
}
