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
    readonly property string currentTitle: hasMedia ? player.track : ""
    readonly property string currentArtist: (hasMedia && player.artist) ? player.artist : ""
    readonly property string fullDisplayTitle: {
        if (!hasMedia) return ""
        if (currentArtist.length > 0) {
            return currentTitle + " - " + currentArtist
        }
        return currentTitle
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

                // Reset position when song changes
                onTextChanged: {
                    marqueeAnimState.currentX = 0
                }

                QtObject {
                    id: marqueeAnimState
                    property real currentX: 0

                    SequentialAnimation on currentX {
                        running: titleText.shouldScroll && root.hasMedia
                        loops: Animation.Infinite

                        // Pause initially so the user can read the start
                        PauseAnimation {
                            duration: 1800
                        }

                        // Scroll out to the left
                        NumberAnimation {
                            from: 0
                            to: -(titleText.contentWidth + 24)
                            duration: Math.max(2500, (titleText.contentWidth + 24) * 25)
                            easing.type: Easing.Linear
                        }

                        // Reposition to the right edge
                        PropertyAction {
                            value: titleContainer.width
                        }

                        // Scroll back into view
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
    }
}
