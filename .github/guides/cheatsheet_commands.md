# 📜 Cheatsheet Commands Library Setup & Implementation

This guide documents the implementation of the Cheatsheet Command Manager. This feature allows users to catalog, search, and manage a personal terminal command library directly inside the desktop cheatsheet panel, with support for tag categorization and JSON import/export.

---

## 📂 File Structure
* **UI Modules**:
  * `modules/ii/cheatsheet/commands/CheatsheetCommands.qml` (Core commands tab view)
  * `modules/ii/cheatsheet/commands/CommandCard.qml` (Individual command delegate card)
  * `modules/ii/cheatsheet/commands/CommandForm.qml` (Inline dialog to add/edit commands)
* **Backend Services**:
  * `services/CommandsService.qml` (QML singleton resolving dynamic JSON serialization, local file persistence, and query filtering)

---

## 🔧 Core Integration Setup

### Step 1: Configuration Schemas (`modules/common/Config.qml`)
Register global toggles inside the cheatsheet options object to support showing/hiding commands and enabling the tag filter sidebar:

```qml
// inside options.cheatsheet block
property bool enableCommands: true
property bool commandsTagsSidebar: false
```

---

### Step 2: Settings Controls (`modules/settings/InterfaceConfig.qml`)
Expose customization switches inside the desktop settings menu:

```qml
ConfigSwitch {
    buttonIcon: "terminal"
    text: Translation.tr("Enable Commands")
    checked: Config.options.cheatsheet.enableCommands
    onCheckedChanged: { Config.options.cheatsheet.enableCommands = checked; }
}
```

---

### Step 3: Module Registration
* **Service Singleton**: Add `CommandsService.qml` inside `services/` and register it inside your main shell environment to manage commands persistence.
* **Cheatsheet Tab**: Hook the commands list loader into `Cheatsheet.qml` so that the commands tab only renders when configured:
  ```qml
  if (Config.options.cheatsheet.enableCommands) {
      list.push({ "icon": "terminal", "name": Translation.tr("Commands") });
  }
  ```
