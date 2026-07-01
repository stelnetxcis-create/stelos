pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root
    property string searchQuery: ""

    readonly property int panelWidth: Config.options.search.clipboard.panelWidth ?? 860
    implicitWidth: panelWidth
    implicitHeight: mainColumn.implicitHeight + 20

    // ── Format definitions ───────────────────────────────────────────────────
    readonly property var formatOptions: [
        { id: "best",       label: "Best",       icon: "star" },
        { id: "video-mp4",  label: "MP4",        icon: "videocam" },
        { id: "audio-mp3",  label: "MP3",        icon: "audiotrack" },
        { id: "audio-ogg",  label: "OGG",        icon: "music_note" },
        { id: "audio-opus", label: "OPUS",       icon: "graphic_eq" },
        { id: "audio-m4a",  label: "M4A",        icon: "album" }
    ]

    readonly property var typeOptions: [
        { id: "basic",    label: "Basic",    icon: "download" },
        { id: "batch",    label: "Batch",    icon: "queue" },
        { id: "playlist", label: "Playlist", icon: "playlist_play" }
    ]

    property string selectedFormat: Config.options.mediaDownloader.lastUsedFormat || "best"
    property string selectedType: "basic"
    property string extraArgsText: ""
    property bool showAdvancedArgs: Config.options.mediaDownloader.showAdvancedArgs

    // Keyboard navigation focus index
    // -1 = SearchBar (default)
    // 0-2 = Type chips (basic, batch, playlist)
    // 3-8 = Format chips (best, video-mp4, audio-mp3, audio-ogg, audio-opus, audio-m4a)
    // 9+ = Resolution chips (if video format) or Bitrate chips (if audio format)
    // N = Download button
    // N+1 = Cancel button (when visible)
    property int focusedControlIndex: -1

    // Dynamic index calculation for quality chips
    readonly property int qualityChipStartIndex: 9
    readonly property int qualityChipCount: {
        if (root.selectedFormat === "best" || root.selectedFormat.startsWith("video-")) {
            return MediaDownloaderService.videoResolutionOptions.length;
        } else if (root.selectedFormat.startsWith("audio-")) {
            return MediaDownloaderService.audioBitrateOptions.length;
        }
        return 0;
    }
    readonly property int downloadButtonIndex: qualityChipStartIndex + qualityChipCount
    readonly property int cancelButtonIndex: downloadButtonIndex + 1

    // URL validation state
    property bool urlInvalid: false
    property string urlInvalidReason: ""
    property bool showErrorTooltip: false

    function focusInput() {
        focusedControlIndex = 0;
    }

    function navigateDown() {
        if (focusedControlIndex === -1) {
            focusedControlIndex = 0;
        } else if (focusedControlIndex >= 0 && focusedControlIndex <= 2) {
            focusedControlIndex = 3;
        } else if (focusedControlIndex >= 3 && focusedControlIndex <= 8) {
            // Move to quality chips if visible, otherwise to download button
            if (root.qualityChipCount > 0) {
                focusedControlIndex = root.qualityChipStartIndex;
            } else {
                focusedControlIndex = root.downloadButtonIndex;
            }
        } else if (focusedControlIndex >= root.qualityChipStartIndex && 
                   focusedControlIndex < root.qualityChipStartIndex + root.qualityChipCount) {
            focusedControlIndex = root.downloadButtonIndex;
        }
    }

    function navigateUp() {
        if (focusedControlIndex === root.downloadButtonIndex || focusedControlIndex === root.cancelButtonIndex) {
            // Move to quality chips if visible, otherwise to format chips
            if (root.qualityChipCount > 0) {
                focusedControlIndex = root.qualityChipStartIndex + root.qualityChipCount - 1;
            } else {
                focusedControlIndex = 8;
            }
        } else if (focusedControlIndex >= root.qualityChipStartIndex && 
                   focusedControlIndex < root.qualityChipStartIndex + root.qualityChipCount) {
            focusedControlIndex = 3;
        } else if (focusedControlIndex >= 3 && focusedControlIndex <= 8) {
            focusedControlIndex = 0;
        } else if (focusedControlIndex >= 0 && focusedControlIndex <= 2) {
            focusedControlIndex = -1;
        }
    }

    function navigateLeft() {
        if (focusedControlIndex > 0 && focusedControlIndex <= 2) {
            focusedControlIndex--;
        } else if (focusedControlIndex > 3 && focusedControlIndex <= 8) {
            focusedControlIndex--;
        } else if (focusedControlIndex > root.qualityChipStartIndex && 
                   focusedControlIndex < root.qualityChipStartIndex + root.qualityChipCount) {
            focusedControlIndex--;
        }
    }

    function navigateRight() {
        if (focusedControlIndex >= 0 && focusedControlIndex < 2) {
            focusedControlIndex++;
        } else if (focusedControlIndex >= 3 && focusedControlIndex < 8) {
            focusedControlIndex++;
        } else if (focusedControlIndex >= root.qualityChipStartIndex && 
                   focusedControlIndex < root.qualityChipStartIndex + root.qualityChipCount - 1) {
            focusedControlIndex++;
        }
    }

    function activateSelected() {
        if (focusedControlIndex >= 0 && focusedControlIndex <= 2) {
            root.selectedType = root.typeOptions[focusedControlIndex].id;
        } else if (focusedControlIndex >= 3 && focusedControlIndex <= 8) {
            root.selectedFormat = root.formatOptions[focusedControlIndex - 3].id;
            Config.options.mediaDownloader.lastUsedFormat = root.selectedFormat;
        } else if (focusedControlIndex >= root.qualityChipStartIndex && 
                   focusedControlIndex < root.qualityChipStartIndex + root.qualityChipCount) {
            const chipIndex = focusedControlIndex - root.qualityChipStartIndex;
            if (root.selectedFormat === "best" || root.selectedFormat.startsWith("video-")) {
                Config.options.mediaDownloader.videoResolution = MediaDownloaderService.videoResolutionOptions[chipIndex].value;
            } else if (root.selectedFormat.startsWith("audio-")) {
                Config.options.mediaDownloader.audioBitrate = MediaDownloaderService.audioBitrateOptions[chipIndex].value;
            }
        } else if (focusedControlIndex === root.downloadButtonIndex) {
            startDownloadAction();
        } else if (focusedControlIndex === root.cancelButtonIndex) {
            MediaDownloaderService.cancelDownload();
        }
    }

    function startDownloadAction() {
        const validation = MediaDownloaderService.validateUrl(root.searchQuery);
        if (!validation.ok) {
            root.urlInvalid = true;
            root.urlInvalidReason = validation.reason;
            root.showErrorTooltip = true;
            errorTooltipTimer.restart();
            urlShakeAnim.restart();
            return;
        }
        root.urlInvalid = false;
        root.urlInvalidReason = "";

        // Add to queue instead of direct download
        const result = MediaDownloaderService.addToQueue(
            root.searchQuery,
            root.selectedFormat,
            root.selectedType,
            root.extraArgsText
        );
        if (!result.ok) {
            root.urlInvalid = true;
            root.urlInvalidReason = result.reason;
            root.showErrorTooltip = true;
            errorTooltipTimer.restart();
            urlShakeAnim.restart();
        }
    }

    function pasteFromClipboard() {
        const clipboardText = Quickshell.clipboardText;
        if (clipboardText) {
            root.searchQuery = clipboardText;
        }
    }

    // Sync search query → url display, and reset panel focus on query changes
    onSearchQueryChanged: {
        root.urlInvalid = false;
        root.urlInvalidReason = "";
        root.showErrorTooltip = false;
        errorTooltipTimer.stop();
        focusedControlIndex = -1;
        // Fetch thumbnail for valid URLs
        if (root.searchQuery && root.searchQuery.match(/^https?:\/\/[^\s]/i)) {
            thumbnailFetchTimer.restart();
            // Auto-detect format from URL
            const detectedFormat = MediaDownloaderService.detectFormatFromUrl(root.searchQuery);
            if (detectedFormat && detectedFormat !== root.selectedFormat) {
                root.selectedFormat = detectedFormat;
                Config.options.mediaDownloader.lastUsedFormat = detectedFormat;
            }
        } else {
            MediaDownloaderService.thumbnailUrl = "";
            MediaDownloaderService.thumbnailTitle = "";
        }
    }

    // Debounce thumbnail fetch to avoid rapid requests while typing
    Timer {
        id: thumbnailFetchTimer
        interval: 800
        repeat: false
        onTriggered: {
            if (root.searchQuery && root.searchQuery.match(/^https?:\/\/[^\s]/i)) {
                MediaDownloaderService.fetchThumbnail(root.searchQuery);
            }
        }
    }

    // ── Error shake animation ────────────────────────────────────────────────
    SequentialAnimation {
        id: urlShakeAnim
        loops: 2
        NumberAnimation {
            target: urlPreviewPill
            property: "x"
            from: 0; to: -6
            duration: 50
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: urlPreviewPill
            property: "x"
            from: -6; to: 6
            duration: 100
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: urlPreviewPill
            property: "x"
            from: 6; to: 0
            duration: 50
            easing.type: Easing.InQuad
        }
    }

    // ── Main layout ──────────────────────────────────────────────────────────
    ColumnLayout {
        id: mainColumn
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // ── StatusHero (52px) ────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            implicitHeight: 44
            spacing: 10

            // Status pill
            Rectangle {
                implicitWidth: statusRow.implicitWidth + 20
                implicitHeight: 32
                radius: Appearance.rounding.full
                color: {
                    switch (MediaDownloaderService.currentStatus) {
                    case "downloading": return Appearance.colors.colPrimaryContainer;
                    case "preparing": return Appearance.colors.colTertiaryContainer;
                    case "converting": return Appearance.colors.colSecondaryContainer;
                    case "error": return Appearance.colors.colErrorContainer;
                    case "checking": return Appearance.colors.colTertiaryContainer;
                    case "cancelling": return Appearance.colors.colSecondaryContainer;
                    default: return Appearance.colors.colSurfaceContainerHigh;
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Easing.OutQuad
                    }
                }

                RowLayout {
                    id: statusRow
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialLoadingIndicator {
                        visible: MediaDownloaderService.currentStatus === "checking" ||
                                 MediaDownloaderService.currentStatus === "preparing" ||
                                 MediaDownloaderService.currentStatus === "converting"
                        implicitSize: 16
                    }

                    MaterialSymbol {
                        visible: !statusRow.children[0].visible
                        text: {
                            switch (MediaDownloaderService.currentStatus) {
                            case "downloading": return "downloading";
                            case "error": return "error";
                            case "idle": return "check_circle";
                            default: return "hourglass_empty";
                            }
                        }
                        iconSize: 14
                        fill: MediaDownloaderService.currentStatus === "idle" ? 1.0 : 0.0
                        color: {
                            switch (MediaDownloaderService.currentStatus) {
                            case "downloading": return Appearance.colors.colOnPrimaryContainer;
                            case "error": return Appearance.colors.colOnErrorContainer;
                            case "checking":
                            case "preparing":
                            case "converting": return Appearance.colors.colOnTertiaryContainer;
                            default: return Appearance.colors.colOnSurfaceVariant;
                            }
                        }
                    }

                    StyledText {
                        text: {
                            switch (MediaDownloaderService.currentStatus) {
                            case "downloading": return "Downloading " + Math.round(MediaDownloaderService.downloadProgress * 100) + "%";
                            case "preparing": return "Preparing";
                            case "converting": return "Converting";
                            case "error": return "Error";
                            case "checking": return "Checking";
                            case "cancelling": return "Cancelling";
                            case "idle": return MediaDownloaderService.ready ? "Ready" : "Not ready";
                            default: return "";
                            }
                        }
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: {
                            switch (MediaDownloaderService.currentStatus) {
                            case "downloading": return Appearance.colors.colOnPrimaryContainer;
                            case "error": return Appearance.colors.colOnErrorContainer;
                            case "checking":
                            case "preparing":
                            case "converting": return Appearance.colors.colOnTertiaryContainer;
                            default: return Appearance.colors.colOnSurfaceVariant;
                            }
                        }
                    }
                }
            }

            // URL Preview pill (read-only)
            Rectangle {
                id: urlPreviewPill
                Layout.fillWidth: true
                implicitHeight: 36
                radius: Appearance.rounding.full
                color: root.urlInvalid
                       ? Appearance.colors.colErrorContainer
                       : Appearance.colors.colSurfaceContainerLow

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Easing.OutQuad
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    MaterialSymbol {
                        text: root.urlInvalid ? "error" : "link"
                        iconSize: 16
                        fill: root.urlInvalid ? 1.0 : 0.0
                        color: root.urlInvalid
                               ? Appearance.colors.colOnErrorContainer
                               : Appearance.colors.colOnSurfaceVariant

                        Behavior on fill {
                            NumberAnimation {
                                duration: Appearance.animation.elementMoveFast.duration
                                easing.type: Easing.OutQuad
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.searchQuery || "Enter URL here..."
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.family: Appearance.font.family.monospace
                        color: root.urlInvalid
                               ? Appearance.colors.colOnErrorContainer
                               : (root.searchQuery ? Appearance.colors.colOnSurface : Appearance.colors.colOnSurfaceVariant)
                        elide: Text.ElideMiddle
                        maximumLineCount: 1
                    }

                    RippleButton {
                        visible: root.searchQuery !== ""
                        implicitWidth: 24
                        implicitHeight: 24
                        buttonRadius: Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colors.colSurfaceContainerHighest
                        colRipple: Appearance.colors.colPrimary

                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "close"
                            iconSize: 14
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                        onClicked: root.searchQuery = ""
                    }
                }

                StyledToolTip {
                    text: root.urlInvalidReason
                    visible: root.showErrorTooltip && root.urlInvalid
                    parent: urlPreviewPill
                }

                // Auto-hide error tooltip after 3s
                Timer {
                    id: errorTooltipTimer
                    interval: 3000
                    repeat: false
                    onTriggered: root.showErrorTooltip = false
                }

                MouseArea {
                    id: urlPreviewMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.IBeamCursor
                }
            }

            // Paste from clipboard button
            RippleButton {
                implicitWidth: 36
                implicitHeight: 36
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colSurfaceContainerHigh
                colBackgroundHover: Appearance.colors.colSurfaceContainerHighHover
                colRipple: Appearance.colors.colPrimary

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "content_paste"
                    iconSize: 18
                    color: Appearance.colors.colOnSurfaceVariant
                }

                onClicked: root.pasteFromClipboard()

                StyledToolTip {
                    text: "Paste from clipboard"
                }
            }
        }

        // ── ControlSurface (horizontal split) ────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            // ── Settings column ──────────────────────────────────────────────
            ColumnLayout {
                Layout.maximumWidth: Math.round(root.panelWidth * 0.45)
                Layout.minimumWidth: Math.round(root.panelWidth * 0.30)
                Layout.fillHeight: true
                spacing: 8

                // Download Type (segmented button style - fill width)
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: typeColumn.implicitHeight + 16
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colSurfaceContainerLow
                    border.width: root.focusedControlIndex >= 0 && root.focusedControlIndex <= 2 ? 1 : 0
                    border.color: root.focusedControlIndex >= 0 && root.focusedControlIndex <= 2
                                  ? Appearance.colors.colOutline
                                  : "transparent"

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Easing.OutQuad
                        }
                    }

                    ColumnLayout {
                        id: typeColumn
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            MaterialSymbol {
                                text: "category"
                                iconSize: 18
                                fill: 1.0
                                color: Appearance.colors.colOnSurfaceVariant
                            }

                            StyledText {
                                text: "Type"
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnSurface
                                Layout.fillWidth: true
                            }
                        }

                        ButtonGroup {
                            id: typeButtonGroup
                        }

                        Repeater {
                            model: root.typeOptions
                            delegate: RippleButton {
                                required property var modelData
                                required property int index

                                Layout.fillWidth: true
                                implicitHeight: 36
                                buttonRadius: Appearance.rounding.normal
                                colBackground: root.focusedControlIndex === index
                                               ? Appearance.colors.colTertiaryContainer
                                               : (root.selectedType === modelData.id
                                                  ? Appearance.colors.colPrimaryContainer
                                                  : "transparent")
                                colBackgroundHover: root.selectedType === modelData.id
                                                     ? Appearance.colors.colPrimaryContainerHover
                                                     : Appearance.colors.colTertiaryContainerHover
                                colRipple: Appearance.colors.colPrimary

                                Behavior on colBackground {
                                    ColorAnimation {
                                        duration: Appearance.animation.elementMoveFast.duration
                                        easing.type: Easing.OutQuad
                                    }
                                }

                                HoverHandler {
                                    cursorShape: Qt.PointingHandCursor
                                }

                                contentItem: RowLayout {
                                    spacing: 8

                                    Item { width: 4 }

                                    MaterialSymbol {
                                        text: modelData.icon
                                        iconSize: 16
                                        fill: root.selectedType === modelData.id ? 1.0 : 0.0
                                        color: root.focusedControlIndex === index
                                               ? Appearance.colors.colOnTertiaryContainer
                                               : (root.selectedType === modelData.id
                                                  ? Appearance.colors.colOnPrimaryContainer
                                                  : Appearance.colors.colOnSurface)
                                    }

                                    StyledText {
                                        text: modelData.label
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: root.focusedControlIndex === index
                                               ? Appearance.colors.colOnTertiaryContainer
                                               : (root.selectedType === modelData.id
                                                  ? Appearance.colors.colOnPrimaryContainer
                                                  : Appearance.colors.colOnSurface)
                                        Layout.fillWidth: true
                                    }
                                }

                                onClicked: {
                                    root.focusedControlIndex = index;
                                    root.selectedType = modelData.id;
                                }
                            }
                        }
                    }
                }

                // Format chips (fill width)
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: formatColumn.implicitHeight + 16
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colSurfaceContainerLow
                    border.width: root.focusedControlIndex >= 3 && root.focusedControlIndex <= 8 ? 1 : 0
                    border.color: root.focusedControlIndex >= 3 && root.focusedControlIndex <= 8
                                  ? Appearance.colors.colOutline
                                  : "transparent"

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Easing.OutQuad
                        }
                    }

                    ColumnLayout {
                        id: formatColumn
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            MaterialSymbol {
                                text: "description"
                                iconSize: 18
                                fill: 1.0
                                color: Appearance.colors.colOnSurfaceVariant
                            }

                            StyledText {
                                text: "Format"
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnSurface
                                Layout.fillWidth: true
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: 4

                            Repeater {
                                model: root.formatOptions
                                delegate: RippleButton {
                                    required property var modelData
                                    required property int index

                                    implicitWidth: formatChipContent.implicitWidth + 20
                                    implicitHeight: 32
                                    buttonRadius: Appearance.rounding.full
                                    colBackground: root.focusedControlIndex === (3 + index)
                                                   ? Appearance.colors.colTertiaryContainer
                                                   : (root.selectedFormat === modelData.id
                                                       ? Appearance.colors.colSecondaryContainer
                                                       : Appearance.colors.colSurfaceContainerHigh)
                                    colBackgroundHover: root.selectedFormat === modelData.id
                                                          ? Appearance.colors.colSecondaryContainerHover
                                                          : Appearance.colors.colTertiaryContainer
                                    colRipple: Appearance.colors.colPrimary

                                    Behavior on colBackground {
                                        ColorAnimation {
                                            duration: Appearance.animation.elementMoveFast.duration
                                            easing.type: Easing.OutQuad
                                        }
                                    }

                                    HoverHandler {
                                        cursorShape: Qt.PointingHandCursor
                                    }

                                    RowLayout {
                                        id: formatChipContent
                                        anchors.centerIn: parent
                                        spacing: 6

                                        MaterialSymbol {
                                            text: modelData.icon
                                            iconSize: 14
                                            fill: root.selectedFormat === modelData.id ? 1.0 : 0.0
                                            color: root.selectedFormat === modelData.id
                                                   ? Appearance.colors.colOnSecondaryContainer
                                                   : Appearance.colors.colOnSurface
                                        }

                                        StyledText {
                                            text: modelData.label
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: root.focusedControlIndex === (3 + index)
                                                   ? Appearance.colors.colOnTertiaryContainer
                                                   : (root.selectedFormat === modelData.id
                                                      ? Appearance.colors.colOnSecondaryContainer
                                                      : Appearance.colors.colOnSurface)
                                        }
                                    }

                                    onClicked: {
                                        root.focusedControlIndex = 3 + index;
                                        root.selectedFormat = modelData.id;
                                        Config.options.mediaDownloader.lastUsedFormat = modelData.id;
                                    }
                                }
                            }
                        }
                    }
                }

                // Quality options (resolution for video, bitrate for audio)
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: qualityColumn.implicitHeight + 16
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colSurfaceContainerLow
                    visible: root.selectedFormat !== "best"
                    border.width: root.focusedControlIndex >= root.qualityChipStartIndex &&
                                  root.focusedControlIndex <= root.downloadButtonIndex - 1 ? 1 : 0
                    border.color: root.focusedControlIndex >= root.qualityChipStartIndex &&
                                  root.focusedControlIndex <= root.downloadButtonIndex - 1
                                  ? Appearance.colors.colOutline
                                  : "transparent"

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Easing.OutQuad
                        }
                    }

                    Behavior on implicitHeight {
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Easing.OutQuad
                        }
                    }

                    ColumnLayout {
                        id: qualityColumn
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            MaterialSymbol {
                                text: "tune"
                                iconSize: 18
                                fill: 1.0
                                color: Appearance.colors.colOnSurfaceVariant
                            }

                            StyledText {
                                text: "Quality"
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnSurface
                                Layout.fillWidth: true
                            }
                        }

                        // Video quality options
                        ColumnLayout {
                            visible: root.selectedFormat.startsWith("video") || root.selectedFormat === "best"
                            Layout.fillWidth: true
                            spacing: 4

                            StyledText {
                                text: "Resolution"
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnSurface
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: 4

                                Repeater {
                                    model: MediaDownloaderService.videoResolutionOptions
                                    delegate: RippleButton {
                                        required property var modelData
                                        required property int index

                                        implicitWidth: resChipContent.implicitWidth + 16
                                        implicitHeight: 28
                                        buttonRadius: Appearance.rounding.full
                                        colBackground: root.focusedControlIndex === (root.qualityChipStartIndex + index)
                                                       ? Appearance.colors.colTertiaryContainer
                                                       : (Config.options.mediaDownloader.videoResolution === modelData.value
                                                          ? Appearance.colors.colTertiaryContainer
                                                          : Appearance.colors.colSurfaceContainerHigh)
                                         colBackgroundHover: Config.options.mediaDownloader.videoResolution === modelData.value
                                                              ? Appearance.colors.colTertiaryContainerHover
                                                              : Appearance.colors.colTertiaryContainer

                                        HoverHandler {
                                            cursorShape: Qt.PointingHandCursor
                                        }

                                        RowLayout {
                                            id: resChipContent
                                            anchors.centerIn: parent
                                            spacing: 0

                                            StyledText {
                                                text: modelData.label
                                                font.pixelSize: Appearance.font.pixelSize.small
                                                color: Config.options.mediaDownloader.videoResolution === modelData.value
                                                       ? Appearance.colors.colOnTertiaryContainer
                                                       : Appearance.colors.colOnSurface
                                            }
                                        }

                                        onClicked: {
                                            Config.options.mediaDownloader.videoResolution = modelData.value;
                                        }
                                    }
                                }
                            }
                        }

                        // Audio quality options
                        ColumnLayout {
                            visible: root.selectedFormat.startsWith("audio")
                            Layout.fillWidth: true
                            spacing: 4

                            StyledText {
                                text: "Bitrate"
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnSurface
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: 4

                                Repeater {
                                    model: MediaDownloaderService.audioBitrateOptions
                                    delegate: RippleButton {
                                        required property var modelData
                                        required property int index

                                        implicitWidth: bitrateChipContent.implicitWidth + 16
                                        implicitHeight: 28
                                        buttonRadius: Appearance.rounding.full
                                        colBackground: root.focusedControlIndex === (root.qualityChipStartIndex + index)
                                                       ? Appearance.colors.colTertiaryContainer
                                                       : (Config.options.mediaDownloader.audioBitrate === modelData.value
                                                          ? Appearance.colors.colTertiaryContainer
                                                          : Appearance.colors.colSurfaceContainerHigh)
                                         colBackgroundHover: Config.options.mediaDownloader.audioBitrate === modelData.value
                                                              ? Appearance.colors.colTertiaryContainerHover
                                                              : Appearance.colors.colTertiaryContainer

                                        HoverHandler {
                                            cursorShape: Qt.PointingHandCursor
                                        }

                                        RowLayout {
                                            id: bitrateChipContent
                                            anchors.centerIn: parent
                                            spacing: 0

                                            StyledText {
                                                text: modelData.label
                                                font.pixelSize: Appearance.font.pixelSize.small
                                                color: Config.options.mediaDownloader.audioBitrate === modelData.value
                                                       ? Appearance.colors.colOnTertiaryContainer
                                                       : Appearance.colors.colOnSurface
                                            }
                                        }

                                        onClicked: {
                                            Config.options.mediaDownloader.audioBitrate = modelData.value;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Advanced args (collapsible)
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: argsColumn.implicitHeight + 16
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colSurfaceContainerLow

                    ColumnLayout {
                        id: argsColumn
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            MaterialSymbol {
                                text: "terminal"
                                iconSize: 18
                                fill: 1.0
                                color: Appearance.colors.colOnSurfaceVariant
                            }

                            StyledText {
                                text: "Advanced args"
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnSurface
                                Layout.fillWidth: true
                            }

                            RippleButton {
                                implicitWidth: 24
                                implicitHeight: 24
                                buttonRadius: Appearance.rounding.full
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colSurfaceContainerHighest

                                HoverHandler {
                                    cursorShape: Qt.PointingHandCursor
                                }

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: root.showAdvancedArgs ? "expand_less" : "expand_more"
                                    iconSize: 16
                                    color: Appearance.colors.colOnSurfaceVariant
                                }

                                onClicked: {
                                    root.showAdvancedArgs = !root.showAdvancedArgs;
                                    Config.options.mediaDownloader.showAdvancedArgs = root.showAdvancedArgs;
                                }
                            }
                        }

                        ColumnLayout {
                            visible: root.showAdvancedArgs
                            Layout.fillWidth: true
                            spacing: 6

                            Behavior on visible {
                                NumberAnimation {
                                    target: this
                                    property: "opacity"
                                    from: visible ? 0 : 1
                                    to: visible ? 1 : 0
                                    duration: Appearance.animation.elementMoveFast.duration
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 60
                                radius: Appearance.rounding.small
                                color: Appearance.colors.colSurfaceContainer

                                TextInput {
                                    id: argsField
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    text: root.extraArgsText
                                    color: Appearance.colors.colOnSurface
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.family: Appearance.font.family.monospace
                                    clip: true
                                    selectByMouse: true
                                    onTextChanged: root.extraArgsText = text

                                    Text {
                                        anchors.fill: parent
                                        text: "--cookies-from-browser firefox..."
                                        color: Appearance.colors.colOnSurfaceVariant
                                        font: parent.font
                                        visible: parent.text === ""
                                    }
                                }
                            }
                        }
                    }
                }

                // Error box for missing dependencies
                Rectangle {
                    visible: !MediaDownloaderService.ytdlpFound && MediaDownloaderService.ready
                    Layout.fillWidth: true
                    implicitHeight: errorRow.implicitHeight + 24
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colErrorContainer

                    RowLayout {
                        id: errorRow
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        MaterialSymbol {
                            text: "error"
                            iconSize: 20
                            fill: 1.0
                            color: Appearance.colors.colOnErrorContainer
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: "yt-dlp not found"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnErrorContainer
                        }

                        StyledText {
                            text: "Install: sudo pacman -S yt-dlp"
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.family: Appearance.font.family.monospace
                            color: Appearance.colors.colOnErrorContainer
                            opacity: 0.8
                        }
                    }
                }

                // Warning box for missing ffmpeg (audio formats)
                WarningBox {
                    visible: !MediaDownloaderService.ffmpegFound &&
                             (root.selectedFormat.startsWith("audio")) &&
                             MediaDownloaderService.ready
                    Layout.fillWidth: true
                    text: "ffmpeg missing — audio conversion unavailable"
                }

                // Download queue (when items exist)
                Rectangle {
                    visible: MediaDownloaderService.downloadQueue.length > 0
                    Layout.fillWidth: true
                    implicitHeight: queueColumn.implicitHeight + 16
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colSurfaceContainerLow

                    ColumnLayout {
                        id: queueColumn
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            MaterialSymbol {
                                text: "queue"
                                iconSize: 18
                                fill: 1.0
                                color: Appearance.colors.colOnSurfaceVariant
                            }

                            StyledText {
                                text: "Queue (" + MediaDownloaderService.downloadQueue.length + ")"
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnSurface
                                Layout.fillWidth: true
                            }

                            RippleButton {
                                visible: MediaDownloaderService.downloadQueue.some(item => item.status === "queued")
                                implicitWidth: 24
                                implicitHeight: 24
                                buttonRadius: Appearance.rounding.full
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colSurfaceContainerHighest

                                HoverHandler {
                                    cursorShape: Qt.PointingHandCursor
                                }

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "clear_all"
                                    iconSize: 16
                                    color: Appearance.colors.colOnSurfaceVariant
                                }

                                onClicked: MediaDownloaderService.clearQueue()

                                StyledToolTip {
                                    text: "Clear queued items"
                                }
                            }
                        }

                        Repeater {
                            model: MediaDownloaderService.downloadQueue.slice(0, 5)
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 32
                                radius: Appearance.rounding.small
                                color: {
                                    switch (modelData.status) {
                                    case "downloading": return Appearance.colors.colPrimaryContainer;
                                    case "complete": return Appearance.colors.colSecondaryContainer;
                                    case "error": return Appearance.colors.colErrorContainer;
                                    default: return Appearance.colors.colSurfaceContainer;
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 6

                                    MaterialSymbol {
                                        text: {
                                            switch (modelData.status) {
                                            case "downloading": return "downloading";
                                            case "complete": return "check_circle";
                                            case "error": return "error";
                                            default: return "schedule";
                                            }
                                        }
                                        iconSize: 14
                                        fill: modelData.status === "complete" ? 1.0 : 0.0
                                        color: {
                                            switch (modelData.status) {
                                            case "downloading": return Appearance.colors.colOnPrimaryContainer;
                                            case "complete": return Appearance.colors.colOnSecondaryContainer;
                                            case "error": return Appearance.colors.colOnErrorContainer;
                                            default: return Appearance.colors.colOnSurfaceVariant;
                                            }
                                        }
                                    }

                                    StyledText {
                                        text: modelData.url.length > 40 ? modelData.url.substring(0, 40) + "..." : modelData.url
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        font.family: Appearance.font.family.monospace
                                        color: {
                                            switch (modelData.status) {
                                            case "downloading": return Appearance.colors.colOnPrimaryContainer;
                                            case "complete": return Appearance.colors.colOnSecondaryContainer;
                                            case "error": return Appearance.colors.colOnErrorContainer;
                                            default: return Appearance.colors.colOnSurfaceVariant;
                                            }
                                        }
                                        elide: Text.ElideMiddle
                                        Layout.fillWidth: true
                                    }

                                    RippleButton {
                                        visible: modelData.status === "queued"
                                        implicitWidth: 20
                                        implicitHeight: 20
                                        buttonRadius: Appearance.rounding.full
                                        colBackground: "transparent"
                                        colBackgroundHover: Appearance.colors.colSurfaceContainerHighest

                                        HoverHandler {
                                            cursorShape: Qt.PointingHandCursor
                                        }

                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: "close"
                                            iconSize: 12
                                            color: Appearance.colors.colOnSurfaceVariant
                                        }

                                        onClicked: MediaDownloaderService.removeFromQueue(modelData.id)
                                    }
                                }
                            }
                        }

                        StyledText {
                            visible: MediaDownloaderService.downloadQueue.length > 5
                            text: "+ " + (MediaDownloaderService.downloadQueue.length - 5) + " more..."
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colOnSurfaceVariant
                            opacity: 0.7
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                }
            }

            // ── Log column ───────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 200
                radius: Appearance.rounding.normal
                color: Appearance.colors.colSurfaceContainer

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    // Thumbnail preview (when available)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(180, parent.width * 0.5625)
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colSurfaceContainerLow
                        clip: true
                        visible: MediaDownloaderService.thumbnailUrl !== ""

                        Image {
                            anchors.fill: parent
                            source: MediaDownloaderService.thumbnailUrl
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true

                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.width: 1
                                border.color: Appearance.colors.colOutlineVariant
                                radius: parent.radius
                            }
                        }

                        // Title overlay at bottom
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: titleText.implicitHeight + 16
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.7) }
                            }

                            StyledText {
                                id: titleText
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                anchors.bottomMargin: 8
                                text: MediaDownloaderService.thumbnailTitle
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: "white"
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.Wrap
                            }
                        }

                        // Loading indicator while fetching
                        MaterialLoadingIndicator {
                            anchors.centerIn: parent
                            implicitSize: 24
                            visible: MediaDownloaderService.thumbnailLoading
                        }
                    }

                    // Log header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        MaterialSymbol {
                            text: "terminal"
                            iconSize: 14
                            color: Appearance.colors.colOnSurfaceVariant
                        }

                        StyledText {
                            text: "Log"
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colOnSurfaceVariant
                            Layout.fillWidth: true
                        }

                        // Progress stats (when downloading)
                        StyledText {
                            visible: MediaDownloaderService.parsedStats.phase === "downloading"
                            text: {
                                const stats = MediaDownloaderService.parsedStats;
                                if (stats.size && stats.speed && stats.eta) {
                                    return stats.size + " · " + stats.speed + " · ETA " + stats.eta;
                                }
                                return Math.round(MediaDownloaderService.downloadProgress * 100) + "%";
                            }
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.family: Appearance.font.family.monospace
                            color: Appearance.colors.colPrimary
                        }

                        // Clear log button
                        RippleButton {
                            implicitWidth: 24
                            implicitHeight: 24
                            buttonRadius: Appearance.rounding.full
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.colors.colSurfaceContainerHighest
                            colRipple: Appearance.colors.colPrimary

                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                            }

                            onClicked: MediaDownloaderService.clearLog()

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "delete_sweep"
                                iconSize: 14
                                color: Appearance.colors.colOnSurfaceVariant
                            }
                        }
                    }

                    // Log content
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colSurfaceContainerLow
                        clip: true

                        StyledFlickable {
                            id: logFlickable
                            anchors.fill: parent
                            anchors.margins: 6
                            contentWidth: width
                            contentHeight: logText.implicitHeight
                            clip: true

                            Text {
                                id: logText
                                width: logFlickable.width
                                text: MediaDownloaderService.logOutput
                                color: Appearance.colors.colOnSurface
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.family: Appearance.font.family.monospace
                                wrapMode: Text.Wrap

                                onImplicitHeightChanged: {
                                    if (logFlickable.atYEnd || logFlickable.contentY > logFlickable.contentHeight - logFlickable.height - 50) {
                                        logFlickable.contentY = Math.max(0, logText.implicitHeight - logFlickable.height);
                                    }
                                }
                            }
                        }

                        // Empty state
                        ColumnLayout {
                            anchors.centerIn: parent
                            visible: MediaDownloaderService.logOutput === ""
                            spacing: 8

                            MaterialLoadingIndicator {
                                visible: MediaDownloaderService.currentStatus === "checking"
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: 20
                                implicitHeight: 20
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: MediaDownloaderService.currentStatus === "checking"
                                      ? "Checking dependencies..."
                                      : "Waiting for output..."
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnSurfaceVariant
                            }
                        }
                    }

                    // Progress bar
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: MediaDownloaderService.isDownloading ||
                                 MediaDownloaderService.currentStatus === "preparing" ||
                                 MediaDownloaderService.currentStatus === "converting"
                        spacing: 4

                        Behavior on visible {
                            NumberAnimation {
                                target: this
                                property: "opacity"
                                from: visible ? 0 : 1
                                to: visible ? 1 : 0
                                duration: Appearance.animation.elementMoveFast.duration
                            }
                        }

                        Loader {
                            Layout.fillWidth: true
                            readonly property bool useIndeterminate: MediaDownloaderService.currentStatus === "preparing" ||
                                                                     MediaDownloaderService.currentStatus === "converting"

                            sourceComponent: useIndeterminate ? indeterminateProgressComp : determinateProgressComp

                            Component {
                                id: determinateProgressComp
                                StyledProgressBar {
                                    value: MediaDownloaderService.downloadProgress
                                }
                            }

                            Component {
                                id: indeterminateProgressComp
                                StyledIndeterminateProgressBar {}
                            }
                        }

                        StyledText {
                            text: {
                                switch (MediaDownloaderService.currentStatus) {
                                case "preparing": return "Preparing download...";
                                case "converting": return "Converting...";
                                case "downloading": return Math.round(MediaDownloaderService.downloadProgress * 100) + "%";
                                default: return "";
                                }
                            }
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                    }
                }
            }
        }

        // ── ActionRow ────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            implicitHeight: 44
            spacing: 8

            // Download button
            RippleButton {
                id: downloadBtn
                Layout.fillWidth: MediaDownloaderService.isDownloading ? false : true
                implicitWidth: MediaDownloaderService.isDownloading ? 0 : implicitHeight
                implicitHeight: 44
                buttonRadius: Appearance.rounding.normal
                colBackground: root.focusedControlIndex === root.downloadButtonIndex
                               ? Appearance.colors.colPrimaryContainerHover
                               : Appearance.colors.colPrimaryContainer
                colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                colRipple: Appearance.colors.colOnPrimaryContainer
                clip: true

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }

                Behavior on implicitWidth {
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Easing.OutQuad
                    }
                }

                visible: !MediaDownloaderService.isDownloading &&
                         MediaDownloaderService.currentStatus !== "cancelling"

                Behavior on visible {
                    NumberAnimation {
                        target: this
                        property: "opacity"
                        from: visible ? 0 : 1
                        to: visible ? 1 : 0
                        duration: Appearance.animation.elementMoveFast.duration
                    }
                }

                enabled: MediaDownloaderService.ready && MediaDownloaderService.ytdlpFound

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialSymbol {
                        text: "download"
                        iconSize: 18
                        color: Appearance.colors.colOnPrimaryContainer
                    }

                    StyledText {
                        text: "Download"
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                }

                onClicked: {
                    root.focusedControlIndex = root.downloadButtonIndex;
                    startDownloadAction();
                }
            }

            // Cancel button
            RippleButton {
                id: cancelBtn
                Layout.fillWidth: MediaDownloaderService.isDownloading ? true : false
                implicitWidth: MediaDownloaderService.isDownloading ? implicitHeight : 0
                implicitHeight: 44
                buttonRadius: Appearance.rounding.normal
                colBackground: root.focusedControlIndex === root.cancelButtonIndex
                               ? Appearance.colors.colErrorContainerHover
                               : Appearance.colors.colErrorContainer
                colBackgroundHover: Appearance.colors.colErrorContainerHover
                colRipple: Appearance.colors.colOnErrorContainer
                clip: true

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }

                Behavior on implicitWidth {
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Easing.OutQuad
                    }
                }

                visible: MediaDownloaderService.isDownloading ||
                         MediaDownloaderService.currentStatus === "cancelling"

                Behavior on visible {
                    NumberAnimation {
                        target: this
                        property: "opacity"
                        from: visible ? 0 : 1
                        to: visible ? 1 : 0
                        duration: Appearance.animation.elementMoveFast.duration
                    }
                }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialSymbol {
                        text: "cancel"
                        iconSize: 18
                        color: Appearance.colors.colOnErrorContainer
                    }

                    StyledText {
                        text: "Cancel"
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnErrorContainer
                    }
                }

                onClicked: {
                    root.focusedControlIndex = root.cancelButtonIndex;
                    MediaDownloaderService.cancelDownload();
                }
            }

            // Open folder button (closes search)
            RippleButton {
                implicitWidth: 44
                implicitHeight: 44
                buttonRadius: Appearance.rounding.normal
                colBackground: Appearance.colors.colSurfaceContainerHigh
                colBackgroundHover: Appearance.colors.colSurfaceContainerHighHover
                colRipple: Appearance.colors.colPrimary

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "folder_open"
                    iconSize: 20
                    color: Appearance.colors.colOnSurfaceVariant
                }

                onClicked: {
                    Quickshell.execDetached(["xdg-open", Config.options.mediaDownloader.downloadPath])
                    GlobalStates.overviewOpen = false
                }

                StyledToolTip {
                    text: "Open download folder"
                }
            }
        }

        // ── Keyboard Hints ──────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            implicitHeight: 24
            spacing: 12

            Rectangle {
                implicitWidth: hintRow1.implicitWidth + 12
                implicitHeight: 20
                radius: Appearance.rounding.small
                color: Appearance.colors.colSurfaceContainer

                RowLayout {
                    id: hintRow1
                    anchors.centerIn: parent
                    spacing: 4

                    StyledText {
                        text: "↑↓"
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                    StyledText {
                        text: "Navigate"
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colOnSurfaceVariant
                        opacity: 0.7
                    }
                }
            }

            Rectangle {
                implicitWidth: hintRow2.implicitWidth + 12
                implicitHeight: 20
                radius: Appearance.rounding.small
                color: Appearance.colors.colSurfaceContainer

                RowLayout {
                    id: hintRow2
                    anchors.centerIn: parent
                    spacing: 4

                    StyledText {
                        text: "←→"
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                    StyledText {
                        text: "Switch"
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colOnSurfaceVariant
                        opacity: 0.7
                    }
                }
            }

            Rectangle {
                implicitWidth: hintRow3.implicitWidth + 12
                implicitHeight: 20
                radius: Appearance.rounding.small
                color: Appearance.colors.colSurfaceContainer

                RowLayout {
                    id: hintRow3
                    anchors.centerIn: parent
                    spacing: 4

                    StyledText {
                        text: "Enter"
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                    StyledText {
                        text: "Select"
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colOnSurfaceVariant
                        opacity: 0.7
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }
    }
}
