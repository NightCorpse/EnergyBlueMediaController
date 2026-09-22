import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    fullRepresentation: Item {
        id: fullRep
        implicitWidth: 423
        implicitHeight: 381
        Layout.preferredWidth: 423
        Layout.preferredHeight: 381
        Layout.minimumWidth: 423
        Layout.minimumHeight: 381

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
    }
}
