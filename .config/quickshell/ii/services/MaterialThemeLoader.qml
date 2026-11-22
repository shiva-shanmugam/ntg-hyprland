pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * Automatically reloads generated material colors.
 * It is necessary to run reapplyTheme() on startup because Singletons are lazily loaded.
 */
Singleton {
    id: root
    property string filePath: Directories.generatedMaterialThemePath
    readonly property bool wallpaperThemesEnabled: Config.ready && Config.options.appearance.wallpaperTheming.enableAppsAndShell
    onWallpaperThemesEnabledChanged: {
        if (!wallpaperThemesEnabled)
            Appearance.wallpaperColors = {};
    }

    function reapplyTheme() {
        themeFileView.reload()
    }

    function applyColors(fileContent) {
        if (!wallpaperThemesEnabled || !fileContent) return;
        try {
            const json = JSON.parse(fileContent);
            const entries = {};
            for (const key of Object.keys(json)) {
                const name = "m3" + key.replace(/_([a-z])/g, (_, letter) => letter.toUpperCase());
                if (name in Appearance.m3colors)
                    entries[name] = json[key];
            }
            Appearance.wallpaperColors = entries;
        } catch (error) {
            console.warn("Could not read generated wallpaper colors:", error.message);
        }
    }

    function resetFilePathNextTime() {
        resetFilePathNextWallpaperChange.enabled = true
    }

    Connections {
        id: resetFilePathNextWallpaperChange
        enabled: false
        target: Config.options.background
        function onWallpaperPathChanged() {
            root.filePath = ""
            root.filePath = Directories.generatedMaterialThemePath
            resetFilePathNextWallpaperChange.enabled = false
        }
    }

    Timer {
        id: delayedFileRead
        interval: Config.options?.hacks?.arbitraryRaceConditionDelay ?? 100
        repeat: false
        running: false
        onTriggered: {
            root.applyColors(themeFileView.text())
        }
    }

	FileView { 
        id: themeFileView
        path: root.wallpaperThemesEnabled ? Qt.resolvedUrl(root.filePath) : ""
        watchChanges: true
        onFileChanged: {
            this.reload()
            delayedFileRead.start()
        }
        onLoadedChanged: {
            const fileContent = themeFileView.text()
            root.applyColors(fileContent)
        }
        onLoadFailed: root.resetFilePathNextTime();
    }

    function setMode(mode: string): void {
        if (mode !== "light" && mode !== "dark")
            return;
        if (wallpaperThemesEnabled)
            Config.options.appearance.wallpaperTheming.enableAppsAndShell = false;
        Quickshell.execDetached(["python3", Quickshell.env("HOME") + "/.config/nothing-theme/render.py",
                                 "--mode", mode, "--apply"]);
    }

    function toggleLightDark() {
        root.setMode(root.darkMode ? "light" : "dark");
    }

    readonly property bool darkMode: Appearance.m3colors.darkmode

    GlobalShortcut {
        name: "toggleLightDark"
        description: "Toggles between dark theme and light theme"

        onPressed: {
            root.toggleLightDark();
        }
    }

    IpcHandler {
        target: "theme"

        function currentMode(): string {
            return root.darkMode ? "dark" : "light";
        }

        function toggleLightDark(): void {
            root.toggleLightDark();
        }

        function setMode(mode: string): void {
            root.setMode(mode);
        }
    }
}
