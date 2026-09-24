import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.mpris as Mpris

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    Mpris.Mpris2Model {
        id: mprisModel
    }

    readonly property var player: mprisModel.currentPlayer
    readonly property bool hasMedia: !!(player && player.track && player.track.trim().length > 0 && player.playbackStatus !== Mpris.PlaybackStatus.Stopped)
    readonly property bool isPlaying: player?.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property string currentTitle: player?.track ?? ""
    readonly property string currentArtist: player?.artist ?? ""
    readonly property string albumArtUrl: (hasMedia && player && player.artUrl) ? player.artUrl.toString() : ""
    readonly property string fullDisplayTitle: {
        if (!hasMedia) return ""
        if (currentArtist.length > 0) {
            return currentTitle + " - " + currentArtist
        }
        return currentTitle
    }

    readonly property real totalSeconds: Math.floor((player?.length ?? 0) / 1000000)
    property real currentSeconds: Math.floor((player?.position ?? 0) / 1000000)

    readonly property int elapsedMins: Math.floor(currentSeconds / 60)
    readonly property int elapsedSecs: Math.floor(currentSeconds % 60)
    readonly property int elapsedM1: Math.floor(elapsedMins / 10) % 10
    readonly property int elapsedM2: elapsedMins % 10
    readonly property int elapsedS1: Math.floor(elapsedSecs / 10) % 10
    readonly property int elapsedS2: elapsedSecs % 10

    readonly property int totalMins: Math.floor(totalSeconds / 60)
    readonly property int totalSecs: Math.floor(totalSeconds % 60)
    readonly property int totalM1: Math.floor(totalMins / 10) % 10
    readonly property int totalM2: totalMins % 10
    readonly property int totalS1: Math.floor(totalSecs / 10) % 10
    readonly property int totalS2: totalSecs % 10

    property bool isMuted: false
    property real savedVolume: 0.7
    readonly property real playerVolume: player ? Math.max(0.0, Math.min(1.0, player.volume)) : 0.7
    readonly property real displayVolume: isMuted ? savedVolume : playerVolume
    readonly property int volumeFrame: Math.round(displayVolume * 20)

    onPlayerVolumeChanged: {
        if (playerVolume > 0.02 && !isMuted) {
            savedVolume = playerVolume;
        }
    }

    function adjustVolume(delta) {
        if (!player) return;
        if (isMuted) {
            isMuted = false;
        }
        const newVol = Math.max(0.0, Math.min(1.0, (player.volume || savedVolume) + delta));
        player.volume = newVol;
        savedVolume = newVol;
    }

    function toggleMute() {
        if (!player) return;
        if (!isMuted) {
            if (player.volume > 0.02) {
                savedVolume = player.volume;
            }
            isMuted = true;
            player.volume = 0.0;
        } else {
            isMuted = false;
            player.volume = (savedVolume > 0.05) ? savedVolume : 0.5;
        }
    }

    // Root-level seek state to ensure cross-scope accessibility and prevent binding loss
    property bool isSeeking: false
    property real manualSeekRatio: 0.0

    function seekByOffset(deltaSecs) {
        if (!hasMedia || totalSeconds <= 0) return;
        const newSecs = Math.max(0, Math.min(totalSeconds, currentSeconds + deltaSecs));
        currentSeconds = newSecs;
        if (player) {
            player.position = Math.round(newSecs * 1000000);
            player.updatePosition();
        }
    }

    onCurrentTitleChanged: {
        root.isSeeking = false;
        currentSeconds = 0;
        if (player) {
            player.updatePosition();
        }
        trackSyncTimer.restart();
    }

    Timer {
        id: trackSyncTimer
        interval: 300
        repeat: false
        onTriggered: {
            if (root.player) {
                root.player.updatePosition();
            }
        }
    }

    // 1-second ticker with periodic MPRIS position synchronization
    property int tickerCycles: 0
    Timer {
        id: positionTimer
        interval: 1000
        repeat: true
        running: root.isPlaying && root.hasMedia && !root.isSeeking
        onTriggered: {
            root.tickerCycles++;
            if (root.tickerCycles % 4 === 0) {
                root.player?.updatePosition();
            }
            if (root.currentSeconds < root.totalSeconds) {
                root.currentSeconds += 1;
            }
        }
    }

    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onPositionChanged() {
            if (!root.isSeeking) {
                root.currentSeconds = Math.floor((root.player?.position ?? 0) / 1000000);
            }
        }
        function onPlaybackStatusChanged() {
            if (!root.isSeeking) {
                root.currentSeconds = Math.floor((root.player?.position ?? 0) / 1000000);
            }
        }
        function onTrackChanged() {
            root.isSeeking = false;
            trackSyncTimer.restart();
        }
        function onLengthChanged() {
            trackSyncTimer.restart();
        }
    }

    // 7-segment large digit (18x29px)
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

    // 7-segment small digit (8x13px)
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

    // Skeuomorphic bubble button (42x39px)
    component BubbleButton: Item {
        id: bubbleBtn
        width: 42
        height: 39
        property url normalSource
        property url hoverSource
        property url downSource
        property url disabledSource
        property bool isEnabled: true
        signal clicked()

        Image {
            id: btnImg
            anchors.fill: parent
            source: {
                if (!bubbleBtn.isEnabled && bubbleBtn.disabledSource != "") {
                    return bubbleBtn.disabledSource
                }
                if (btnMouseArea.pressed) {
                    return bubbleBtn.downSource
                }
                if (btnMouseArea.containsMouse) {
                    return bubbleBtn.hoverSource
                }
                return bubbleBtn.normalSource
            }
            smooth: true
            mipmap: true

            transform: [
                Translate {
                    y: btnMouseArea.pressed ? 2 : 0
                    Behavior on y { NumberAnimation { duration: 60 } }
                },
                Scale {
                    origin.x: 21
                    origin.y: 20
                    xScale: btnMouseArea.pressed ? 0.97 : 1.0
                    yScale: btnMouseArea.pressed ? 0.97 : 1.0
                    Behavior on xScale { NumberAnimation { duration: 60 } }
                    Behavior on yScale { NumberAnimation { duration: 60 } }
                }
            ]
        }

        MouseArea {
            id: btnMouseArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: bubbleBtn.isEnabled
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: bubbleBtn.clicked()
        }
    }

    fullRepresentation: Item {
        id: fullRep
        implicitWidth: 423
        implicitHeight: 381
        Layout.preferredWidth: 423
        Layout.preferredHeight: 381
        Layout.minimumWidth: 200
        Layout.minimumHeight: 180

        readonly property real scaleFactor: Math.min(width / 423, height / 381)

        // Base 423x381 physical chassis container with proportional scaling
        Item {
            id: widgetContainer
            anchors.centerIn: parent
            width: 423
            height: 381
            scale: fullRep.scaleFactor
            transformOrigin: Item.Center

            Image {
                id: deviceBody
                anchors.fill: parent
                source: Qt.resolvedUrl("../assets/main_back_1_transparent.png")
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
            }

            // Ambient glass album art masked to curved LCD viewport
            Item {
                id: ambientScreenArea
                x: 66
                y: 90
                width: 243
                height: 129
                visible: root.hasMedia && root.albumArtUrl.length > 0

                Item {
                    id: ambientSource
                    anchors.fill: parent
                    visible: false

                    Image {
                        id: coverImage
                        anchors.fill: parent
                        source: root.albumArtUrl
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        asynchronous: true
                    }

                    // Contrast gradient to ensure title and digit readability
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Qt.rgba(0.01, 0.1, 0.28, 0.80) }
                            GradientStop { position: 0.55; color: Qt.rgba(0.01, 0.1, 0.28, 0.35) }
                            GradientStop { position: 1.0; color: Qt.rgba(0.01, 0.1, 0.28, 0.10) }
                        }
                    }
                }

                Image {
                    id: screenMask
                    anchors.fill: parent
                    source: Qt.resolvedUrl("../assets/screen_mask_alpha.png")
                    visible: false
                    smooth: true
                }

                GE.OpacityMask {
                    anchors.fill: parent
                    source: ambientSource
                    maskSource: screenMask
                    opacity: 1.00
                }
            }

            // Track title display area
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

            // Elapsed time display (TIME)
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

            // Total duration display (TOTAL)
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

            // Timeline seekbar
            Item {
                id: seekContainer
                x: 70
                y: 234
                width: 175
                height: 20
                visible: root.hasMedia

                // Progress fill clipped dynamically to slider thumb position
                Item {
                    id: seekFillClip
                    x: 0
                    y: 0
                    height: 20
                    width: seekThumb.x > 0 ? Math.min(175, seekThumb.x + 22) : 0
                    clip: true

                    Image {
                        x: 0
                        y: 0
                        width: 175
                        height: 20
                        source: Qt.resolvedUrl("../assets/seek_slider_1.png")
                        smooth: true
                        mipmap: true
                    }
                }

                // Slider thumb (44x20px)
                Image {
                    id: seekThumb
                    x: root.isSeeking
                        ? Math.round(root.manualSeekRatio * 131)
                        : (root.totalSeconds > 0 ? Math.round(Math.min(1.0, Math.max(0.0, root.currentSeconds / root.totalSeconds)) * 131) : 0)
                    y: 0
                    width: 44
                    height: 20
                    source: {
                        if (root.isSeeking) {
                            return Qt.resolvedUrl("../assets/seek_thumb_do_1.png")
                        }
                        if (seekMouseArea.containsMouse) {
                            return Qt.resolvedUrl("../assets/seek_thumb_hov_1.png")
                        }
                        return Qt.resolvedUrl("../assets/seek_thumb_no_1.png")
                    }
                    smooth: true
                    mipmap: true
                }

                MouseArea {
                    id: seekMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    preventStealing: true
                    cursorShape: root.isSeeking ? Qt.ClosedHandCursor : (containsMouse ? Qt.PointingHandCursor : Qt.ArrowCursor)

                    function updateManualPosition(mouseX) {
                        const clampedPixel = Math.max(0, Math.min(131, mouseX - 22));
                        root.manualSeekRatio = clampedPixel / 131.0;
                        if (root.totalSeconds > 0) {
                            root.currentSeconds = root.manualSeekRatio * root.totalSeconds;
                        }
                    }

                    function commitSeek() {
                        if (root.totalSeconds > 0 && root.player) {
                            const newSecs = root.manualSeekRatio * root.totalSeconds;
                            root.currentSeconds = newSecs;
                            root.player.position = Math.round(newSecs * 1000000);
                            root.player.updatePosition();
                        }
                    }

                    onPressed: function(mouse) {
                        root.isSeeking = true;
                        updateManualPosition(mouse.x);
                    }

                    onPositionChanged: function(mouse) {
                        if (root.isSeeking) {
                            updateManualPosition(mouse.x);
                        }
                    }

                    onReleased: function(mouse) {
                        if (root.isSeeking) {
                            updateManualPosition(mouse.x);
                            commitSeek();
                            root.isSeeking = false;
                        }
                    }

                    onCanceled: {
                        root.isSeeking = false;
                    }

                    onWheel: function(wheel) {
                        const delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
                        if (delta === 0) return;
                        const step = delta > 0 ? 5 : -5;
                        root.seekByOffset(step);
                    }
                }
            }

            // Transport bubble buttons
            BubbleButton {
                id: btnPlayPause
                x: 73
                y: 262
                normalSource: root.isPlaying
                    ? Qt.resolvedUrl("../assets/m_pause_no_1.png")
                    : Qt.resolvedUrl("../assets/m_play_no_1.png")
                hoverSource: root.isPlaying
                    ? Qt.resolvedUrl("../assets/m_pause_hov_1.png")
                    : Qt.resolvedUrl("../assets/m_play_hov_1.png")
                downSource: root.isPlaying
                    ? Qt.resolvedUrl("../assets/m_pause_do_1.png")
                    : Qt.resolvedUrl("../assets/m_play_do_1.png")
                disabledSource: Qt.resolvedUrl("../assets/m_play_dis_1.png")
                isEnabled: !!root.player
                onClicked: {
                    if (root.player) {
                        root.player.PlayPause();
                    }
                }
            }

            BubbleButton {
                id: btnStop
                x: 119
                y: 262
                normalSource: Qt.resolvedUrl("../assets/m_stop_no_1.png")
                hoverSource: Qt.resolvedUrl("../assets/m_stop_hov_1.png")
                downSource: Qt.resolvedUrl("../assets/m_stop_do_1.png")
                disabledSource: Qt.resolvedUrl("../assets/m_stop_dis_1.png")
                isEnabled: root.hasMedia
                onClicked: {
                    if (root.player) {
                        root.player.Stop();
                    }
                }
            }

            BubbleButton {
                id: btnPrev
                x: 165
                y: 262
                normalSource: Qt.resolvedUrl("../assets/m_prev_no_1.png")
                hoverSource: Qt.resolvedUrl("../assets/m_prev_hov_1.png")
                downSource: Qt.resolvedUrl("../assets/m_prev_do_1.png")
                disabledSource: Qt.resolvedUrl("../assets/m_prev_dis_1.png")
                isEnabled: root.hasMedia
                onClicked: {
                    if (root.player) {
                        root.player.Previous();
                    }
                }
            }

            BubbleButton {
                id: btnNext
                x: 211
                y: 262
                normalSource: Qt.resolvedUrl("../assets/m_next_no_1.png")
                hoverSource: Qt.resolvedUrl("../assets/m_next_hov_1.png")
                downSource: Qt.resolvedUrl("../assets/m_next_do_1.png")
                disabledSource: Qt.resolvedUrl("../assets/m_next_dis_1.png")
                isEnabled: root.hasMedia
                onClicked: {
                    if (root.player) {
                        root.player.Next();
                    }
                }
            }

            // Rotary volume knob (21-frame spritesheet)
            Item {
                id: volumeKnob
                x: 255
                y: 209
                width: 76
                height: 76
                clip: true

                Image {
                    id: knobSprite
                    x: -root.volumeFrame * 76
                    y: 0
                    width: 1596
                    height: 76
                    source: Qt.resolvedUrl("../assets/volume_1.png")
                    smooth: true
                }

                MouseArea {
                    id: knobMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    preventStealing: true
                    cursorShape: Qt.SizeVerCursor

                    property real startY: 0
                    property real startVol: 0

                    onWheel: function(wheel) {
                        const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                        root.adjustVolume(step);
                    }

                    onPressed: function(mouse) {
                        startY = mouse.y;
                        startVol = root.displayVolume;
                    }

                    onPositionChanged: function(mouse) {
                        if (pressed) {
                            const deltaY = startY - mouse.y;
                            const volDelta = deltaY / 120.0;
                            const newVol = Math.max(0.0, Math.min(1.0, startVol + volDelta));
                            if (root.player) {
                                if (root.isMuted) root.isMuted = false;
                                root.player.volume = newVol;
                                root.savedVolume = newVol;
                            }
                        }
                    }
                }
            }

            // Mute toggle button
            Item {
                id: btnMute
                x: 319
                y: 192
                width: 29
                height: 29

                Image {
                    id: muteImg
                    anchors.fill: parent
                    source: {
                        if (root.isMuted) {
                            return Qt.resolvedUrl("../assets/m_mute_do_1.png")
                        }
                        if (muteMouseArea.pressed) {
                            return Qt.resolvedUrl("../assets/m_mute_do_1.png")
                        }
                        if (muteMouseArea.containsMouse) {
                            return Qt.resolvedUrl("../assets/m_mute_hov_1.png")
                        }
                        return Qt.resolvedUrl("../assets/m_mute_no_1.png")
                    }
                    smooth: true
                    mipmap: true

                    transform: [
                        Translate {
                            y: (muteMouseArea.pressed || root.isMuted) ? 1.5 : 0
                            Behavior on y { NumberAnimation { duration: 60 } }
                        },
                        Scale {
                            origin.x: 14
                            origin.y: 14
                            xScale: (muteMouseArea.pressed || root.isMuted) ? 0.96 : 1.0
                            yScale: (muteMouseArea.pressed || root.isMuted) ? 0.96 : 1.0
                            Behavior on xScale { NumberAnimation { duration: 60 } }
                            Behavior on yScale { NumberAnimation { duration: 60 } }
                        }
                    ]
                }

                MouseArea {
                    id: muteMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleMute()
                }
            }

            // Shuffle button
            Item {
                id: btnShuffle
                x: 305
                y: 114
                width: 24
                height: 25

                readonly property bool isShuffleOn: root.player?.shuffle === Mpris.ShuffleStatus.On

                Image {
                    id: shuffImg
                    anchors.fill: parent
                    source: {
                        if (btnShuffle.isShuffleOn) {
                            if (shuffMouseArea.pressed) return Qt.resolvedUrl("../assets/eq_xfade_do_2.png")
                            return Qt.resolvedUrl("../assets/eq_xfade_hov_2.png")
                        }
                        if (shuffMouseArea.pressed) return Qt.resolvedUrl("../assets/eq_xfade_do_1.png")
                        if (shuffMouseArea.containsMouse) return Qt.resolvedUrl("../assets/eq_xfade_hov_1.png")
                        return Qt.resolvedUrl("../assets/eq_xfade_no_1.png")
                    }
                    smooth: true
                    mipmap: true

                    transform: [
                        Translate {
                            y: shuffMouseArea.pressed ? 1.5 : 0
                            Behavior on y { NumberAnimation { duration: 60 } }
                        },
                        Scale {
                            origin.x: 12
                            origin.y: 12
                            xScale: shuffMouseArea.pressed ? 0.96 : 1.0
                            yScale: shuffMouseArea.pressed ? 0.96 : 1.0
                            Behavior on xScale { NumberAnimation { duration: 60 } }
                            Behavior on yScale { NumberAnimation { duration: 60 } }
                        }
                    ]
                }

                MouseArea {
                    id: shuffMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.player) return;
                        if (btnShuffle.isShuffleOn) {
                            root.player.shuffle = Mpris.ShuffleStatus.Off;
                        } else {
                            root.player.shuffle = Mpris.ShuffleStatus.On;
                        }
                    }
                }
            }

            // Repeat button (None -> Playlist -> Track)
            Item {
                id: btnRepeat
                x: 294
                y: 139
                width: 24
                height: 25

                readonly property int loopState: root.player ? root.player.loopStatus : Mpris.LoopStatus.None

                Image {
                    id: repImg
                    anchors.fill: parent
                    source: {
                        if (btnRepeat.loopState === Mpris.LoopStatus.Track) {
                            if (repMouseArea.pressed) return Qt.resolvedUrl("../assets/pl_rip_do_2.png")
                            return Qt.resolvedUrl("../assets/pl_rip_hov_2.png")
                        }
                        if (btnRepeat.loopState === Mpris.LoopStatus.Playlist) {
                            if (repMouseArea.pressed) return Qt.resolvedUrl("../assets/pl_rep_do_2.png")
                            return Qt.resolvedUrl("../assets/pl_rep_hov_2.png")
                        }
                        if (repMouseArea.pressed) return Qt.resolvedUrl("../assets/pl_rep_do_1.png")
                        if (repMouseArea.containsMouse) return Qt.resolvedUrl("../assets/pl_rep_hov_1.png")
                        return Qt.resolvedUrl("../assets/pl_rep_no_1.png")
                    }
                    smooth: true
                    mipmap: true

                    transform: [
                        Translate {
                            y: repMouseArea.pressed ? 1.5 : 0
                            Behavior on y { NumberAnimation { duration: 60 } }
                        },
                        Scale {
                            origin.x: 12
                            origin.y: 12
                            xScale: repMouseArea.pressed ? 0.96 : 1.0
                            yScale: repMouseArea.pressed ? 0.96 : 1.0
                            Behavior on xScale { NumberAnimation { duration: 60 } }
                            Behavior on yScale { NumberAnimation { duration: 60 } }
                        }
                    ]
                }

                MouseArea {
                    id: repMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.player) return;
                        if (btnRepeat.loopState === Mpris.LoopStatus.None) {
                            root.player.loopStatus = Mpris.LoopStatus.Playlist;
                        } else if (btnRepeat.loopState === Mpris.LoopStatus.Playlist) {
                            root.player.loopStatus = Mpris.LoopStatus.Track;
                        } else {
                            root.player.loopStatus = Mpris.LoopStatus.None;
                        }
                    }
                }
            }
        }
    }
}
