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
    readonly property bool isStelosOwner: StelosAccessService.isOwner

    Process {
        id: checkRemoteProc
        command: ["bash", FileUtils.trimFileProtocol(`${Directories.home}/.local/share/ii-stelos/get-active-remote.sh`)]
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
            // Owner status is cached to disk and only re-checked at startup
            // or via the manual refresh button, to avoid re-flashing the
            // User view every time this panel is opened.
        }
    }

    readonly property string setupScript: FileUtils.trimFileProtocol(`${Directories.home}/.local/share/ii-vynx/setup-stelos.sh`)
    readonly property string stelosDir: FileUtils.trimFileProtocol(`${Directories.home}/.local/share/ii-stelos`)
    readonly property string stelosRepoOwner: "stelnetxcis-create"
    readonly property string stelosRepoName: "stelos"
    readonly property string stelosRepoUrl: `https://github.com/${stelosRepoOwner}/${stelosRepoName}`
    readonly property string stelosRepoDisplay: `github.com/${stelosRepoOwner}/${stelosRepoName}`
    readonly property string stelosSetupScript: FileUtils.trimFileProtocol(`${Directories.home}/.local/share/ii-stelos/setup-stelos-repo.sh`)
    readonly property string stelosPushScript: FileUtils.trimFileProtocol(`${Directories.home}/.local/share/ii-stelos/push-stelos.sh`)
    readonly property string stelosSyncScript: FileUtils.trimFileProtocol(`${Directories.home}/.local/share/ii-stelos/sync-live-config.sh`)
    readonly property string stelosPullApplyScript: FileUtils.trimFileProtocol(`${Directories.home}/.local/share/ii-stelos/pull-and-apply.sh`)

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
            } else {
                actionProc.logOutput += "✗ Exited with code " + code + "\n";
            }
        }
    }

    // ── StelOS Pull / Push / Construct ──────────────────────────────────────
    Process {
        id: stelosProc
        property string mode: ""
        property string logOutput: ""
        property int exitCode: -1
        property bool finished: false
        stdout: SplitParser {
            onRead: data => { stelosProc.logOutput += data + "\n"; }
        }
        stderr: SplitParser {
            onRead: data => { stelosProc.logOutput += data + "\n"; }
        }
        onExited: code => {
            stelosProc.exitCode = code;
            stelosProc.finished = true;
            stelosProc.logOutput += code === 0 ? "✓ Done\n" : ("✗ Exited with code " + code + "\n");
        }
    }

    function runStelosAction(mode, command) {
        stelosProc.logOutput = "";
        stelosProc.finished = false;
        stelosProc.exitCode = -1;
        stelosProc.mode = mode;
        stelosProc.command = command;
        stelosProc.running = true;
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
                topLeftRadius: Appearance.rounding.verysmall
                topRightRadius: Appearance.rounding.verysmall
                bottomLeftRadius: Appearance.rounding.large
                bottomRightRadius: Appearance.rounding.verysmall
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
                            text: `<a href='${page.stelosRepoUrl}'>${page.stelosRepoDisplay}</a>`
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
                    RippleButtonWithIcon { materialIcon: "code"; mainText: Translation.tr("Repository"); onClicked: Qt.openUrlExternally(page.stelosRepoUrl) }
                    RippleButtonWithIcon { materialIcon: "adjust"; materialIconFill: false; mainText: Translation.tr("Issues"); onClicked: Qt.openUrlExternally(`${page.stelosRepoUrl}/issues`) }
                }
            }

            ContentSubsection {
                Layout.fillWidth: true
                Layout.fillHeight: true
                topLeftRadius: Appearance.rounding.verysmall
                topRightRadius: Appearance.rounding.verysmall
                bottomLeftRadius: Appearance.rounding.verysmall
                bottomRightRadius: Appearance.rounding.large
                title: Translation.tr("Access Level")
                icon: page.isStelosOwner ? "verified_user" : "person"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Layout.topMargin: 10
                    Layout.bottomMargin: 10
                    Rectangle {
                        implicitWidth: 50
                        implicitHeight: 50
                        radius: Appearance.rounding.large
                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0.0; color: page.isStelosOwner ? Appearance.colors.colPrimary : Appearance.colors.colSecondaryContainer }
                            GradientStop { position: 1.0; color: page.isStelosOwner ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSurfaceContainerHigh }
                        }
                        border.width: page.isStelosOwner ? 2 : 0
                        border.color: Appearance.colors.colPrimary
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: page.isStelosOwner ? "verified_user" : "person"
                            iconSize: 28
                            color: page.isStelosOwner ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        StyledText {
                            text: page.isStelosOwner ? Translation.tr("Owner") : Translation.tr("User")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Bold
                        }
                        StyledText {
                            text: page.isStelosOwner
                                ? Translation.tr("Push access detected — full repo controls unlocked")
                                : Translation.tr("Read-only — pull updates only")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                    }
                    RippleButton {
                        implicitWidth: 32
                        implicitHeight: 32
                        buttonRadius: Appearance.rounding.full
                        toggled: StelosAccessService.checking
                        onClicked: StelosAccessService.recheck()
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "refresh"
                            iconSize: 18
                        }
                    }
                }
            }
        }
    }

    ContentSection {
        icon: "swap_horiz"
        title: Translation.tr("Git Source & Update Controls")

        ContentSubsection {
            visible: !page.isStelosOwner
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
                        actionProc.command = ["bash", "-c",
                            `if [ ! -d "${page.stelosDir}/.git" ]; then bash "${page.stelosSetupScript}" "${page.stelosDir}"; fi; bash "${page.stelosPullApplyScript}" "${page.stelosDir}"`
                        ];
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
                height: 250
                visible: actionProc.logOutput !== ""
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer0
                border.color: !actionProc.finished ? Appearance.colors.colOutline :
                              (actionProc.exitCode === 0 ? Appearance.colors.colPrimary : Appearance.colors.colError)
                border.width: 1
                clip: true

                StyledFlickable {
                    anchors.fill: parent
                    anchors.margins: 8
                    clip: true
                    contentHeight: logText.implicitHeight
                    contentWidth: width
                    flickableDirection: Flickable.VerticalFlick
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    Text {
                        id: logText
                        width: parent.width
                        text: actionProc.logOutput
                        font.family: "monospace"
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer1
                        wrapMode: Text.WrapAnywhere
                        textFormat: Text.PlainText
                    }
                }
            }
        }

        ContentSubsection {
            visible: page.isStelosOwner
            title: Translation.tr("StelOS Repo")
            icon: "call_split"
            tooltip: Translation.tr("Pull, push, or construct your StelOS fork from your live config")

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                RippleButtonWithIcon {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    buttonRadius: Appearance.rounding.large
                    materialIcon: stelosProc.running && stelosProc.mode === "pull" ? "sync" : "download"
                    mainContentComponent: StyledText {
                        text: stelosProc.running && stelosProc.mode === "pull" ? Translation.tr("Pulling...") : Translation.tr("Pull")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                    enabled: !stelosProc.running
                    onClicked: {
                        page.runStelosAction("pull", ["bash", "-c",
                            `if [ ! -d "${page.stelosDir}/.git" ]; then bash "${page.stelosSetupScript}" "${page.stelosDir}"; else cd "${page.stelosDir}" && git pull --ff-only; fi`
                        ]);
                    }
                }

                RippleButtonWithIcon {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    buttonRadius: Appearance.rounding.large
                    materialIcon: stelosProc.running && stelosProc.mode === "push" ? "sync" : "upload"
                    mainContentComponent: StyledText {
                        text: stelosProc.running && stelosProc.mode === "push" ? Translation.tr("Pushing...") : Translation.tr("Push")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                    enabled: !stelosProc.running
                    onClicked: {
                        page.runStelosAction("push", ["bash", page.stelosPushScript, page.stelosDir, "Update StelOS config"]);
                    }
                }

                RippleButtonWithIcon {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    buttonRadius: Appearance.rounding.large
                    materialIcon: stelosProc.running && stelosProc.mode === "construct" ? "sync" : "construction"
                    mainContentComponent: StyledText {
                        text: stelosProc.running && stelosProc.mode === "construct" ? Translation.tr("Constructing...") : Translation.tr("Construct")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                    enabled: !stelosProc.running
                    onClicked: {
                        page.runStelosAction("construct", ["bash", page.stelosSyncScript, page.stelosDir, "--yes"]);
                    }
                }

                RippleButtonWithIcon {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    buttonRadius: Appearance.rounding.large
                    materialIcon: stelosProc.running && stelosProc.mode === "update" ? "sync" : "system_update_alt"
                    mainContentComponent: StyledText {
                        text: stelosProc.running && stelosProc.mode === "update" ? Translation.tr("Updating...") : Translation.tr("Update")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                    enabled: !stelosProc.running
                    onClicked: {
                        page.runStelosAction("update", ["bash", page.stelosPullApplyScript, page.stelosDir]);
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 8
                height: 40
                visible: stelosProc.finished
                radius: Appearance.rounding.small
                color: ColorUtils.transparentize(stelosProc.exitCode === 0 ? Appearance.colors.colPrimary : Appearance.colors.colError, 0.85)
                border.color: stelosProc.exitCode === 0 ? Appearance.colors.colPrimary : Appearance.colors.colError
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    MaterialSymbol {
                        text: stelosProc.exitCode === 0 ? "check_circle" : "error"
                        iconSize: 20
                        color: stelosProc.exitCode === 0 ? Appearance.colors.colPrimary : Appearance.colors.colError
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: stelosProc.exitCode === 0 ? Translation.tr("Done!") : Translation.tr("Failed — check log below.")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer0
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 6
                height: 250
                visible: stelosProc.logOutput !== ""
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer0
                border.color: !stelosProc.finished ? Appearance.colors.colOutline :
                              (stelosProc.exitCode === 0 ? Appearance.colors.colPrimary : Appearance.colors.colError)
                border.width: 1
                clip: true

                StyledFlickable {
                    anchors.fill: parent
                    anchors.margins: 8
                    clip: true
                    contentHeight: stelosLogText.implicitHeight
                    contentWidth: width
                    flickableDirection: Flickable.VerticalFlick
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    Text {
                        id: stelosLogText
                        width: parent.width
                        text: stelosProc.logOutput
                        font.family: "monospace"
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer1
                        wrapMode: Text.WrapAnywhere
                        textFormat: Text.PlainText
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
