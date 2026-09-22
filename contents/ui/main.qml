import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.mpris as Mpris

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // MPRIS Data Model from KDE Plasma
    Mpris.Mpris2Model {
        id: mprisModel
    }

    readonly property var player: mprisModel.currentPlayer
    readonly property bool hasMedia: !!(player && player.track && player.track.trim().length > 0 && player.playbackStatus !== Mpris.PlaybackStatus.Stopped)
    readonly property bool isPlaying: player?.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property string currentTitle: player?.track ?? ""
    readonly property string currentArtist: player?.artist ?? ""
    readonly property string fullDisplayTitle: {
        if (!hasMedia) return ""
        if (currentArtist.length > 0) {
            return currentTitle + " - " + currentArtist
        }
        return currentTitle
    }

    // Time & Position tracking (in seconds)
    readonly property real totalSeconds: Math.floor((player?.length ?? 0) / 1000000)
    property real currentSeconds: Math.floor((player?.position ?? 0) / 1000000)

    // Format digits for elapsed time (TIME)
    readonly property int elapsedMins: Math.floor(currentSeconds / 60)
    readonly property int elapsedSecs: Math.floor(currentSeconds % 60)
    readonly property int elapsedM1: Math.floor(elapsedMins / 10) % 10
    readonly property int elapsedM2: elapsedMins % 10
    readonly property int elapsedS1: Math.floor(elapsedSecs / 10) % 10
    readonly property int elapsedS2: elapsedSecs % 10

    // Format digits for total duration (TOTAL)
    readonly property int totalMins: Math.floor(totalSeconds / 60)
    readonly property int totalSecs: Math.floor(totalSeconds % 60)
    readonly property int totalM1: Math.floor(totalMins / 10) % 10
    readonly property int totalM2: totalMins % 10
    readonly property int totalS1: Math.floor(totalSecs / 10) % 10
    readonly property int totalS2: totalSecs % 10

    // 1-second position ticker during active playback
    Timer {
        id: positionTimer
        interval: 1000
        repeat: true
        running: root.isPlaying && root.hasMedia
        onTriggered: {
            if (root.currentSeconds < root.totalSeconds) {
                root.currentSeconds += 1
            } else {
                root.player?.updatePosition()
            }
        }
    }

    // Sync position when player updates or seeks
    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onPositionChanged() {
            root.currentSeconds = Math.floor((root.player?.position ?? 0) / 1000000)
        }
        function onPlaybackStatusChanged() {
            root.currentSeconds = Math.floor((root.player?.position ?? 0) / 1000000)
        }
        function onTrackChanged() {
            root.currentSeconds = Math.floor((root.player?.position ?? 0) / 1000000)
        }
    }

    // Reusable 7-Segment Large Digit (18x29px)
    component LargeDigit: Item {
        width: 18
        height: 29
        clip: true
        property int value: 0

        Image {
            x: -Math.max(0, Math.min(9, parent.value)) * 18
            y: 0
            source: Qt.resolvedUrl("../assets/time_1_1.png")
            smooth: false
        }
    }

    // Reusable 7-Segment Small Digit (8x13px)
    component SmallDigit: Item {
        width: 8
        height: 13
        clip: true
        property int value: 0

        Image {
            x: -Math.max(0, Math.min(9, parent.value)) * 8
            y: 0
            source: Qt.resolvedUrl("../assets/dtime_1.png")
            smooth: false
        }
    }

    fullRepresentation: Item {
        id: fullRep
        implicitWidth: 423
        implicitHeight: 381
        Layout.preferredWidth: 423
        Layout.preferredHeight: 381
        Layout.minimumWidth: 423
        Layout.minimumHeight: 381

        // Base Chassis (Carcaça)
        Image {
            id: deviceBody
            anchors.centerIn: parent
            width: 423
            height: 381
            source: Qt.resolvedUrl("../assets/main_back_1_transparent.png")
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
        }

        // Title Display Area right below the "TITLE" label
        Item {
            id: titleContainer
            x: 93
            y: 147
            width: 182
            height: 22
            clip: true

            Text {
                id: titleText
                text: root.fullDisplayTitle
                visible: root.hasMedia
                color: "#ffffff"
                font.family: "Tahoma, Segoe UI, sans-serif"
                font.pixelSize: 11
                font.bold: true
                style: Text.Outline
                styleColor: "#001a33"
                anchors.verticalCenter: parent.verticalCenter

                readonly property bool shouldScroll: contentWidth > titleContainer.width

                x: shouldScroll ? marqueeAnimState.currentX : 0

                onTextChanged: {
                    marqueeAnimState.currentX = 0
                }

                QtObject {
                    id: marqueeAnimState
                    property real currentX: 0

                    SequentialAnimation on currentX {
                        running: titleText.shouldScroll && root.hasMedia
                        loops: Animation.Infinite

                        PauseAnimation {
                            duration: 1800
                        }

                        NumberAnimation {
                            from: 0
                            to: -(titleText.contentWidth + 24)
                            duration: Math.max(2500, (titleText.contentWidth + 24) * 25)
                            easing.type: Easing.Linear
                        }

                        PropertyAction {
                            value: titleContainer.width
                        }

                        NumberAnimation {
                            from: titleContainer.width
                            to: 0
                            duration: Math.max(1200, titleContainer.width * 25)
                            easing.type: Easing.Linear
                        }
                    }
                }
            }
        }

        // 7-Segment Main Clock: TIME (left: 86, top: 173)
        Item {
            id: timeDisplay
            x: 86
            y: 173
            width: 95
            height: 29
            visible: root.hasMedia

            LargeDigit {
                x: 18
                value: root.elapsedM1
            }
            LargeDigit {
                x: 36
                value: root.elapsedM2
            }
            Image {
                x: 50
                source: Qt.resolvedUrl("../assets/time_sign_1.png")
                smooth: false
            }
            LargeDigit {
                x: 59
                value: root.elapsedS1
            }
            LargeDigit {
                x: 77
                value: root.elapsedS2
            }
        }

        // 7-Segment Total Duration Clock: TOTAL (left: 190, top: 187)
        Item {
            id: dtimeDisplay
            x: 190
            y: 187
            width: 35
            height: 13
            visible: root.hasMedia

            SmallDigit {
                x: 0
                value: root.totalM1
            }
            SmallDigit {
                x: 8
                value: root.totalM2
            }
            Image {
                x: 15
                source: Qt.resolvedUrl("../assets/dtime_sign_1.png")
                smooth: false
            }
            SmallDigit {
                x: 18
                value: root.totalS1
            }
            SmallDigit {
                x: 26
                value: root.totalS2
            }
        }
    }
}
