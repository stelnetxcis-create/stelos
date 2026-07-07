import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.functions
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
            text: Translation.tr("Weather Service")
            font.pixelSize: Appearance.font.pixelSize.large
            font.family: Appearance.font.family.title
            color: Appearance.colors.colOnLayer0
        }
    }
    ContentSection {
        icon: "cloud"
        title: Translation.tr("Weather Service")

        ConfigSwitch {
            buttonIcon: "assistant_navigation"
            text: Translation.tr("Enable GPS location")
            checked: Config.options.bar.weather.enableGPS
            onCheckedChanged: {
                Config.options.bar.weather.enableGPS = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "thermometer"
            text: Translation.tr("Fahrenheit unit")
            checked: Config.options.bar.weather.useUSCS
            onCheckedChanged: {
                Config.options.bar.weather.useUSCS = checked;
            }
        }

        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("City name")
            text: Config.options.bar.weather.city
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Config.options.bar.weather.city = text;
            }
        }

        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Polling interval (m)")
            value: Config.options.bar.weather.fetchInterval
            from: 5
            to: 50
            stepSize: 5
            onValueChanged: {
                Config.options.bar.weather.fetchInterval = value;
            }
        }
    }

    ContentSection {
        icon: "airwave"
        title: Translation.tr("Air Quality & Pollen")

        HelperLinkBox {
            Layout.fillWidth: true
            title: Translation.tr("Open-Meteo Air Quality API")
            text: Translation.tr("Uses the same free Open-Meteo provider as the weather forecast, no API key needed. Pollen data is only available in some regions (mainly Europe/US) and will show as unavailable elsewhere.")
            isFirst: true
            isLast: true

            RippleButtonWithIcon {
                mainText: Translation.tr("Open API Docs")
                materialIcon: "open_in_new"
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                colBackground: Appearance.colors.colLayer0
                colBackgroundHover: Appearance.colors.colLayer0Hover
                colRipple: Appearance.colors.colLayer0Active
                downAction: () => {
                    Qt.openUrlExternally("https://open-meteo.com/en/docs/air-quality-api")
                }
            }
        }

        Item { Layout.preferredHeight: 16 }

        ConfigSwitch {
            buttonIcon: "check"
            text: Translation.tr("Show air quality (AQI)")
            checked: Config.options.bar.weather.airQuality.enable
            isFirst: true
            onCheckedChanged: {
                Config.options.bar.weather.airQuality.enable = checked;
            }
        }

        ConfigSwitch {
            enabled: Config.options.bar.weather.airQuality.enable
            buttonIcon: "grass"
            text: Translation.tr("Show pollen levels (where available)")
            checked: Config.options.bar.weather.airQuality.showPollen
            isLast: true
            onCheckedChanged: {
                Config.options.bar.weather.airQuality.showPollen = checked;
            }
        }

        Item { Layout.preferredHeight: 8 }

        StyledText {
            Layout.fillWidth: true
            visible: Config.options.bar.weather.airQuality.enable && Weather.airQuality.loaded
            text: Translation.tr("Current: ") + Weather.airQuality.aqiLabel + " (AQI " + Weather.airQuality.aqi + ")" + (Weather.showPollen && Weather.airQuality.hasPollenData ? " • " + Translation.tr("Grass") + " " + Weather.airQuality.pollenGrass + " • " + Translation.tr("Tree") + " " + Weather.airQuality.pollenTree : "")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.small
        }
    }
}
