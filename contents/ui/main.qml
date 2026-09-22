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

    // MPRIS Data Model from KDE Plasma
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

    // Volume & Mute State
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

    function seekByOffset(deltaSecs) {
        if (!hasMedia || totalSeconds <= 0) return;
        const newSecs = Math.max(0, Math.min(totalSeconds, currentSeconds + deltaSecs));
        currentSeconds = newSecs;
        if (player) {
            player.position = Math.round(newSecs * 1000000);
            player.updatePosition();
        }
    }

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

    // Reusable Skeuomorphic Bubble Button (42x39px)
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

        // Root container of the 423x381 physical MP3 gadget
        Item {
            id: widgetContainer
            anchors.centerIn: parent
            width: 423
            height: 381
            scale: fullRep.scaleFactor
            transformOrigin: Item.Center

            // Base Chassis (Carcaça)
            Image {
                id: deviceBody
                anchors.fill: parent
                source: Qt.resolvedUrl("../assets/main_back_1_transparent.png")
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
            }

            // Ambient Glass Album Art (Curved glass integration with mask)
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

                    // Contrast gradient over bottom-left to protect TITLE and 7-segment clock
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

            // Seekbar / Timeline (left: 70, top: 234, width: 175, height: 20)
            Item {
                id: seekContainer
                x: 70
                y: 234
                width: 175
                height: 20
                visible: root.hasMedia

                // Green progress fill: clipped dynamically to thumb position
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

                // Slider thumb (width: 44, height: 20)
                Image {
                    id: seekThumb
                    x: seekMouseArea.pressed ? x : (root.totalSeconds > 0 ? Math.round((root.currentSeconds / root.totalSeconds) * 131) : 0)
                    y: 0
                    width: 44
                    height: 20
                    source: {
                        if (seekMouseArea.pressed) {
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

                // Interactive seek MouseArea
                MouseArea {
                    id: seekMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: pressed ? Qt.ClosedHandCursor : (containsMouse ? Qt.PointingHandCursor : Qt.ArrowCursor)

                    drag.target: seekThumb
                    drag.axis: Drag.XAxis
                    drag.minimumX: 0
                    drag.maximumX: 131

                    function seekTo(targetMouseX) {
                        const clampedX = Math.max(0, Math.min(131, targetMouseX - 22));
                        seekThumb.x = clampedX;
                        if (root.totalSeconds > 0) {
                            const ratio = clampedX / 131.0;
                            const newSecs = ratio * root.totalSeconds;
                            root.currentSeconds = newSecs;
                            if (root.player) {
                                root.player.position = Math.round(newSecs * 1000000);
                                root.player.updatePosition();
                            }
                        }
                    }

                    onWheel: function(wheel) {
                        const delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
                        if (delta === 0) return;
                        const step = delta > 0 ? 5 : -5;
                        root.seekByOffset(step);
                    }

                    onPressed: function(mouse) {
                        seekTo(mouse.x);
                    }

                    onPositionChanged: function(mouse) {
                        if (pressed) {
                            seekTo(mouse.x);
                        }
                    }

                    onReleased: function(mouse) {
                        seekTo(mouse.x);
                    }
                }
            }

            // --- The 4 Skeuomorphic Bubble Bottom Buttons (y: 262) ---

            // 1. Play / Pause Button (left: 73, top: 262)
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

            // 2. Stop Button (left: 119, top: 262)
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

            // 3. Previous Track Button (left: 165, top: 262)
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

            // 4. Next Track Button (left: 211, top: 262)
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

            // --- Rotary Volume Knob (left: 255, top: 209, size: 76x76) ---
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

            // --- Mute Button (left: 319, top: 192, size: 29x29) ---
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

            // --- Shuffle / Random Button (left: 305, top: 114, size: 24x25) ---
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
                        // Ativo (On) -> Verde
                        if (btnShuffle.isShuffleOn) {
                            if (shuffMouseArea.pressed) return Qt.resolvedUrl("../assets/eq_xfade_do_2.png")
                            return Qt.resolvedUrl("../assets/eq_xfade_hov_2.png")
                        }
                        // Desligado (Off) -> Azul normal
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

            // --- Repeat / Loop Button (left: 294, top: 139, size: 24x25) ---
            Item {
                id: btnRepeat
                x: 294
                y: 139
                width: 24
                height: 25

                // 3 stages: None (Desligado = 2 Setas Azul), Playlist (Infinito = 2 Setas Verde), Track (Repeat 1 = 1 Seta Verde)
                readonly property int loopState: root.player ? root.player.loopStatus : Mpris.LoopStatus.None

                Image {
                    id: repImg
                    anchors.fill: parent
                    source: {
                        // Estágio: Repeat 1 (Track) -> Ícone de 1 Seta/Loop (pl_rip) Verde!
                        if (btnRepeat.loopState === Mpris.LoopStatus.Track) {
                            if (repMouseArea.pressed) return Qt.resolvedUrl("../assets/pl_rip_do_2.png")
                            return Qt.resolvedUrl("../assets/pl_rip_hov_2.png")
                        }
                        // Estágio: Repeat Infinito (Playlist) -> Ícone de 2 Setas (pl_rep) Verde!
                        if (btnRepeat.loopState === Mpris.LoopStatus.Playlist) {
                            if (repMouseArea.pressed) return Qt.resolvedUrl("../assets/pl_rep_do_2.png")
                            return Qt.resolvedUrl("../assets/pl_rep_hov_2.png")
                        }
                        // Estágio: Desligado (None) -> Ícone de 2 Setas Azul Normal
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
                            root.player.loopStatus = Mpris.LoopStatus.Playlist; // Passa para Verde (Repeat Infinito - 2 setas)
                        } else if (btnRepeat.loopState === Mpris.LoopStatus.Playlist) {
                            root.player.loopStatus = Mpris.LoopStatus.Track; // Passa para Verde (Repeat 1 - 1 loop)
                        } else {
                            root.player.loopStatus = Mpris.LoopStatus.None; // Volta para Azul Normal (Desligado)
                        }
                    }
                }
            }
        }
    }
}
