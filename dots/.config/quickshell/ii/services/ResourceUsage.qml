pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

// Polled resource usage service: RAM, Swap, CPU, Disk, GPU.
// - proc/stat, /proc/meminfo and CPU temperature read via FileView
//   in a single Timer tick - no bash forks.
// - Disk usage is sampled every `diskInterval` ms through a one-shot
//   Process (`df`) driven by a QML Timer.
// - GPU monitoring auto-detects vendor on boot:
//   - NVIDIA = one-shot nvidia-smi triggered by a QML Timer.
//   - AMD    = sysfs gpu_busy_percent and hwmon temp1_input via
//              FileView (zero-cost, no fork).
//   - Intel  = hwmon/thermal_zone fallback via one-shot bash by the
//              same GPU Timer (temperature only, no usage metric).
Singleton {
    id: root
	property real memoryTotal: 1
	property real memoryFree: 0
	property real memoryUsed: memoryTotal - memoryFree
    property real memoryUsedPercentage: memoryUsed / memoryTotal
    property real diskTotal: 1
    property real diskFree: 0
    property real diskUsed: 0
    property real diskUsedPercentage: diskTotal > 0 ? (diskUsed / diskTotal) : 0
    property real swapTotal: 1
	property real swapFree: 0
	property real swapUsed: swapTotal - swapFree
    property real swapUsedPercentage: swapTotal > 0 ? (swapUsed / swapTotal) : 0
    property real cpuUsage: 0
    property var previousCpuStats
    property real cpuTemp: 0
    property real cpuFreqMhz: 0
    property real gpuUsage: 0
    property real gpuPowerW: 0
    property real gpuTemp: 0

    property string cpuModel: "--"
    property string gpuModel: "--"

    property string maxAvailableMemoryString: kbToGbString(ResourceUsage.memoryTotal)
    property string maxAvailableSwapString: kbToGbString(ResourceUsage.swapTotal)
    property string maxAvailableCpuString: "--"

    readonly property int historyLength: Config?.options.resources.historyLength ?? 60
    property list<real> cpuUsageHistory: []
    property list<real> memoryUsageHistory: []
    property list<real> swapUsageHistory: []

    function kbToGbString(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    function updateMemoryUsageHistory() {
        memoryUsageHistory = [...memoryUsageHistory, memoryUsedPercentage]
        if (memoryUsageHistory.length > historyLength) {
            memoryUsageHistory.shift()
        }
    }
    function updateSwapUsageHistory() {
        swapUsageHistory = [...swapUsageHistory, swapUsedPercentage]
        if (swapUsageHistory.length > historyLength) {
            swapUsageHistory.shift()
        }
    }
    function updateCpuUsageHistory() {
        cpuUsageHistory = [...cpuUsageHistory, cpuUsage]
        if (cpuUsageHistory.length > historyLength) {
            cpuUsageHistory.shift()
        }
    }
    function updateHistories() {
        updateMemoryUsageHistory()
        updateSwapUsageHistory()
        updateCpuUsageHistory()
    }

	property bool gpuMonitoringEnabled: false
	onGpuMonitoringEnabledChanged: {
		if (!gpuMonitoringEnabled) {
			gpuUsage = 0
			gpuTemp = 0
		}
	}

    // ── GPU vendor detection ────────────────────────────────────────
    // Detected once on boot. Drives which subsystem we poll for stats.
    //   "nvidia" → nvidia-smi one-shot (Timer-driven)
    //   "amd"    → sysfs FileView (zero-cost, no fork)
    //   "intel"  → thermal_zone fallback (temperature only)
    //   "unknown" → no monitoring
    property string gpuVendor: "unknown"

    // AMD sysfs paths (resolved once after vendor detection)
    property string amdUsagePath: ""      // /sys/class/drm/card*/device/gpu_busy_percent
    property string amdTempPath: ""       // /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input

    FileView { id: amdUsageFileView }
    FileView { id: amdTempFileView }

    FileView { id: cpuTempFileView }
	property string cpuTempPath: ""

    Process {
        id: locateCpuTempPathProc
        command: ["bash", "-c", "for hw in /sys/class/hwmon/hwmon*; do if [ -f \"$hw/name\" ]; then name=$(cat \"$hw/name\" 2>/dev/null); if [ \"$name\" = \"k10temp\" ] || [ \"$name\" = \"zenpower\" ] || [ \"$name\" = \"coretemp\" ]; then for t_input in \"$hw\"/temp*_input; do if [ -f \"$t_input\" ]; then echo \"$t_input\"; exit 0; fi; done; fi; fi; done; for tz in /sys/class/thermal/thermal_zone*; do if [ -f \"$tz/type\" ] && [ -f \"$tz/temp\" ]; then type=$(cat \"$tz/type\" 2>/dev/null); if [ \"$type\" = \"x86_pkg_temp\" ] || [ \"$type\" = \"cpu-thermal\" ] || [ \"$type\" = \"cpu_thermal\" ] || [ \"$type\" = \"TCPU\" ] || [ \"$type\" = \"cpu\" ] || [ \"$type\" = \"acpitz\" ]; then echo \"$tz/temp\"; exit 0; fi; fi; done"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.cpuTempPath = text.trim()
                if (root.cpuTempPath) {
                    cpuTempFileView.path = root.cpuTempPath
                }
            }
        }
    }

    // ── CPU/RAM polling Timer (drives FileView reloads) ─────────────
    // No more `while true; do` bash loops. One QML Timer per subsystem,
    // reuses FileView instances that just reload files in-place.
	Timer {
        id: cpuRamTimer
		interval: 1
		running: true
		repeat: true
		onTriggered: {
			// Reload files
			fileMeminfo.reload()
			fileStat.reload()
			if (root.cpuTempPath) {
				cpuTempFileView.reload()
				const rawTemp = Number(cpuTempFileView.text().trim() || 0)
				root.cpuTemp = rawTemp > 1000 ? rawTemp / 1000 : rawTemp
			}

			// Parse memory and swap usage
			const textMeminfo = fileMeminfo.text()
			memoryTotal = Number(textMeminfo.match(/MemTotal: *(\d+)/)?.[1] ?? 1)
			memoryFree = Number(textMeminfo.match(/MemAvailable: *(\d+)/)?.[1] ?? 0)
			swapTotal = Number(textMeminfo.match(/SwapTotal: *(\d+)/)?.[1] ?? 1)
			swapFree = Number(textMeminfo.match(/SwapFree: *(\d+)/)?.[1] ?? 0)

			// Parse CPU usage
			const textStat = fileStat.text()
			const cpuLine = textStat.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)
			if (cpuLine) {
				const stats = cpuLine.slice(1).map(Number)
				const total = stats.reduce((a, b) => a + b, 0)
				const idle = stats[3]

				if (previousCpuStats) {
					const totalDiff = total - previousCpuStats.total
					const idleDiff = idle - previousCpuStats.idle
					cpuUsage = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0
				}

				previousCpuStats = { total, idle }
			}

			// AMD GPU stats via sysfs (zero-cost, no fork)
			if (root.gpuVendor === "amd" && root.gpuMonitoringEnabled) {
				if (root.amdUsagePath) {
					amdUsageFileView.reload()
					const usage = Number(amdUsageFileView.text().trim() || 0)
					root.gpuUsage = usage / 100
				}
				if (root.amdTempPath) {
					amdTempFileView.reload()
					const rawTemp = Number(amdTempFileView.text().trim() || 0)
					root.gpuTemp = rawTemp > 1000 ? rawTemp / 1000 : rawTemp
				}
			}

			root.updateHistories()
			interval = Config.options?.resources?.updateInterval ?? 3000
		}
	}

	FileView { id: fileMeminfo; path: "/proc/meminfo" }
	FileView { id: fileStat; path: "/proc/stat" }

    Process {
        id: findCpuMaxFreqProc
        command: ["bash", "-c", "LANG=C LC_ALL=C lscpu | grep 'CPU max MHz' | awk '{print $4}'"]
        running: true
        stdout: StdioCollector {
            id: outputCollector
            onStreamFinished: {
                root.maxAvailableCpuString = (parseFloat(outputCollector.text) / 1000).toFixed(0) + " GHz"
            }
        }
    }

    Process {
        id: cpuModelProc
        command: ["bash", "-c", "LANG=C LC_ALL=C grep -m1 'model name' /proc/cpuinfo | sed 's/model name\\s*:\\s*//'"]
        running: true
        stdout: StdioCollector {
            id: cpuModelCollector
            onStreamFinished: {
                const model = cpuModelCollector.text.trim()
                if (model.length > 0) root.cpuModel = model
            }
        }
    }

    // GPU model + vendor detection in one shot. Previously nvidia-smi was
    // called on every model fetch AND in an infinite loop. Now we run
    // nvidia-smi exactly once on boot; if present, vendor="nvidia".
    // Otherwise the path probe inside discovers AMD/Intel via sysfs/lspci.
    Process {
        id: gpuModelProc
        command: ["bash", "-c",
            "if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then " +
            "  echo 'NVIDIA|'$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null); " +
            "elif [ -d /sys/class/drm ] && ls /sys/class/drm/card*/device/gpu_busy_percent >/dev/null 2>&1; then " +
            "  for card in /sys/class/drm/card*/device; do " +
            "    if [ -f \"$card/gpu_busy_percent\" ]; then " +
            "      model=$(cat \"$card/device\" 2>/dev/null || basename $(dirname \"$card\")); " +
            "      echo \"AMD|$model\"; exit 0; " +
            "    fi; " +
            "  done; " +
            "  echo 'AMD|AMD GPU'; " +
            "else " +
            "  model=$(lspci 2>/dev/null | grep -i -m1 'vga\\|3d\\|display' | sed 's/.*: //'); " +
            "  if echo \"$model\" | grep -qi 'intel'; then " +
            "    echo \"INTEL|$model\"; " +
            "  else " +
            "    echo \"UNKNOWN|$model\"; " +
            "  fi; " +
            "fi"
        ]
        running: true
        stdout: StdioCollector {
            id: gpuModelCollector
            onStreamFinished: {
                const line = gpuModelCollector.text.trim()
                if (line.length === 0) {
                    root.gpuVendor = "unknown"
                    return
                }
                const parts = line.split("|")
                const vendor = parts[0].toLowerCase()
                const model = parts[1] || ""
                root.gpuVendor = vendor === "nvidia" ? "nvidia"
                              : vendor === "amd" ? "amd"
                              : vendor === "intel" ? "intel"
                              : "unknown"
                if (model.length > 0) root.gpuModel = model

                if (root.gpuVendor === "amd") {
                    // Resolve AMD sysfs paths once for cheap FileView polling
                    amdPathResolveProc.running = true
                }
            }
        }
    }

    // One-shot bash to resolve AMD hwmon paths (can't be done from QML).
    Process {
        id: amdPathResolveProc
        command: ["bash", "-c",
            "for card in /sys/class/drm/card*/device; do " +
            "  if [ -f \"$card/gpu_busy_percent\" ]; then " +
            "    echo \"USAGE=$card/gpu_busy_percent\"; " +
            "    for hwmon in \"$card\"/hwmon/hwmon*/temp1_input; do " +
            "      if [ -f \"$hwmon\" ]; then " +
            "        echo \"TEMP=$hwmon\"; break; " +
            "      fi; " +
            "    done; " +
            "    exit 0; " +
            "  fi; " +
            "done"
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                lines.forEach(line => {
                    if (line.startsWith("USAGE=")) {
                        root.amdUsagePath = line.slice(7)
                        amdUsageFileView.path = root.amdUsagePath
                    } else if (line.startsWith("TEMP=")) {
                        root.amdTempPath = line.slice(5)
                        amdTempFileView.path = root.amdTempPath
                    }
                })
            }
        }
    }

    // ── Disk space polling — no more `while true; do df; sleep 5; done` ─
    // One-shot `df` invocation driven by a QML Timer. Each tick forks a
    // short-lived bash that dies immediately after parsing stdout (no
    // zombie sleep loop waiting on a SIGTERM that never comes).
    Process {
        id: diskSpaceProc
        command: ["bash", "-c", "LANG=C LC_ALL=C df -B1 / | awk 'NR==2{print $2, $3, $4}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/)
                if (parts.length >= 3) {
                    root.diskTotal = Number(parts[0])
                    root.diskUsed = Number(parts[1])
                    root.diskFree = Number(parts[2])
                }
            }
        }
    }

    Timer {
        id: diskSpaceTimer
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            diskSpaceProc.running = false
            diskSpaceProc.running = true
            interval = Config.options?.resources?.diskInterval ?? 5000
        }
    }

    // ── NVIDIA/Intel GPU polling — one-shot nvidia-smi per tick ───────
    // Previous incarnation: an infinite `while true; do nvidia-smi; sleep 3`
    // bash loop. Each loop tick blocked a slot in the bash memory budget
    // (~30ms exec + 5MB temp). Now: a QML Timer spawns a one-shot Process
    // every `gpuInterval` ms when monitoring is enabled. When disabled,
    // neither the Timer nor any fork runs.
    Process {
        id: gpuMonitorProc
        command: ["bash", "-c",
            "if [ \"$GPUVENDOR\" = \"nvidia\" ] && command -v nvidia-smi >/dev/null 2>&1; then " +
            "  nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null; " +
            "elif [ \"$GPUVENDOR\" = \"intel\" ]; then " +
            "  temp=0; " +
            "  for hw in /sys/class/hwmon/hwmon*; do " +
            "    if [ -f \"$hw/name\" ]; then " +
            "      name=$(cat \"$hw/name\" 2>/dev/null); " +
            "      if [ \"$name\" = \"coretemp\" ] || [ \"$name\" = \"intel-pch\" ]; then " +
            "        for t in \"$hw\"/temp1_input; do " +
            "          if [ -f \"$t\" ]; then x=$(cat \"$t\" 2>/dev/null || echo 0); temp=$((x/1000)); echo \"0, $temp\"; exit 0; fi; " +
            "        done; " +
            "      fi; " +
            "    fi; " +
            "  done; " +
            "  for tz in /sys/class/thermal/thermal_zone*; do " +
            "    type=$(cat \"$tz/type\" 2>/dev/null); " +
            "    if [ \"$type\" = \"x86_pkg_temp\" ] || [ \"$type\" = \"cpu_thermal\" ]; then " +
            "      x=$(cat \"$tz/temp\" 2>/dev/null || echo 0); temp=$((x/1000)); echo \"0, $temp\"; exit 0; " +
            "    fi; " +
            "  done; " +
            "  echo \"0, 0\"; " +
            "else " +
            "  echo \"0, 0\"; " +
            "fi"
        ]
        environment: ({
            GPUVENDOR: root.gpuVendor
        })
        running: false
        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split(/[\s,]+/)
                if (parts.length >= 2) {
                    root.gpuUsage = Number(parts[0]) / 100
                    root.gpuTemp = Number(parts[1])
                }
            }
        }
        onExited: {
            // One-shot, nothing to do. The Timer will respawn us next tick.
        }
    }

    Timer {
        id: gpuMonitorTimer
        interval: 2000
        repeat: true
        running: root.gpuMonitoringEnabled && (root.gpuVendor === "nvidia" || root.gpuVendor === "intel")
        onTriggered: {
            if (!root.gpuMonitoringEnabled) return
            if (root.gpuVendor !== "nvidia" && root.gpuVendor !== "intel") return
            gpuMonitorProc.running = false
            gpuMonitorProc.running = true
            interval = Config.options?.resources?.gpuInterval ?? 3000
        }
    }
}
