import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.app
import qs.Commons
import qs.services
import qs.components
import qs.Ui
import "../../../services/manga_card.js" as MangaCard
import "../../../services/list_metrics.js" as ListMetrics

Item {
    id: browseView

    // ── Exposed API ──────────────────────────────────────────────────────────
    readonly property string fontBody: Style.font.family

    // metaLine composes "chapter · status"; the wording lives in
    // manga_card.js, so both views share one adapter instead of copying it.
    readonly property var cardTranslator: MangaCard.translator(I18n.t)

    // One number for the grid and its skeleton: they must not disagree.
    readonly property int columnCount: 3

    // The layout the user picked (persisted in settings.json). Both branches
    // below read this one value, so the toggle in the section header and the
    // model wiring can never disagree about which one is showing.
    readonly property bool listMode: UiPrefs.viewMode === "list"

    // Emitted when the user taps a manga card
    signal mangaSelected(string mangaId)

    property string currentTagId: ""

    // Emitted when an in-panel filter change invalidates the current search;
    // the panel clears its search bar in response.
    signal searchCleared()

    function resetList() {
        Manga.fetchByOrigin(currentTagId, true)
    }

    // One segment of the grid/list toggle: a square glyph chip that shows
    // whether its layout is the one on screen. The hover tooltip carries the
    // name, so the header stays compact.

    ColumnLayout {
        anchors.fill: parent
        spacing: Style.space(0)

        // ── Tag filter bar (tinted chips, scroll-x) ──────────────────────────
        FilterBar {
            Layout.fillWidth: true
            fontFamily: browseView.fontBody
            options: [
                { label: I18n.t("manga.filter.hot") },
                { label: I18n.t("manga.filter.latest") },
                // Origin tags are data values, identical in both languages.
                { label: "Manga" }, // i18n-ignore — origin tag
                { label: "Manhwa" }, // i18n-ignore — origin tag
                { label: "Manhua" } // i18n-ignore — origin tag
            ]
            currentIndex: {
                if (browseView.currentTagId === "") return 0
                if (browseView.currentTagId === "latest") return 1
                if (browseView.currentTagId === "ja") return 2
                if (browseView.currentTagId === "ko") return 3
                if (browseView.currentTagId === "zh") return 4
                return -1
            }
            onActivated: function(index) {
                var tagId = ["", "latest", "ja", "ko", "zh"][index]
                browseView.currentTagId = tagId
                browseView.searchCleared()
                Manga.fetchByOrigin(tagId, true)
            }
        }

        // ── Section header (+ grid/list toggle) ──────────────────────────────
        // How many results are already in. The contract only exposes `hasMore`,
        // so this is the loaded count — never a catalogue total.
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Style.spacing.xl
            Layout.rightMargin: Style.spacing.xl
            spacing: Style.spacing.sm
            visible: Manga.mangaList.length > 0

            PanelSectionHeader {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                fontFamily: browseView.fontBody
                text: I18n.t("header.results") + " · "
                    + I18n.tn("header.loaded", Manga.mangaList.length)
            }

            // Grid/list toggle. Its twin lives in LibraryView.qml: the shared
            // section header is a bare Text in qs.Ui, and giving it children
            // would reach into a component every panel uses.
            ViewModeChip {
                Layout.alignment: Qt.AlignVCenter
                glyph: "▦"
                label: I18n.t("view.grid")
                current: !browseView.listMode
                bodyFont: browseView.fontBody
                onClicked: UiPrefs.setViewMode("grid")
            }

            ViewModeChip {
                Layout.alignment: Qt.AlignVCenter
                glyph: "☰"
                label: I18n.t("view.list")
                current: browseView.listMode
                bodyFont: browseView.fontBody
                onClicked: UiPrefs.setViewMode("list")
            }
        }

        // ── Main content area ────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Loading state: ghost cards where the first page will land. The
            // cell width comes from SkeletonGrid's own padding, which matches
            // the grid's margins below. In list mode the grid shape does not
            // apply, so the row skeleton takes over.
            SkeletonGrid {
                anchors.fill: parent
                z: 10
                active: !browseView.listMode && Manga.isFetchingManga && Manga.mangaList.length === 0
                columns: browseView.columnCount
                ratio: 1.58
            }

            SkeletonList {
                anchors.fill: parent
                z: 10
                rowHeight: Style.space(ListMetrics.ROW_HEIGHT_BASE)
                dividerInset: Style.spacing.xl
                active: browseView.listMode && Manga.isFetchingManga && Manga.mangaList.length === 0
            }

            // More pages on the way
            LoadingBar {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                z: 11
                active: Manga.isFetchingManga && Manga.mangaList.length > 0
            }

            // Error state
            Rectangle {
                anchors.fill: parent
                color: Colors.background
                visible: Manga.mangaError.length > 0 && !Manga.isFetchingManga
                z: 9

                Column {
                    anchors.centerIn: parent
                    spacing: Style.spacing.xl
                    StyledText {
                        text: "⚠"
                        font.pixelSize: 32 // style-ignore — bespoke size
                        color: Colors.error
                        anchors.horizontalCenter: parent.horizontalCenter
                        opacity: 0.8
                    }
                    StyledText {
                        text: Manga.mangaError
                        color: Colors.on_surface_variant
                        font.pixelSize: Style.font.body
                        font.family: browseView.fontBody
                        wrapMode: Text.Wrap
                        width: 260
                        horizontalAlignment: Text.AlignHCenter
                        lineHeight: 1.4
                    }
                }
            }

            // ── Manga grid ───────────────────────────────────────────────────
            GridView {
                id: mangaGrid
                anchors.fill: parent
                anchors.margins: Style.spacing.xl
                visible: !browseView.listMode
                // `width` already excludes the margins above, so the three
                // columns share it whole (the old `(width - 10) / 4` left a
                // stray 10 px on the right).
                cellWidth: width / browseView.columnCount
                cellHeight: cellWidth * 1.58
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                // A ScriptModel diffs each new array against the last, so appending a
                // page inserts rows instead of resetting the view (and its scroll).
                model: ScriptModel { values: Manga.mangaList }

                ScrollBar.vertical: StyledScrollBar {
                }

                onContentYChanged: {
                    if (contentY + height > contentHeight - cellHeight * 2)
                        Manga.fetchNextMangaPage()
                }

                delegate: Item {
                    width: mangaGrid.cellWidth
                    height: mangaGrid.cellHeight

                    CoverCard {
                        anchors.fill: parent
                        source: modelData.thumbUrl || ""
                        title: modelData.title || ""
                        bodyFont: browseView.fontBody
                        // Kept from the inline delegate this replaces: this grid
                        // faded 56 px and padded the title bar 18 px, so the
                        // cover stays exactly where it was.
                        gradientHeight: 56
                        titlePadding: 18
                        typeBadge: I18n.tData(modelData.type || "").toUpperCase()
                        // The work's chapter · status. The search of some
                        // sources carries no chapter, and the line then drops
                        // that segment instead of leaving an orphan dot.
                        meta: MangaCard.metaLine(modelData.chapter,
                                                 I18n.tData(modelData.status || ""),
                                                 browseView.cardTranslator)

                        onClicked: {
                            Manga.fetchMangaDetail(modelData.id)
                            browseView.mangaSelected(modelData.id)
                        }
                    }
                }
            }

            // ── Manga list ───────────────────────────────────────────────────
            // Same model and same fetch contract as the grid; only the row
            // shape changes. A ScriptModel is kept so appending a page inserts
            // rows instead of resetting the view (and its scroll).
            ListView {
                id: mangaRows
                anchors.fill: parent
                anchors.topMargin: Style.spacing.xl
                anchors.bottomMargin: Style.spacing.xl
                visible: browseView.listMode
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: ScriptModel { values: Manga.mangaList }

                ScrollBar.vertical: StyledScrollBar {
                }

                onContentYChanged: {
                    if (contentY + height > contentHeight - height / 2)
                        Manga.fetchNextMangaPage()
                }

                delegate: ListRow {
                    width: mangaRows.width
                    height: implicitHeight
                    source: modelData.thumbUrl || ""
                    title: modelData.title || ""
                    bodyFont: browseView.fontBody
                    meta: MangaCard.metaLine(modelData.chapter,
                                             I18n.tData(modelData.status || ""),
                                             browseView.cardTranslator)

                    onClicked: {
                        Manga.fetchMangaDetail(modelData.id)
                        browseView.mangaSelected(modelData.id)
                    }
                }
            }
        }
    }
}
