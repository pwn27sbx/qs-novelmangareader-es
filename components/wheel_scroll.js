// Wheel arithmetic for the readers, kept pure so Node can test it.
//
// A wheel event carries `angleDelta` (eighths of a degree, 120 per notch on a
// mouse) OR only `pixelDelta` (a touchpad). Both mean "scroll this way", so the
// step keeps the SAME sign — a handler that negates pixelDelta scrolls the
// wrong way on a touchpad. The factor multiplies the step; the result is
// clamped so the reader never runs past its own end.
//
// Imported by modules/*/components/ReaderView.qml and by
// tests/wheel_scroll.test.js.

function stepOf(angleDeltaY, pixelDeltaY) {
    var angle = Number(angleDeltaY) || 0;
    if (angle !== 0)
        return angle;
    return Number(pixelDeltaY) || 0;
}

function nextContentY(currentY, angleDeltaY, pixelDeltaY, factor, limit) {
    var step = stepOf(angleDeltaY, pixelDeltaY) * (Number(factor) || 1);
    var target = (Number(currentY) || 0) - step;
    var max = Number(limit);
    if (!isFinite(max) || max < 0)
        max = 0;
    return Math.max(0, Math.min(max, target));
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { stepOf: stepOf, nextContentY: nextContentY };
}
