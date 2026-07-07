import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: root
    forceWidth: false

    signal goBack()

    RowLayout {
        spacing: 12

        RippleButton {
            implicitWidth: implicitHeight
            implicitHeight: 40
            topLeftRadius: Appearance.rounding.full
            topRightRadius: Appearance.rounding.full
            bottomLeftRadius: Appearance.rounding.full
            bottomRightRadius: Appearance.rounding.full
            colBackground: Appearance.colors.colSecondaryContainer
            colBackgroundHover: Appearance.colors.colSecondaryContainerHover
            colRipple: Appearance.colors.colSecondaryContainerActive

            MaterialSymbol {
                anchors.centerIn: parent
                text: "arrow_back"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnSecondaryContainer
            }

            onClicked: root.goBack()
        }

        StyledText {
            text: Translation.tr("Resources Tracker")
            font.pixelSize: Appearance.font.pixelSize.large
            font.family: Appearance.font.family.title
            color: Appearance.colors.colOnLayer0
        }
    }

    ContentSection {
        icon: "memory"
        title: Translation.tr("Resources Tracker")

        ConfigSwitch {
            buttonIcon: "percent"
            text: Translation.tr("Show percentage text")
            checked: Config.options.bar.resources.showPercentageText
            onCheckedChanged: {
                Config.options.bar.resources.showPercentageText = checked;
            }
        }
        ConfigSwitch {
            buttonIcon: "memory"
            text: Translation.tr("Always show RAM")
            checked: Config.options.bar.resources.alwaysShowRam
            onCheckedChanged: Config.options.bar.resources.alwaysShowRam = checked
        }
        ConfigSwitch {
            buttonIcon: "planner_review"
            text: Translation.tr("Always show CPU")
            checked: Config.options.bar.resources.alwaysShowCpu
            onCheckedChanged: Config.options.bar.resources.alwaysShowCpu = checked
        }
        ConfigSwitch {
            buttonIcon: "thermostat"
            text: Translation.tr("Always show Temp")
            checked: Config.options.bar.resources.alwaysShowCpuTemp
            onCheckedChanged: Config.options.bar.resources.alwaysShowCpuTemp = checked
        }
        ConfigSwitch {
            buttonIcon: "hard_drive"
            text: Translation.tr("Always show Disk")
            checked: Config.options.bar.resources.alwaysShowDisk
            onCheckedChanged: Config.options.bar.resources.alwaysShowDisk = checked
            StyledToolTip {
                text: Translation.tr("The bar icon always mirrors just the first mount below. Open the resources card (click it) to see every mount listed under Disk Mounts.")
            }
        }
        ConfigSwitch {
            buttonIcon: "swap_horiz"
            text: Translation.tr("Always show Swap")
            checked: Config.options.bar.resources.alwaysShowSwap
            onCheckedChanged: Config.options.bar.resources.alwaysShowSwap = checked
        }
        ConfigSwitch {
            buttonIcon: "dns"
            text: Translation.tr("Always show Docker")
            checked: Config.options.bar.resources.showDocker
            onCheckedChanged: Config.options.bar.resources.showDocker = checked
        }
    }

    ContentSection {
        icon: "hard_drive"
        title: Translation.tr("Disk Mounts")

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Every path here gets its own usage row in the resources card. The bar's compact icon only ever reflects the first entry.")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.small
            wrapMode: Text.WordWrap
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 4

            Repeater {
                model: Config.options.resources.diskMounts || []

                delegate: RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MaterialTextField {
                        Layout.fillWidth: true
                        text: modelData
                        placeholderText: Translation.tr("/path/to/mount")
                        onEditingFinished: {
                            let mounts = Array.from(Config.options.resources.diskMounts);
                            mounts[index] = text.trim();
                            Config.options.resources.diskMounts = mounts;
                        }
                    }

                    RippleButton {
                        implicitWidth: 40
                        implicitHeight: 40
                        buttonRadius: Appearance.rounding.normal
                        colBackground: Appearance.colors.colSecondaryContainer
                        colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                        colRipple: Appearance.colors.colSecondaryContainerActive
                        enabled: Config.options.resources.diskMounts.length > 1
                        opacity: enabled ? 1.0 : 0.4

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "delete"
                            iconSize: Appearance.font.pixelSize.large
                            color: Appearance.colors.colOnSecondaryContainer
                        }

                        onClicked: {
                            let mounts = Array.from(Config.options.resources.diskMounts);
                            mounts.splice(index, 1);
                            Config.options.resources.diskMounts = mounts;
                        }
                    }
                }
            }

            RippleButtonWithIcon {
                Layout.fillWidth: true
                Layout.topMargin: 4
                mainText: Translation.tr("Add mount path")
                materialIcon: "add"
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colRipple: Appearance.colors.colLayer2Active
                downAction: () => {
                    let mounts = Array.from(Config.options.resources.diskMounts || []);
                    mounts.push("/mnt");
                    Config.options.resources.diskMounts = mounts;
                }
            }
        }
    }

    ContentSection {
        icon: "inventory_2"
        title: Translation.tr("Docker Backend")

        ConfigSwitch {
            buttonIcon: "power_settings_new"
            text: Translation.tr("Enable Docker monitoring")
            checked: Config.options.resources.enableDocker
            onCheckedChanged: {
                Config.options.resources.enableDocker = checked
            }
        }
    }
}
