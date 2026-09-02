# 📱 Paged Android Quick Toggles Implementation

This guide documents the implementation of the horizontally-swipeable, multi-paged Android Style Quick Toggles panel located in the Quickshell Sidebar Dashboard.

---

## ✨ Features & Architecture

* **Horizontal Paging**: Provides smooth flicking, snapping, and layout calculations across multiple quick toggle pages.
* **Intelligent Responsive Height**: Automatically calculates and shrinks/expands the quick toggle panel wrapper height depending on the current active page's item count, leaving maximum vertical real estate for notifications and system information widgets.
* **Premium Edit Mode**: A custom modal view allowing you to drag-and-drop, delete, add new toggle pages, or reorder toggles with full active micro-animations.
* **Dynamic Sidebar Layout Sync**: Interacts with the dashboard sidebar's bottom panels to dynamically contract, squeeze, or shift widget structures when edit mode is toggled.

---

## 📂 File Layout
* `modules/ii/sidebarDashboard/quickToggles/AndroidQuickPanel.qml` (Core paged quick toggle parent panel)
* `modules/ii/sidebarDashboard/quickToggles/androidStyle/` (Specific item builders, pagination indicators, and customization dialogs)
* `modules/ii/sidebarDashboard/quickToggles/androidStyle/AndroidToggleDelegateChooser.qml` (Switches and routes clicking bindings to respective singletons)
