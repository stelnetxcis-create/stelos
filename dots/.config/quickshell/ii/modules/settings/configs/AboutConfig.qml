import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

ContentPage {
    id: page
    forceWidth: false

    property string activeRemote: ""
    property int forkUpdates: 0
    property int upstreamUpdates: 0
    property bool checkingUpdates: false

    Process {
        id: checkRemoteProc
        command: ["bash", "-c", "if [ -f \"$HOME/.config/quickshell/ii/.active-remote\" ]; then cat \"$HOME/.config/quickshell/ii/.active-remote\"; else for dir in \"$HOME/Downloads/ii-vynx\" \"$HOME/.local/share/ii-vynx-fork\" \"$HOME/.local/share/ii-vynx-upstream\" \"$HOME/.local/share/ii-vynx\" \"$HOME/dotfiles\"; do if git -C \"$dir\" rev-parse --is-inside-work-tree >/dev/null 2>&1; then git -C \"$dir\" remote get-url origin; break; fi; done; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                page.activeRemote = text.trim();
            }
        }
    }

    Process {
        id: checkUpdatesProc
        command: ["bash", "-c", "fork_dir=\"$HOME/Downloads/ii-vynx\"; [ ! -d \"$fork_dir/.git\" ] && fork_dir=\"$HOME/.local/share/ii-vynx-fork\"; [ ! -d \"$fork_dir/.git\" ] && fork_dir=\"$HOME/.config/quickshell/ii-vynx-repo\"; upstream_dir=\"$HOME/.local/share/ii-vynx-upstream\"; fork_updates=0; [ -d \"$fork_dir/.git\" ] && { git -C \"$fork_dir\" fetch --quiet origin 2>/dev/null; fork_updates=$(git -C \"$fork_dir\" rev-list --count HEAD..@{u} 2>/dev/null || echo 0); }; upstream_updates=0; [ -d \"$upstream_dir/.git\" ] && { git -C \"$upstream_dir\" fetch --quiet origin 2>/dev/null; upstream_updates=$(git -C \"$upstream_dir\" rev-list --count HEAD..@{u} 2>/dev/null || echo 0); }; echo \"$fork_updates $upstream_updates\""]

        onStarted: {
            page.checkingUpdates = true;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split(" ");
                if (parts.length === 2) {
                    page.forkUpdates = parseInt(parts[0]) || 0;
                    page.upstreamUpdates = parseInt(parts[1]) || 0;
                }
                page.checkingUpdates = false;
            }
        }
    }

    Component.onCompleted: {
        checkRemoteProc.running = true;
        checkUpdatesProc.running = true;
    }

    onVisibleChanged: {
        if (visible) {
            checkRemoteProc.running = true;
            checkUpdatesProc.running = true;
        }
    }

    readonly property string setupScript: FileUtils.trimFileProtocol(`${Directories.home}/.local/share/ii-vynx/setup-stelos.sh`)

    Process {
        id: actionProc
        property string mode: ""
        property string logOutput: ""
        property int exitCode: -1
        property bool finished: false
        stdout: SplitParser {
            onRead: data => {
                actionProc.logOutput += data + "\n";
            }
        }
        stderr: SplitParser {
            onRead: data => {
                actionProc.logOutput += data + "\n";
            }
        }
        onExited: code => {
            actionProc.exitCode = code;
            actionProc.finished = true;
            if (code === 0) {
                actionProc.logOutput += "✓ Done\n";
                if (actionProc.mode === "update-fork") {
                    Quickshell.execDetached(["bash", page.setupScript, "--force-install", "--no-pull", "--no-confirm", "--preserve-config"]);
                } else if (actionProc.mode === "update-upstream") {
                    Quickshell.execDetached(["bash", page.setupScript, "--force-install", "--no-pull", "--no-confirm", "--ii-vynx", "--preserve-config"]);
                }
            } else {
                actionProc.logOutput += "✗ Exited with code " + code + "\n";
            }
        }
    }

    ContentSection {
        icon: "info"
        title: Translation.tr("System Info")

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 2
            columnSpacing: 2

            ContentSubsection {
                Layout.fillWidth: true
                Layout.fillHeight: true
                topLeftRadius: Appearance.rounding.large
                topRightRadius: Appearance.rounding.verysmall
                bottomLeftRadius: Appearance.rounding.verysmall
                bottomRightRadius: Appearance.rounding.verysmall
                title: Translation.tr("Distro Info")
                icon: "developer_board"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Layout.topMargin: 10
                    Layout.bottomMargin: 10
                    IconImage {
                        implicitSize: 50
                        source: Quickshell.iconPath(SystemInfo.logo)
                    }
                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        StyledText {
                            text: SystemInfo.distroName
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Bold
                        }
                        StyledText {
                            font.pixelSize: Appearance.font.pixelSize.small
                            text: "<a href='" + SystemInfo.homeUrl + "'>" + SystemInfo.homeUrl.replace(/^https?:\/\/(www\.)?/, '') + "</a>"
                            textFormat: Text.RichText
                            onLinkActivated: link => Qt.openUrlExternally(link)
                            PointingHandLinkHover {}
                        }
                    }
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 5
                    RippleButtonWithIcon { materialIcon: "auto_stories"; mainText: Translation.tr("Docs"); onClicked: Qt.openUrlExternally(SystemInfo.documentationUrl) }
                    RippleButtonWithIcon { materialIcon: "bug_report"; mainText: Translation.tr("Bugs"); onClicked: Qt.openUrlExternally(SystemInfo.bugReportUrl) }
                }
            }

            ContentSubsection {
                Layout.fillWidth: true
                Layout.fillHeight: true
                topLeftRadius: Appearance.rounding.verysmall
                topRightRadius: Appearance.rounding.large
                bottomLeftRadius: Appearance.rounding.verysmall
                bottomRightRadius: Appearance.rounding.verysmall
                title: Translation.tr("Parent-Dots Info")
                icon: "account_tree"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Layout.topMargin: 10
                    Layout.bottomMargin: 10
                    IconImage {
                        implicitSize: 50
                        source: Quickshell.iconPath("illogical-impulse")
                    }
                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        StyledText {
                            text: Translation.tr("illogical-impulse")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Bold
                        }
                        StyledText {
                            text: "<a href='https://github.com/end-4/dots-hyprland'>github.com/end-4/dots-hyprland</a>"
                            font.pixelSize: Appearance.font.pixelSize.small
                            textFormat: Text.RichText
                            onLinkActivated: link => Qt.openUrlExternally(link)
                            PointingHandLinkHover {}
                        }
                    }
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 5
                    RippleButtonWithIcon { materialIcon: "auto_stories"; mainText: Translation.tr("Wiki"); onClicked: Qt.openUrlExternally("https://end-4.github.io/dots-hyprland-wiki/en/ii-qs/02usage/") }
                    RippleButtonWithIcon { materialIcon: "favorite"; mainText: Translation.tr("Sponsor"); onClicked: Qt.openUrlExternally("https://github.com/sponsors/end-4") }
                }
            }

            ContentSubsection {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.columnSpan: 2
                topLeftRadius: Appearance.rounding.verysmall
                topRightRadius: Appearance.rounding.verysmall
                bottomLeftRadius: Appearance.rounding.large
                bottomRightRadius: Appearance.rounding.large
                title: Translation.tr("StelOS")
                icon: "call_split"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Layout.topMargin: 10
                    Layout.bottomMargin: 10
                    Image {
                        source: "file://" + Quickshell.shellPath("assets/icons/ii-p3drovfx.png")
                        sourceSize: Qt.size(50, 50)
                        fillMode: Image.PreserveAspectFit
                        width: 50
                        height: 50
                    }
                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        StyledText {
                            text: Translation.tr("StelOS")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Bold
                        }
                        StyledText {
                            text: "<a href='https://github.com/stelnetxcis-create/stelos'>github.com/stelnetxcis-create/stelos</a>"
                            font.pixelSize: Appearance.font.pixelSize.small
                            textFormat: Text.RichText
                            onLinkActivated: link => Qt.openUrlExternally(link)
                            PointingHandLinkHover {}
                        }
                    }
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 5
                    RippleButtonWithIcon { materialIcon: "code"; mainText: Translation.tr("GitHub"); onClicked: Qt.openUrlExternally("https://github.com/stelnetxcis-create/stelos") }
                    RippleButtonWithIcon { materialIcon: "adjust"; materialIconFill: false; mainText: Translation.tr("Issues"); onClicked: Qt.openUrlExternally("https://github.com/stelnetxcis-create/stelos/issues") }
                }
            }
        }
    }

    ContentSection {
        icon: "swap_horiz"
        title: Translation.tr("Git Source & Update Controls")

        ContentSubsection {
            title: Translation.tr("Source updater")
            icon: "update"
            tooltip: Translation.tr("Pull latest changes from GitHub for each source independently")

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                RippleButtonWithIcon {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    buttonRadius: Appearance.rounding.large
                    materialIcon: actionProc.running && actionProc.mode === "update-fork" ? "sync" : "system_update_alt"
                    mainContentComponent: RowLayout {
                        spacing: 8
                        StyledText {
                            text: actionProc.running && actionProc.mode === "update-fork" ? Translation.tr("Updating fork...") : Translation.tr("Update StelOS")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnSecondaryContainer
                        }
                        Rectangle {
                            visible: page.forkUpdates > 0
                            radius: 10
                            color: Appearance.colors.colError
                            implicitWidth: badgeText.implicitWidth + 8
                            implicitHeight: 18
                            Layout.alignment: Qt.AlignVCenter

                            StyledText {
                                id: badgeText
                                anchors.centerIn: parent
                                text: page.forkUpdates
                                font.pixelSize: Appearance.font.pixelSize.verysmall
                                font.weight: Font.Bold
                                color: Appearance.colors.colOnError
                            }
                        }
                    }
                    enabled: !actionProc.running
                    onClicked: {
                        Config.blockWrites = true;
                        actionProc.logOutput = "";
                        actionProc.finished = false;
                        actionProc.exitCode = -1;
                        actionProc.mode = "update-fork";
                        actionProc.command = ["bash", page.setupScript, "--update-only", "--no-confirm"];
                        actionProc.running = true;
                    }
                }
            }


            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 8
                height: 40
                visible: actionProc.finished
                radius: Appearance.rounding.small
                color: ColorUtils.transparentize(actionProc.exitCode === 0 ? Appearance.colors.colPrimary : Appearance.colors.colError, 0.85)
                border.color: actionProc.exitCode === 0 ? Appearance.colors.colPrimary : Appearance.colors.colError
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    MaterialSymbol {
                        text: actionProc.exitCode === 0 ? "check_circle" : "error"
                        iconSize: 20
                        color: actionProc.exitCode === 0 ? Appearance.colors.colPrimary : Appearance.colors.colError
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: actionProc.exitCode === 0 ? Translation.tr("Update completed successfully! Reload the shell to apply.") : Translation.tr("Update failed! Please check the log below.")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer0
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 6
                height: Math.min(250, logText.implicitHeight + 16)
                visible: actionProc.logOutput !== ""
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer0
                border.color: !actionProc.finished ? Appearance.colors.colOutline :
                              (actionProc.exitCode === 0 ? Appearance.colors.colPrimary : Appearance.colors.colError)
                border.width: 1

                StyledFlickable {
                    anchors.fill: parent
                    anchors.margins: 8
                    clip: true
                    contentHeight: logText.implicitHeight
                    contentWidth: width
                    flickableDirection: Flickable.VerticalFlick

                    Text {
                        id: logText
                        width: parent.width
                        text: actionProc.logOutput
                        font.family: "monospace"
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer1
                        wrapMode: Text.WrapAnywhere
                    }
                }
            }
        }

    }

    ContentSection {
        icon: "history"
        title: Translation.tr("Commit History")

                RowLayout {
                    visible: ChangelogService.loading
                    Layout.fillWidth: true
                    spacing: 8
                    MaterialLoadingIndicator {
                        implicitSize: 20
                    }
                    StyledText {
                        text: Translation.tr("Fetching commits...")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                }

                StyledText {
                    visible: !ChangelogService.loading && ChangelogService.commits.count === 0
                    text: Translation.tr("No commits found or repository not available.")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }

                Repeater {
                    model: ChangelogService.commits
                    delegate: Rectangle {
                        id: entryRoot

                        readonly property int itemIndex: {
                            var p = parent;
                            if (!p) return 0;
                            var idx = 0;
                            for (var i = 0; i < p.children.length; ++i) {
                                if (p.children[i] === entryRoot) return idx;
                                if (p.children[i].visible && typeof p.children[i].topLeftRadius !== "undefined") idx++;
                            }
                            return 0;
                        }

                        readonly property int totalItems: {
                            var p = parent;
                            if (!p) return 1;
                            var count = 0;
                            for (var i = 0; i < p.children.length; ++i) {
                                if (p.children[i].visible && typeof p.children[i].topLeftRadius !== "undefined") count++;
                            }
                            return count;
                        }

                        property bool isFirst: itemIndex === 0
                        property bool isLast: itemIndex === totalItems - 1

                        topLeftRadius: isLast ? Appearance.rounding.large : Appearance.rounding.verysmall
                        topRightRadius: isLast ? Appearance.rounding.large : Appearance.rounding.verysmall
                        bottomLeftRadius: isFirst ? Appearance.rounding.large : Appearance.rounding.verysmall
                        bottomRightRadius: isFirst ? Appearance.rounding.large : Appearance.rounding.verysmall


                        readonly property string commitHash: model.hash
                        readonly property string commitTitle: model.title
                        readonly property string commitDescription: model.description
                        readonly property string commitSmartId: model.smartId

                        Layout.fillWidth: true
                        Layout.preferredHeight: layout.implicitHeight + 24

                        radius: Appearance.rounding.large
                        color: Appearance.colors.colLayer2
                        border.width: 0

                        ColumnLayout {
                            id: layout
                            anchors {
                                fill: parent
                                margins: 12
                            }
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true

                                Rectangle {
                                    visible: entryRoot.commitSmartId !== ""
                                    radius: Appearance.rounding.small
                                    color: {
                                        if (!entryRoot.commitSmartId) return Appearance.m3colors.m3surfaceContainerHighest;
                                        let prefix = entryRoot.commitSmartId.charAt(0);
                                        if (prefix === 'A') return Appearance.colors.colPrimaryContainer;
                                        if (prefix === 'B') return Appearance.colors.colErrorContainer || Appearance.colors.colSecondaryContainer;
                                        if (prefix === 'C' || prefix === 'D') return Appearance.colors.colTertiaryContainer || Appearance.colors.colSecondaryContainer;
                                        return Appearance.m3colors.m3surfaceContainerHighest;
                                    }
                                    border.width: 0
                                    implicitWidth: idText.implicitWidth + 16
                                    implicitHeight: idText.implicitHeight + 6

                                    StyledText {
                                        id: idText
                                        anchors.centerIn: parent
                                        text: entryRoot.commitSmartId
                                        font.weight: Font.Bold
                                        font.pixelSize: Appearance.font.pixelSize.smallie
                                        color: {
                                            if (!entryRoot.commitSmartId) return Appearance.colors.colOnSurface;
                                            let prefix = entryRoot.commitSmartId.charAt(0);
                                            if (prefix === 'A') return Appearance.colors.colOnPrimaryContainer;
                                            if (prefix === 'B') return Appearance.colors.colOnErrorContainer || Appearance.colors.colOnSecondaryContainer;
                                            if (prefix === 'C' || prefix === 'D') return Appearance.colors.colOnTertiaryContainer || Appearance.colors.colOnSecondaryContainer;
                                            return Appearance.colors.colOnSurface;
                                        }
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                StyledText {
                                    text: model.date
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colSubtext
                                    opacity: 0.7
                                }
                            }

                            StyledText {
                                text: entryRoot.commitTitle
                                font.weight: Font.Bold
                                font.pixelSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colOnLayer1
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }

                            StyledText {
                                visible: entryRoot.commitDescription !== ""
                                text: entryRoot.commitDescription
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                                opacity: 0.85
                            }
                        }
                    }
                }
    }
}
