// Sizes the list view and its loading skeleton must share.
//
// A row is 72 base units tall and the skeleton stands in for it during load;
// if the two disagree the placeholder rows stop lining up with the real ones.
// The number lives here once so both views and the row read the same value.
var ROW_HEIGHT_BASE = 72;

if (typeof module !== "undefined" && module.exports) {
    module.exports = { ROW_HEIGHT_BASE: ROW_HEIGHT_BASE };
}
