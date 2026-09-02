pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

/** Official project destinations used by Welcome cards.
 * The fork documentation URL stays empty until the project publishes it.
 */
QtObject {
    readonly property string repositoryUrl: "https://github.com/stelnetxcis-create/stelos"
    readonly property string documentationUrl: "https://github.com/stelnetxcis-create/stelos/wiki"
    readonly property string discordUrl: "https://discord.gg/GtdRBXgMwq"
    readonly property bool documentationAvailable: true
}
