# AboutConfig.qml — System Info card consolidation

`sync-tooling/reapply-rebrand.sh` fixes paths, ids, and labels in
`AboutConfig.qml` automatically, but it deliberately does **not** try to
auto-rewrite the card structure if Pedro's merge reintroduces the original
3-card layout ("Upstream Info" + "This fork info" as separate cards). That's
a structural QML change, not a text swap, and a blind find/replace risks
mangling brace nesting.

If the sync script prints:

    AboutConfig.qml: old 3-card structure detected from upstream merge.

then in `dots/.config/quickshell/ii/modules/settings/configs/AboutConfig.qml`,
find the two `ContentSubsection` blocks titled `Translation.tr("Upstream Info")`
and `Translation.tr("This fork info")` (they sit right after the
`Translation.tr("Parent-Dots Info")` block) and replace both with a single
block:

```qml
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
            source: "file://" + Quickshell.shellPath("assets/icons/ii-stelnet.png")
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
```

Also check the Fork Switcher preset model a little further down — it should
list only two entries:

```qml
model: [
    { id: "stelos", icon: "fork_right",     label: Translation.tr("StelOS") },
    { id: "end4",     icon: "deployed_code",   label: Translation.tr("end-4 (dots-hyprland)") }
]
```

If Pedro's merge re-added a third `vynx`/`upstream` entry here, delete it.

After hand-patching, re-run `reapply-rebrand.sh` once more (it's idempotent)
to catch any paths/ids in the newly-merged text, then validate:

```bash
python3 -c "
s = open('dots/.config/quickshell/ii/modules/settings/configs/AboutConfig.qml').read()
assert s.count('{') == s.count('}')
assert s.count('(') == s.count(')')
print('balanced OK')
"
```
