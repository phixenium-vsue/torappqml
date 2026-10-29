pragma Singleton
import QtQuick 2.12

QtObject {
    id: theme

    property bool dark: true

    // surfaces
    readonly property color bgApp:    dark ? "#080c16" : "#f4f6fb"
    readonly property color bgCard:   dark ? "#0d1322" : "#ffffff"
    readonly property color bgCard2:  dark ? "#101a2e" : "#eef1f8"
    readonly property color bgRowSel: dark ? "#13203c" : "#e3e9ff"
    readonly property color bgDark:   dark ? "#0a0f1c" : "#e7ebf4"

    // accents
    readonly property color accent:       "#4f63ff"
    readonly property color accent2:      "#6d5cff"
    readonly property color accentViolet: dark ? "#8b5cf6" : "#7c4dff"
    readonly property color teal:         dark ? "#2dd4bf" : "#0d9488"
    readonly property color cyan:         dark ? "#22d3ee" : "#0891b2"
    readonly property color green:        dark ? "#22c55e" : "#16a34a"
    readonly property color greenSoft:    dark ? "#2922c55e" : "#2416a34a"
    readonly property color purple:       dark ? "#a78bfa" : "#7c3aed"
    readonly property color red:          dark ? "#ef4444" : "#dc2626"
    readonly property color yellow:       dark ? "#eab308" : "#ca8a04"
    readonly property color orange:       dark ? "#f59e0b" : "#d97706"
    readonly property color orangeSoft:   dark ? "#33f59e0b" : "#2ed97706"
    readonly property color phosphor:     dark ? "#39ff14" : "#16a34a"
    readonly property color phosphorGlow: dark ? "#6639ff14" : "#4422c55e"

    // text
    readonly property color text:    dark ? "#e9edf6" : "#131826"
    readonly property color textDim: dark ? "#8b93a7" : "#5b6478"
    readonly property color textDim2: dark ? "#6b7388" : "#8a93a7"

    // strokes
    readonly property color stroke:  dark ? "#0fffffff" : "#14000000"
    readonly property color stroke2: dark ? "#1affffff" : "#1f000000"
    readonly property color rowSelBorder: dark ? "#8c4f63ff" : "#664f63ff"

    // hero scene
    readonly property color heroTop: dark ? "#1a1330" : "#dbe4ff"
    readonly property color heroMid: dark ? "#141a33" : "#e8ecff"
    readonly property color heroBot: dark ? "#0c1326" : "#f4f6fb"
    readonly property color mountA1: dark ? "#3a2a6b" : "#b8c4f5"
    readonly property color mountA2: dark ? "#161233" : "#dfe5fb"
    readonly property color mountB1: dark ? "#241a47" : "#c9d2f8"
    readonly property color mountB2: dark ? "#0d0a22" : "#eaeefb"

    // onion states
    readonly property color onionOff1: dark ? "#aab2c4" : "#b9c0cf"
    readonly property color onionOff2: dark ? "#6b7388" : "#98a0b2"
    readonly property color onionOn1:  "#8b5cf6"
    readonly property color onionOn2:  "#6d5cff"
    readonly property color onionGlowOn:  "#638b5cf6"
    readonly property color onionGlowOff: dark ? "#1f2dd4bf" : "#142dd4bf"

    // geometry
    readonly property real radiusCard: 18
    readonly property real radiusRow: 14
    readonly property real radiusBtn: 12
}
