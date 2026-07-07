pragma ComponentBehavior: Bound
import QtQml
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services
import "../"

NestableObject {
    id: root
    property var monitors: []
    property var profiles: []
    property var autoAdaptNames: []
    property bool hyprmonInstalled: true // assume present until proven otherwise, avoids a flash of the warning on every load
    property bool edidDecodeInstalled: true // same assume-present-until-checked pattern
    // Generic, EDID-derived capability sets. Populated per connected monitor's OWN edid
    // via edid-decode — nothing here is keyed to any specific brand/model. Whatever's
    // plugged in gets probed fresh; unplug it and plug in something else, that gets
    // probed too, independently.
    property var hdrCapableNames: []
    property var wideGamutCapableNames: []
    property var edidCheckedNames: []

    Component.onCompleted: {
        Qt.callLater(() => {
            autoAdaptStateProc.running = true;
            fetchProc.running = true;
            hyprmonCheckProc.running = true;
            checkRevertAvailable();
            reloadProfiles();
        });
    }

    Process {
        id: hyprmonCheckProc
        command: ["bash", "-c", "command -v hyprmon >/dev/null 2>&1 && echo yes || echo no"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.hyprmonInstalled = text.trim() === "yes";
            }
        }
    }

    // Identity for capability tracking: prefer the EDID description (survives a different
    // monitor landing on the same port) and only fall back to the port name when no
    // description is available. Same principle StelSync's desc: matching already uses.
    function monitorIdentity(mon) {
        return mon.description ? `desc:${mon.description}` : mon.name;
    }

    // Checks each newly-seen monitor's actual EDID for an HDR Static Metadata Data Block
    // (real HDR support) and a BT2020 colorimetry entry (wide gamut support), rather than
    // assuming any display can do either. Only probes identities it hasn't already checked,
    // so swapping to a different monitor on the same port triggers a fresh probe instead of
    // reusing another display's cached result.
    function checkEdidCapabilities() {
        if (!root.monitors || root.monitors.length === 0)
            return;
        const newMons = root.monitors.filter(m => root.edidCheckedNames.indexOf(root.monitorIdentity(m)) === -1);
        if (newMons.length === 0)
            return;

        const nameList = newMons.map(m => `"${m.name.replace(/"/g, "")}"`).join(" ");
        const script = `
if ! command -v edid-decode >/dev/null 2>&1; then
    echo "EDID_DECODE_MISSING"
    exit 0
fi
echo "EDID_DECODE_OK"
result="{"
first=1
for name in ${nameList}; do
    f=$(ls /sys/class/drm/*-"$name"/edid 2>/dev/null | head -1)
    hashdr="false"
    haswide="false"
    if [ -n "$f" ]; then
        out=$(edid-decode "$f" 2>/dev/null)
        echo "$out" | grep -qi "hdr static metadata" && hashdr="true"
        echo "$out" | grep -qi "bt2020" && haswide="true"
    fi
    if [ $first -eq 0 ]; then result="$result,"; fi
    result="$result\\"$name\\":{\\"hdr\\":$hashdr,\\"wide\\":$haswide}"
    first=0
done
result="$result}"
echo "$result"
`;
        edidCheckProc.command = ["bash", "-c", script];
        edidCheckProc.running = true;
        root.edidCheckedNames = root.edidCheckedNames.concat(newMons.map(m => root.monitorIdentity(m)));
    }

    Process {
        id: edidCheckProc
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                if (lines[0] === "EDID_DECODE_MISSING") {
                    root.edidDecodeInstalled = false;
                    return;
                }
                root.edidDecodeInstalled = true;
                try {
                    const parsed = JSON.parse(lines.slice(1).join("\n") || "{}");
                    const hdrNames = root.hdrCapableNames.slice();
                    const wideNames = root.wideGamutCapableNames.slice();
                    for (const name in parsed) {
                        // Translate the port-keyed result back to this monitor's identity
                        // (description-based when available), using its current live state.
                        const mon = root.monitors.find(m => m.name === name);
                        const identity = mon ? root.monitorIdentity(mon) : name;
                        if (parsed[name].hdr && hdrNames.indexOf(identity) === -1)
                            hdrNames.push(identity);
                        if (parsed[name].wide && wideNames.indexOf(identity) === -1)
                            wideNames.push(identity);
                    }
                    root.hdrCapableNames = hdrNames;
                    root.wideGamutCapableNames = wideNames;
                } catch (e) {
                    console.log("[MonitorConfigOption] EDID capability parse error:", e);
                }
            }
        }
    }

    // True if ANY monitor currently has auto-adapt on. Used to lock profile switching,
    // since applying a profile would otherwise re-pin resolution/refresh on all outputs
    // (auto-adapt still wins in the end thanks to load order, but locking avoids confusing
    // flicker/UI state while a profile apply is in flight).
    property bool anyAutoAdapt: root.monitors && root.monitors.some(m => m.autoAdapt)

    function applyAutoAdaptFlags() {
        if (!root.monitors || root.monitors.length === 0)
            return;
        root.monitors = root.monitors.map(m => Object.assign({}, m, {
            autoAdapt: root.autoAdaptNames.indexOf(m.name) !== -1
        }));
    }

    function setAutoAdapt(index, enabled) {
        let m = root.monitors.slice();
        m[index] = Object.assign({}, m[index], {
            autoAdapt: enabled
        });
        root.monitors = m;

        const names = m.filter(mon => mon.autoAdapt).map(mon => mon.name);
        root.autoAdaptNames = names;

        // Description-based matching (desc:) survives moving a monitor to a different port,
        // which plain port names (HDMI-A-1, DP-1, ...) don't. Only safe when the description
        // is non-empty and unique among currently connected monitors — same caveat HyprMon
        // itself documents, since duplicate/blank descriptions can't be told apart.
        const descCounts = {};
        m.forEach(mon => {
            if (mon.description)
                descCounts[mon.description] = (descCounts[mon.description] || 0) + 1;
        });

        const luaLines = m.filter(mon => mon.autoAdapt).map(mon => {
            const useDesc = mon.description && descCounts[mon.description] === 1;
            const output = useDesc ? `desc:${mon.description.replace(/\s*\(.*\)\s*$/, "")}` : mon.name;
            const pos = Math.round(mon.x) + "x" + Math.round(mon.y);
            const scale = parseFloat(mon.scale || 1.0).toFixed(2);
            const cm = mon.colorManagementPreset || "srgb";
            const bitdepth = mon.bitDepth === 10 ? 10 : 8;
            const sdrBrightness = (mon.sdrBrightness !== undefined ? mon.sdrBrightness : 1.0).toFixed(2);
            const sdrSaturation = (mon.sdrSaturation !== undefined ? mon.sdrSaturation : 1.0).toFixed(2);
            const transform = mon.transform || 0;

            let fields = [
                `output = "${output}"`,
                `mode = "highrr"`,
                `position = "${pos}"`,
                `scale = ${scale}`,
                `cm = "${cm}"`,
                `bitdepth = ${bitdepth}`,
                `sdrbrightness = ${sdrBrightness}`,
                `sdrsaturation = ${sdrSaturation}`,
                // Always request VRR when auto-adapting: hyprctl exposes no "is this display
                // VRR-capable" field to check first, but asking for VRR on a display that
                // doesn't support it is a harmless no-op, not a black screen risk like a fixed
                // refresh rate is. Change to 2 instead of 1 if you'd rather it only kick in
                // for fullscreen apps/games.
                `vrr = 1`
            ];
            if (transform !== 0)
                fields.push(`transform = ${transform}`);
            if (mon.mirrorOf && mon.mirrorOf !== "none")
                fields.push(`mirror = "${mon.mirrorOf}"`);

            return `hl.monitor({ ${fields.join(", ")} })`;
        });

        const luaContent = "-- Managed by ii Settings > Monitors (StelSync).\n"
            + "-- Manual changes here are fine, but they will be regenerated whenever\n"
            + "-- StelSync is toggled from Settings.\n"
            + (luaLines.length ? luaLines.join("\n") + "\n" : "");
        const namesJson = JSON.stringify(names);

        // Back up the current autoadapt.lua + state (if they exist) before overwriting,
        // using the same ~/.config/hypr/hyprmon_backups directory and .bak.<timestamp>
        // naming HyprMon itself already uses, capped at the last 20 the same way, so
        // "Revert to last known good" has something to restore from either path.
        autoAdaptSaveProc.command = ["bash", "-c",
            "mkdir -p ~/.config/hypr/hyprmon_backups\n"
            + "ts=$(date +%s)\n"
            + "[ -f ~/.config/hypr/autoadapt.lua ] && cp ~/.config/hypr/autoadapt.lua ~/.config/hypr/hyprmon_backups/autoadapt.lua.bak.$ts\n"
            + "[ -f ~/.config/hypr/autoadapt_state.json ] && cp ~/.config/hypr/autoadapt_state.json ~/.config/hypr/hyprmon_backups/autoadapt_state.json.bak.$ts\n"
            + "ls -t ~/.config/hypr/hyprmon_backups/autoadapt.lua.bak.* 2>/dev/null | tail -n +21 | xargs rm -f 2>/dev/null || true\n"
            + "ls -t ~/.config/hypr/hyprmon_backups/autoadapt_state.json.bak.* 2>/dev/null | tail -n +21 | xargs rm -f 2>/dev/null || true\n"
            + "mkdir -p ~/.config/hypr && cat << 'EOF' > ~/.config/hypr/autoadapt.lua\n" + luaContent + "EOF\n"
            + "cat << 'EOF' > ~/.config/hypr/autoadapt_state.json\n" + namesJson + "\nEOF\n"
            + "hyprctl reload"];
        autoAdaptSaveProc.running = true;
    }

    property bool revertAvailable: false
    property string revertTimestamp: ""

    function checkRevertAvailable() {
        revertCheckProc.command = ["bash", "-c",
            "ls -t ~/.config/hypr/hyprmon_backups/*.bak.* 2>/dev/null | head -1"];
        revertCheckProc.running = true;
    }

    Process {
        id: revertCheckProc
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim();
                root.revertAvailable = line.length > 0;
                if (line.length > 0) {
                    const m = line.match(/\.bak\.(\d+)$/);
                    if (m) {
                        const d = new Date(parseInt(m[1]) * 1000);
                        root.revertTimestamp = d.toLocaleString(Qt.locale(), "MMM d, hh:mm");
                    }
                }
            }
        }
    }

    // Restores the most recent backed-up hyprmon.lua AND autoadapt.lua (+ its state file)
    // together as one unit, since a single "revert" should put the whole monitor config
    // back to a consistent prior state rather than mixing an old hyprmon.lua with a
    // newer autoadapt.lua that assumes different things about it.
    function revertToLastGood() {
        const script = `
BACKUP_DIR=~/.config/hypr/hyprmon_backups
restore_latest() {
    local pattern="$1"
    local dest="$2"
    local latest
    latest=$(ls -t "$BACKUP_DIR"/$pattern 2>/dev/null | head -1)
    if [ -n "$latest" ]; then
        cp "$latest" "$dest"
        echo "restored: $latest -> $dest"
    fi
}
restore_latest "hyprmon.lua.bak.*" ~/.config/hypr/hyprmon.lua
restore_latest "autoadapt.lua.bak.*" ~/.config/hypr/autoadapt.lua
restore_latest "autoadapt_state.json.bak.*" ~/.config/hypr/autoadapt_state.json
hyprctl reload
`;
        revertProc.command = ["bash", "-c", script];
        revertProc.running = true;
    }

    Process {
        id: revertProc
        stdout: StdioCollector {
            onStreamFinished: {
                Quickshell.execDetached(["notify-send", "StelSync", Translation.tr("Reverted to last known good monitor config.")]);
                autoAdaptStateProc.running = true;
                monitorEventFetchDelay.restart();
            }
        }
    }

    Process {
        id: autoAdaptSaveProc
        onRunningChanged: if (!running) {
            // hyprctl reload needs a moment to actually renegotiate the mode
            // before hyprctl monitors reflects the new refresh rate
            autoAdaptFetchDelay.restart();
        }
    }

    Timer {
        id: autoAdaptFetchDelay
        interval: 600
        repeat: false
        onTriggered: {
            fetchProc.running = true;
        }
    }

    Process {
        id: autoAdaptStateProc
        command: ["bash", "-c", "cat ~/.config/hypr/autoadapt_state.json 2>/dev/null || echo '[]'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.autoAdaptNames = JSON.parse(text.trim() || "[]");
                } catch (e) {
                    root.autoAdaptNames = [];
                }
                root.applyAutoAdaptFlags();
            }
        }
    }

    function reloadProfiles() {
        profilesProc.running = true;
    }

    function updateMonitor(index, changes) {
        let m = root.monitors.slice();
        m[index] = Object.assign({}, m[index], changes);
        root.monitors = m;
    }

    Timer {
        id: debounceSaveTimer
        interval: 150
        repeat: false
        onTriggered: {
            root.doSave();
        }
    }

    function save() {
        debounceSaveTimer.restart();
    }

    function doSave() {
        if (saveProc.running) {
            // If the process is still running, try again shortly
            debounceSaveTimer.start();
            return;
        }

        if (root.monitors.length === 0)
            return;
        if (root.monitors.some(m => !m.name))
            return;

        const profile = {
            name: "__quickshell_live__",
            monitors: root.monitors.map(m => {
                return {
                    name: m.name,
                    make: "",
                    model: m.description,
                    PxW: m.width,
                    PxH: m.height,
                    Hz: m.refreshRate,
                    Scale: m.scale,
                    X: m.x,
                    Y: m.y,
                    Active: !m.disabled,
                    BitDepth: m.bitDepth || 8,
                    ColorMode: m.colorManagementPreset || "srgb",
                    SDRBrightness: m.sdrBrightness || 1.0,
                    SDRSaturation: m.sdrSaturation || 1.0,
                    VRR: m.vrr || 0,
                    Transform: m.transform || 0,
                    IsMirrored: m.mirrorOf && m.mirrorOf !== "none",
                    MirrorSource: m.mirrorOf && m.mirrorOf !== "none" ? m.mirrorOf : ""
                };
            }),
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString()
        };
        const jsonStr = JSON.stringify(profile, null, 2);

        saveProc.command = ["bash", "-c", "mkdir -p ~/.config/hyprmon/profiles && cat << 'EOF' > ~/.config/hyprmon/profiles/__quickshell_live__.json\n" + jsonStr + "\nEOF\nhyprmon -profile __quickshell_live__ && mkdir -p ~/.config/hypr/hyprmon_backups && mv ~/.config/hypr/*.bak.* ~/.config/hypr/hyprmon_backups/ 2>/dev/null || true; ls -t ~/.config/hypr/hyprmon_backups/*.bak.* 2>/dev/null | tail -n +21 | xargs rm -f 2>/dev/null || true"];
        saveProc.running = true;
    }

    function applyMonitor(m) {
        root.save();
    }

    function applyAndSave(index) {
        root.save();
    }

    function logicalWidth(m) {
        return (m.transform === 1 || m.transform === 3) ? m.height : m.width;
    }

    function logicalHeight(m) {
        return (m.transform === 1 || m.transform === 3) ? m.width : m.height;
    }

    function applyProfile(name) {
        applyProfileProc.command = ["bash", "-c", "hyprmon -profile \"$1\" && mkdir -p ~/.config/hypr/hyprmon_backups && mv ~/.config/hypr/*.bak.* ~/.config/hypr/hyprmon_backups/ 2>/dev/null || true; ls -t ~/.config/hypr/hyprmon_backups/*.bak.* 2>/dev/null | tail -n +21 | xargs rm -f 2>/dev/null || true", "--", name];
        applyProfileProc.running = true;
    }

    function deleteProfile(name) {
        deleteProfileProc.command = ["bash", "-c", "rm -f ~/.config/hyprmon/profiles/\"$1\".json", "--", name];
        deleteProfileProc.running = true;
    }

    function saveProfile(name) {
        if (!name)
            return;
        const profile = {
            name: name,
            monitors: root.monitors.map(m => {
                return {
                    name: m.name,
                    make: "",
                    model: m.description,
                    PxW: m.width,
                    PxH: m.height,
                    Hz: m.refreshRate,
                    Scale: m.scale,
                    X: m.x,
                    Y: m.y,
                    Active: !m.disabled,
                    BitDepth: m.bitDepth || 8,
                    ColorMode: m.colorManagementPreset || "srgb",
                    SDRBrightness: m.sdrBrightness || 1.0,
                    SDRSaturation: m.sdrSaturation || 1.0,
                    VRR: m.vrr || 0,
                    Transform: m.transform || 0,
                    IsMirrored: m.mirrorOf && m.mirrorOf !== "none",
                    MirrorSource: m.mirrorOf && m.mirrorOf !== "none" ? m.mirrorOf : ""
                };
            }),
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString()
        };
        const jsonStr = JSON.stringify(profile, null, 2);
        saveProfileProc.command = ["bash", "-c", "mkdir -p ~/.config/hyprmon/profiles && cat << 'EOF' > ~/.config/hyprmon/profiles/\"$1\".json\n$2\nEOF", "--", name, jsonStr];
        saveProfileProc.running = true;
    }

    // Instant reaction to monitor connect/disconnect, instead of waiting up to 3s for the
    // background poll. Hyprland already applies matching monitor rules (including our
    // autoadapt.lua ones) to a newly connected output on its own — this listener exists
    // purely so the Settings panel and the OSD notification below aren't stale/late.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            switch (event.name) {
            case "monitoradded":
            case "monitoraddedv2":
            case "monitorremoved":
            case "monitorremovedv2":
                monitorEventFetchDelay.restart();
                break;
            }
        }
    }

    Timer {
        id: monitorEventFetchDelay
        interval: 400
        repeat: false
        onTriggered: {
            fetchProc.running = true;
            osdFetchProc.running = true;
        }
    }

    // Separate one-shot fetch just for the "which display / what rate" OSD notification,
    // so it always announces the freshest state right after a monitor change, independent
    // of whatever the main fetchProc/UI timing is doing.
    Process {
        id: osdFetchProc
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const mons = JSON.parse(text);
                    mons.filter(mon => !mon.disabled && root.autoAdaptNames.indexOf(mon.name) !== -1)
                        .forEach(mon => {
                            const label = (mon.description || mon.name).replace(/\s*\(.*\)\s*$/, "");
                            Quickshell.execDetached(["notify-send", "-t", "3000", "StelSync",
                                `${label}: ${mon.width}x${mon.height} @ ${mon.refreshRate.toFixed(0)}Hz, VRR on`]);
                        });
                } catch (e) {
                    console.log("[MonitorConfigOption] OSD fetch error:", e);
                }
            }
        }
    }

    Process {
        id: fetchProc
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.monitors = JSON.parse(text).map(m => ({
                                name: m.name,
                                description: m.description,
                                width: m.width,
                                height: m.height,
                                refreshRate: m.refreshRate,
                                x: m.x,
                                y: m.y,
                                scale: m.scale,
                                transform: (m.transform !== undefined && m.transform !== null) ? m.transform : 0,
                                disabled: m.disabled,
                                availableModes: m.availableModes,
                                currentMode: `${m.width}x${m.height}@${m.refreshRate.toFixed(2)}Hz`,
                                mirrorOf: m.mirrorOf || "none",
                                bitDepth: (m.currentFormat && m.currentFormat.indexOf("2101010") !== -1) ? 10 : 8,
                                colorManagementPreset: m.colorManagementPreset || "srgb",
                                sdrBrightness: m.sdrBrightness !== undefined ? m.sdrBrightness : 1.0,
                                sdrSaturation: m.sdrSaturation !== undefined ? m.sdrSaturation : 1.0,
                                vrr: m.vrr ? 1 : 0,
                                autoAdapt: root.autoAdaptNames.indexOf(m.name) !== -1
                            }));
                    root.checkEdidCapabilities();
                } catch (e) {
                    console.log("[MonitorConfigOption] Error:", e);
                }
            }
        }
    }

    // Keeps the panel honest: refresh rate / mode can change from outside the UI's own
    // actions (auto-adapt renegotiating on its own, a monitor reconnecting, etc), so poll
    // periodically rather than only refetching after actions we triggered ourselves.
    // Only runs while nothing else is mid-write, so it never fights an in-flight save.
    Timer {
        id: livePollTimer
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            if (!fetchProc.running && !saveProc.running && !autoAdaptSaveProc.running
                && !applyProfileProc.running && !saveToHyprlandProc.running) {
                fetchProc.running = true;
            }
        }
    }

    Process {
        id: applyProc
    }
    Process {
        id: saveProc
        onRunningChanged: if (!running) {
            delayFetchTimer.restart();
            checkRevertAvailable();
        }
    }
    Process {
        id: reloadProc
        command: ["hyprctl", "reload"]
    }

    Process {
        id: profilesProc
        command: ["hyprmon", "-list-profiles"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let lines = text.trim().split("\n").filter(l => l.length > 0);
                    let plist = lines.map(line => {
                        let isA = line.endsWith(" *");
                        let name = isA ? line.substring(0, line.length - 2) : line;
                        return {
                            name: name,
                            isActive: isA
                        };
                    }).filter(p => p.name !== "__quickshell_live__");
                    root.profiles = plist;
                } catch (e) {
                    console.log("[MonitorConfigOption] Error profiles:", e);
                }
            }
        }
    }

    Timer {
        id: delayFetchTimer
        interval: 200
        repeat: false
        onTriggered: {
            fetchProc.running = true;
            reloadProfiles();
        }
    }

    Process {
        id: applyProfileProc
        onRunningChanged: if (!running) {
            delayFetchTimer.restart();
            checkRevertAvailable();
        }
    }

    Process {
        id: deleteProfileProc
        onRunningChanged: if (!running) {
            reloadProfiles();
        }
    }

    function reloadFromHyprland() {
        Quickshell.execDetached(["hyprctl", "reload"]);
        // delay fetching so hyprctl reload has time to apply
        delayFetchTimer.restart();
    }

    function saveToHyprland() {
        let content = "# Generated by Quickshell/II MonitorsConfig\n";
        for (let i = 0; i < root.monitors.length; i++) {
            let m = root.monitors[i];
            if (!m) continue;
            if (m.disabled) {
                content += "monitor=" + m.name + ",disable\n";
            } else {
                let res = m.width + "x" + m.height + "@" + parseFloat(m.refreshRate).toFixed(2);
                let pos = Math.round(m.x) + "x" + Math.round(m.y);
                let scale = parseFloat(m.scale).toFixed(2);
                if (scale.endsWith(".00")) scale = parseInt(scale).toString();
                let params = [m.name, res, pos, scale];
                let line = "monitor=" + params.join(",");
                
                if (m.mirrorOf && m.mirrorOf !== "none") {
                    line += ",mirror," + m.mirrorOf;
                }
                if (m.bitDepth === 10) {
                    line += ",bitdepth,10";
                }
                if (m.transform !== undefined && m.transform !== 0) {
                    line += ",transform," + m.transform;
                }
                content += line + "\n";
            }
        }
        
        saveToHyprlandProc.command = ["bash", "-c", "cat << 'EOF' > ~/.config/hypr/monitors.conf\n" + content + "EOF\nnotify-send 'Monitors' 'Saved permanently to Hyprland!' -t 3000"];
        saveToHyprlandProc.running = true;
    }

    Process {
        id: saveToHyprlandProc
    }

    Process {
        id: saveProfileProc
        onRunningChanged: if (!running) {
            reloadProfiles();
        }
    }
}
