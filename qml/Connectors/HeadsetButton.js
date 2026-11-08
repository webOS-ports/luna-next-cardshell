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

.pragma library

/*
 * Counts presses of a wired headset's one button, as webOS 2.x's
 * InputManager::headsetStateMachine did, and says what they mean.
 *
 * The difference from 2.x: there a single press was posted the moment the
 * button came up, and a second press inside a second posted "double" on
 * top, so a double press also toggled play/pause on its way to the next
 * track. Here nothing is decided until the presses stop: a press counts
 * as single only once multiPressMs has passed without another, as
 * Android's headset handling does. Three presses are acted on at once,
 * there being nothing after them.
 *
 * Pure: the caller keeps the state and the clock, and runs a one-shot
 * timer for the number of milliseconds each step returns (0: none).
 */

var multiPressMs = 400;   //!< a further press within this counts with the last
var holdMs = 2000;        //!< held this long: a hold, as 2.x's PRESS_AND_HOLD_TIME_MS

function initial() {
    return { down: false, downAt: 0, upAt: 0, count: 0, held: false };
}

//! What count presses ask for: "playPause", "next", "previous", or "".
function actionFor(count) {
    switch (count) {
    case 1: return "playPause";
    case 2: return "next";
    case 3: return "previous";
    default: return "";
    }
}

function _reset(state) {
    state.down = false;
    state.count = 0;
    state.held = false;
}

//! The button went down at now.
function press(state, now) {
    state.down = true;
    state.downAt = now;
    return { action: "", timerMs: holdMs };
}

//! The button came up at now.
function release(state, now) {
    if (!state.down)
        return { action: "", timerMs: 0 };

    state.down = false;
    if (state.held) {
        // The hold was the whole gesture; the presses before it go with it.
        _reset(state);
        return { action: "", timerMs: 0 };
    }

    state.count += 1;
    state.upAt = now;
    if (state.count >= 3) {
        var action = actionFor(state.count);
        _reset(state);
        return { action: action, timerMs: 0 };
    }
    return { action: "", timerMs: multiPressMs };
}

//! The timer ran out at now.
function timeout(state, now) {
    if (state.down) {
        if (!state.held && now - state.downAt >= holdMs) {
            // Rejects a ringing call; nothing else takes it yet. The
            // presses before it go with it when the button comes up.
            state.held = true;
            return { action: "hold", timerMs: 0 };
        }
        return { action: "", timerMs: state.held ? 0 : Math.max(0, holdMs - (now - state.downAt)) };
    }

    if (state.count > 0 && now - state.upAt >= multiPressMs) {
        var action = actionFor(state.count);
        _reset(state);
        return { action: action, timerMs: 0 };
    }
    return { action: "", timerMs: state.count > 0 ? multiPressMs - (now - state.upAt) : 0 };
}
