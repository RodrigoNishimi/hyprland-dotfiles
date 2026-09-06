pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import "."

Rectangle {
    id: mediaWidget

    // ── PROPRIEDADES DE CONFIGURAÇÃO E ESTADO ──────────────────────────────────
    property bool autoHideWhenIdle: false
    property bool showVolumeControl: false
    property bool showPlayerPicker: true
    property bool compact: false

    width: parent ? parent.width : 412
    height: visible ? implicitHeight : 0
    implicitHeight: compact ? (compactCol.implicitHeight + 20) : (layoutCol.implicitHeight + 24)
    radius: 16
    color: Theme.surface

    visible: !autoHideWhenIdle || hasActiveMedia

    // ── GERENCIAMENTO DE PLAYERS MPRIS & PLAYERCTL ────────────────────────────
    property int selectedPlayerIndex: 0
    property real currentPosition: 0

    // Filtra instâncias vazias do playerctld sem player associado
    readonly property var playersList: {
        const all = Mpris.players ? Mpris.players.values : [];
        const valid = [];
        for (let i = 0; i < all.length; i++) {
            const p = all[i];
            if (!p) continue;
            // Se for playerctld sem faixa ativa, ignora para não poluir
            if (p.dbusName && p.dbusName.includes("playerctld") && !p.trackTitle && !p.isPlaying) {
                continue;
            }
            valid.push(p);
        }
        return valid;
    }

    readonly property int playersCount: playersList.length
    readonly property bool hasActiveMedia: activePlayer !== null && ((activePlayer.trackTitle && activePlayer.trackTitle.length > 0) || activePlayer.isPlaying)

    // Seleciona o player atual (prioriza o que estiver tocando ativamente ou o índice manual)
    readonly property var activePlayer: {
        if (playersList.length === 0) return null;
        if (selectedPlayerIndex >= 0 && selectedPlayerIndex < playersList.length) {
            return playersList[selectedPlayerIndex];
        }
        for (let i = 0; i < playersList.length; i++) {
            if (playersList[i].isPlaying) return playersList[i];
        }
        return playersList[0];
    }

    onPlayersCountChanged: {
        if (selectedPlayerIndex >= playersList.length) {
            selectedPlayerIndex = Math.max(0, playersList.length - 1);
        }
    }

    // ── MÉTODOS AUXILIARES ───────────────────────────────────────────────────
    function formatTime(seconds: real): string {
        if (isNaN(seconds) || seconds < 0) return "0:00";
        const total = Math.floor(seconds);
        const hrs = Math.floor(total / 3600);
        const mins = Math.floor((total % 3600) / 60);
        const secs = total % 60;
        const secStr = secs < 10 ? "0" + secs : secs.toString();

        if (hrs > 0) {
            const minStr = mins < 10 ? "0" + mins : mins.toString();
            return hrs + ":" + minStr + ":" + secStr;
        }
        return mins + ":" + secStr;
    }

    function getPlayerIcon(name: string): string {
        if (!name) return "󰝚";
        const lower = name.toLowerCase();
        if (lower.includes("spotify")) return "󰓇";
        if (lower.includes("firefox")) return "󰈹";
        if (lower.includes("chrome") || lower.includes("chromium") || lower.includes("brave")) return "󰖟";
        if (lower.includes("vlc")) return "󰕼";
        if (lower.includes("mpv")) return "";
        if (lower.includes("discord")) return "󰙯";
        if (lower.includes("amberol") || lower.includes("rhythmbox") || lower.includes("music")) return "󰝚";
        return "󰎆";
    }

    function seekTo(targetSec: real): void {
        if (!activePlayer || !activePlayer.canSeek) return;
        const bounded = Math.max(0, Math.min(activePlayer.length > 0 ? activePlayer.length : targetSec, targetSec));
        if (activePlayer.positionSupported) {
            activePlayer.position = bounded;
        } else {
            const offset = bounded - currentPosition;
            activePlayer.seek(offset);
        }
        currentPosition = bounded;
    }

    // Timer suave para atualizar o contador da barra de progresso durante o playback
    Timer {
        id: progressTick
        interval: 1000
        repeat: true
        running: mediaWidget.activePlayer !== null && mediaWidget.activePlayer.isPlaying && !seekArea.pressed
        onTriggered: {
            if (mediaWidget.activePlayer && mediaWidget.activePlayer.positionSupported) {
                mediaWidget.currentPosition = mediaWidget.activePlayer.position;
            }
        }
    }

    Connections {
        target: mediaWidget.activePlayer
        function onPositionChanged() {
            if (mediaWidget.activePlayer && !seekArea.pressed) {
                mediaWidget.currentPosition = mediaWidget.activePlayer.position;
            }
        }
        function onTrackChanged() {
            if (mediaWidget.activePlayer) {
                mediaWidget.currentPosition = mediaWidget.activePlayer.position;
            }
        }
        function onPlaybackStateChanged() {
            if (mediaWidget.activePlayer) {
                mediaWidget.currentPosition = mediaWidget.activePlayer.position;
            }
        }
    }

    // ── LAYOUT EXPANDIDO / COMPLETO (Ideal para Centro de Controle) ───────────
    Column {
        id: layoutCol
        visible: !mediaWidget.compact
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 10

        // 1. CABEÇALHO (Player Ativo + Switcher + Shuffle/Loop)
        RowLayout {
            width: parent.width
            spacing: 8

            // Badge com Ícone e Nome do Player
            Rectangle {
                Layout.preferredHeight: 24
                Layout.preferredWidth: Math.min(playerBadgeRow.implicitWidth + 14, 180)
                radius: 6
                color: Theme.overlay

                Row {
                    id: playerBadgeRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: mediaWidget.getPlayerIcon(mediaWidget.activePlayer ? mediaWidget.activePlayer.identity : "")
                        font.family: "Hack Nerd Font"
                        font.pixelSize: 13
                        color: Theme.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: mediaWidget.activePlayer ? (mediaWidget.activePlayer.identity || "Media Player") : "Nenhum Player"
                        font.family: "Hack Nerd Font"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: Theme.text
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, 130)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Alternador entre múltiplos players
            Row {
                visible: mediaWidget.showPlayerPicker && mediaWidget.playersCount > 1
                spacing: 4

                Rectangle {
                    width: 22
                    height: 22
                    radius: 5
                    color: prevPlayerMouse.containsMouse ? Theme.highlightMed : Theme.overlay

                    Text {
                        anchors.centerIn: parent
                        text: "󰅁"
                        font.family: "Hack Nerd Font"
                        font.pixelSize: 12
                        color: Theme.text
                    }
                    MouseArea {
                        id: prevPlayerMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(m) {
                            m.accepted = true;
                            mediaWidget.selectedPlayerIndex = (mediaWidget.selectedPlayerIndex - 1 + mediaWidget.playersCount) % mediaWidget.playersCount;
                        }
                    }
                }

                Rectangle {
                    width: 22
                    height: 22
                    radius: 5
                    color: nextPlayerMouse.containsMouse ? Theme.highlightMed : Theme.overlay

                    Text {
                        anchors.centerIn: parent
                        text: "󰅂"
                        font.family: "Hack Nerd Font"
                        font.pixelSize: 12
                        color: Theme.text
                    }
                    MouseArea {
                        id: nextPlayerMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(m) {
                            m.accepted = true;
                            mediaWidget.selectedPlayerIndex = (mediaWidget.selectedPlayerIndex + 1) % mediaWidget.playersCount;
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Botão Shuffle
            Rectangle {
                visible: mediaWidget.activePlayer !== null && mediaWidget.activePlayer.shuffleSupported
                width: 24
                height: 24
                radius: 6
                color: shuffleMouse.containsMouse ? Theme.highlightMed : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "󰒝"
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 13
                    color: (mediaWidget.activePlayer && mediaWidget.activePlayer.shuffle) ? Theme.accent : Theme.muted
                }
                MouseArea {
                    id: shuffleMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(m) {
                        m.accepted = true;
                        if (mediaWidget.activePlayer) {
                            mediaWidget.activePlayer.shuffle = !mediaWidget.activePlayer.shuffle;
                        }
                    }
                }
            }

            // Botão Loop / Repetição
            Rectangle {
                visible: mediaWidget.activePlayer !== null && mediaWidget.activePlayer.loopSupported
                width: 24
                height: 24
                radius: 6
                color: loopMouse.containsMouse ? Theme.highlightMed : "transparent"

                readonly property int loopVal: mediaWidget.activePlayer ? mediaWidget.activePlayer.loopState : MprisLoopState.None

                Text {
                    anchors.centerIn: parent
                    text: {
                        if (parent.loopVal === MprisLoopState.Track) return "󰑘";
                        if (parent.loopVal === MprisLoopState.Playlist) return "󰑗";
                        return "󰑖";
                    }
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 13
                    color: parent.loopVal !== MprisLoopState.None ? Theme.accent : Theme.muted
                }
                MouseArea {
                    id: loopMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(m) {
                        m.accepted = true;
                        if (mediaWidget.activePlayer) {
                            if (mediaWidget.activePlayer.loopState === MprisLoopState.None) {
                                mediaWidget.activePlayer.loopState = MprisLoopState.Playlist;
                            } else if (mediaWidget.activePlayer.loopState === MprisLoopState.Playlist) {
                                mediaWidget.activePlayer.loopState = MprisLoopState.Track;
                            } else {
                                mediaWidget.activePlayer.loopState = MprisLoopState.None;
                            }
                        }
                    }
                }
            }
        }

        // 2. CAPA & METADADOS DA MÍDIA
        RowLayout {
            width: parent.width
            spacing: 12

            // Capa do Álbum / Thumbnail
            Rectangle {
                id: albumArtFrame
                Layout.preferredWidth: 54
                Layout.preferredHeight: 54
                radius: 10
                color: Theme.overlay
                clip: true

                Text {
                    anchors.centerIn: parent
                    text: mediaWidget.getPlayerIcon(mediaWidget.activePlayer ? mediaWidget.activePlayer.identity : "")
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 24
                    color: Theme.muted
                    visible: artImage.status !== Image.Ready
                }

                Image {
                    id: artImage
                    anchors.fill: parent
                    source: (mediaWidget.activePlayer && mediaWidget.activePlayer.trackArtUrl) ? mediaWidget.activePlayer.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    mipmap: true
                    visible: status === Image.Ready
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: (mediaWidget.activePlayer && mediaWidget.activePlayer.canRaise) ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: function(m) {
                        m.accepted = true;
                        if (mediaWidget.activePlayer && mediaWidget.activePlayer.canRaise) {
                            mediaWidget.activePlayer.raise();
                        }
                    }
                }
            }

            // Título, Artista e Álbum
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: mediaWidget.hasActiveMedia ? (mediaWidget.activePlayer.trackTitle || "Sem título") : "Nenhuma mídia reproduzindo"
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: Theme.text
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    Layout.fillWidth: true
                    text: mediaWidget.hasActiveMedia ? (mediaWidget.activePlayer.trackArtist || mediaWidget.activePlayer.trackAlbumArtist || "Desconhecido") : "Inicie o Spotify, YouTube ou player favorito"
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 11
                    color: Theme.subtle
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    Layout.fillWidth: true
                    text: (mediaWidget.hasActiveMedia && mediaWidget.activePlayer.trackAlbum) ? mediaWidget.activePlayer.trackAlbum : ""
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 10
                    color: Theme.muted
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    visible: text.length > 0
                }
            }
        }

        // 3. BARRA DE PROGRESSO & TIMELINE (SEEKBAR)
        Column {
            width: parent.width
            spacing: 3
            visible: mediaWidget.hasActiveMedia && mediaWidget.activePlayer.lengthSupported && mediaWidget.activePlayer.length > 0

            RowLayout {
                width: parent.width
                spacing: 8

                // Tempo Atual
                Text {
                    text: mediaWidget.formatTime(mediaWidget.currentPosition)
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 10
                    color: Theme.muted
                    Layout.preferredWidth: 35
                    horizontalAlignment: Text.AlignRight
                }

                // Trilha da SeekBar
                Rectangle {
                    id: seekTrack
                    Layout.fillWidth: true
                    height: 5
                    radius: 2.5
                    color: Theme.overlay

                    readonly property real progressRatio: {
                        if (!mediaWidget.activePlayer || !mediaWidget.activePlayer.length || mediaWidget.activePlayer.length <= 0) return 0;
                        return Math.max(0.0, Math.min(1.0, mediaWidget.currentPosition / mediaWidget.activePlayer.length));
                    }

                    Rectangle {
                        width: parent.width * seekTrack.progressRatio
                        height: parent.height
                        radius: 2.5
                        color: Theme.accent
                    }

                    Rectangle {
                        width: 10
                        height: 10
                        radius: 5
                        color: Theme.accent
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(0, Math.min(parent.width - 10, (parent.width * seekTrack.progressRatio) - 5))
                        visible: seekArea.containsMouse || seekArea.pressed
                    }

                    WheelHandler {
                        onWheel: function(e) {
                            const delta = e.angleDelta.y > 0 ? 5 : -5;
                            mediaWidget.seekTo(mediaWidget.currentPosition + delta);
                        }
                    }

                    MouseArea {
                        id: seekArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        function applySeek(m) {
                            if (!mediaWidget.activePlayer || mediaWidget.activePlayer.length <= 0) return;
                            const posOnTrack = mapToItem(seekTrack, m.x, 0).x;
                            const ratio = Math.max(0.0, Math.min(1.0, posOnTrack / seekTrack.width));
                            const targetTime = ratio * mediaWidget.activePlayer.length;
                            mediaWidget.seekTo(targetTime);
                        }

                        onPressed: function(m) {
                            m.accepted = true;
                            applySeek(m);
                        }
                        onPositionChanged: function(m) {
                            if (pressed) applySeek(m);
                        }
                    }
                }

                // Tempo Total
                Text {
                    text: mediaWidget.formatTime(mediaWidget.activePlayer ? mediaWidget.activePlayer.length : 0)
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 10
                    color: Theme.muted
                    Layout.preferredWidth: 35
                }
            }
        }

        // 4. CONTROLES DE REPRODUÇÃO
        RowLayout {
            width: parent.width
            Layout.alignment: Qt.AlignHCenter

            Item { Layout.fillWidth: true }

            // Retroceder 10s
            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: rwdMouse.containsMouse ? Theme.overlay : "transparent"
                opacity: (mediaWidget.activePlayer && mediaWidget.activePlayer.canSeek) ? 1.0 : 0.4

                Text {
                    anchors.centerIn: parent
                    text: "󰁍"
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 14
                    color: Theme.text
                }
                MouseArea {
                    id: rwdMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(m) {
                        m.accepted = true;
                        if (mediaWidget.activePlayer && mediaWidget.activePlayer.canSeek) {
                            mediaWidget.activePlayer.seek(-10);
                        }
                    }
                }
            }

            // Faixa Anterior
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: prevMouse.containsMouse ? Theme.overlay : "transparent"
                opacity: (mediaWidget.activePlayer && mediaWidget.activePlayer.canGoPrevious) ? 1.0 : 0.4

                Text {
                    anchors.centerIn: parent
                    text: "󰒮"
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 16
                    color: Theme.text
                }
                MouseArea {
                    id: prevMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(m) {
                        m.accepted = true;
                        if (mediaWidget.activePlayer && mediaWidget.activePlayer.canGoPrevious) {
                            mediaWidget.activePlayer.previous();
                        }
                    }
                }
            }

            // Play / Pause Principal
            Rectangle {
                id: playPauseBtn
                width: 38
                height: 38
                radius: 19
                color: playMouse.containsMouse ? Theme.accentAlt : Theme.accent
                opacity: mediaWidget.activePlayer ? 1.0 : 0.5

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }

                Text {
                    anchors.centerIn: parent
                    text: (mediaWidget.activePlayer && mediaWidget.activePlayer.isPlaying) ? "󰏤" : "󰐊"
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 18
                    color: Theme.base
                }

                MouseArea {
                    id: playMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(m) {
                        m.accepted = true;
                        if (mediaWidget.activePlayer) {
                            mediaWidget.activePlayer.togglePlaying();
                        }
                    }
                }
            }

            // Próxima Faixa
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: nextMouse.containsMouse ? Theme.overlay : "transparent"
                opacity: (mediaWidget.activePlayer && mediaWidget.activePlayer.canGoNext) ? 1.0 : 0.4

                Text {
                    anchors.centerIn: parent
                    text: "󰒭"
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 16
                    color: Theme.text
                }
                MouseArea {
                    id: nextMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(m) {
                        m.accepted = true;
                        if (mediaWidget.activePlayer && mediaWidget.activePlayer.canGoNext) {
                            mediaWidget.activePlayer.next();
                        }
                    }
                }
            }

            // Avançar 10s
            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: fwdMouse.containsMouse ? Theme.overlay : "transparent"
                opacity: (mediaWidget.activePlayer && mediaWidget.activePlayer.canSeek) ? 1.0 : 0.4

                Text {
                    anchors.centerIn: parent
                    text: "󰁎"
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 14
                    color: Theme.text
                }
                MouseArea {
                    id: fwdMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(m) {
                        m.accepted = true;
                        if (mediaWidget.activePlayer && mediaWidget.activePlayer.canSeek) {
                            mediaWidget.activePlayer.seek(10);
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }

        // 5. CONTROLE DE VOLUME DO PLAYER (OPCIONAL)
        RowLayout {
            width: parent.width
            spacing: 8
            visible: mediaWidget.showVolumeControl && mediaWidget.activePlayer !== null && mediaWidget.activePlayer.volumeSupported

            Text {
                text: (mediaWidget.activePlayer && mediaWidget.activePlayer.volume > 0) ? "󰕾" : "󰝟"
                font.family: "Hack Nerd Font"
                font.pixelSize: 12
                color: Theme.muted
            }

            Rectangle {
                id: volTrack
                Layout.fillWidth: true
                height: 4
                radius: 2
                color: Theme.overlay

                readonly property real volVal: mediaWidget.activePlayer ? mediaWidget.activePlayer.volume : 0

                Rectangle {
                    width: parent.width * volTrack.volVal
                    height: parent.height
                    radius: 2
                    color: Theme.blue
                }

                WheelHandler {
                    onWheel: function(e) {
                        if (!mediaWidget.activePlayer) return;
                        const delta = e.angleDelta.y > 0 ? 0.05 : -0.05;
                        mediaWidget.activePlayer.volume = Math.max(0.0, Math.min(1.0, mediaWidget.activePlayer.volume + delta));
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    function applyVol(m) {
                        if (!mediaWidget.activePlayer) return;
                        const pos = mapToItem(volTrack, m.x, 0).x;
                        const v = Math.max(0.0, Math.min(1.0, pos / volTrack.width));
                        mediaWidget.activePlayer.volume = v;
                    }
                    onPressed: function(m) {
                        m.accepted = true;
                        applyVol(m);
                    }
                    onPositionChanged: function(m) {
                        if (pressed) applyVol(m);
                    }
                }
            }

            Text {
                text: Math.round((mediaWidget.activePlayer ? mediaWidget.activePlayer.volume : 0) * 100) + "%"
                font.family: "Hack Nerd Font"
                font.pixelSize: 10
                color: Theme.muted
                Layout.preferredWidth: 30
                horizontalAlignment: Text.AlignRight
            }
        }
    }

    // ── LAYOUT COMPACTO ───────────────────────────────────────────────────────
    Column {
        id: compactCol
        visible: mediaWidget.compact
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10
        spacing: 8

        RowLayout {
            width: parent.width
            spacing: 8

            Text {
                text: mediaWidget.getPlayerIcon(mediaWidget.activePlayer ? mediaWidget.activePlayer.identity : "")
                font.family: "Hack Nerd Font"
                font.pixelSize: 14
                color: Theme.accent
            }

            Text {
                Layout.fillWidth: true
                text: mediaWidget.hasActiveMedia ? (mediaWidget.activePlayer.trackTitle + " - " + mediaWidget.activePlayer.trackArtist) : "Nenhuma mídia"
                font.family: "Hack Nerd Font"
                font.pixelSize: 12
                font.weight: Font.Bold
                color: Theme.text
                elide: Text.ElideRight
            }

            Rectangle {
                width: 24
                height: 24
                radius: 12
                color: prevCompMouse.containsMouse ? Theme.overlay : "transparent"
                opacity: (mediaWidget.activePlayer && mediaWidget.activePlayer.canGoPrevious) ? 1.0 : 0.4
                Text {
                    anchors.centerIn: parent
                    text: "󰒮"
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 13
                    color: Theme.text
                }
                MouseArea {
                    id: prevCompMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(m) {
                        m.accepted = true;
                        if (mediaWidget.activePlayer && mediaWidget.activePlayer.canGoPrevious) mediaWidget.activePlayer.previous();
                    }
                }
            }

            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: Theme.accent
                Text {
                    anchors.centerIn: parent
                    text: (mediaWidget.activePlayer && mediaWidget.activePlayer.isPlaying) ? "󰏤" : "󰐊"
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 14
                    color: Theme.base
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(m) {
                        m.accepted = true;
                        if (mediaWidget.activePlayer) mediaWidget.activePlayer.togglePlaying();
                    }
                }
            }

            Rectangle {
                width: 24
                height: 24
                radius: 12
                color: nextCompMouse.containsMouse ? Theme.overlay : "transparent"
                opacity: (mediaWidget.activePlayer && mediaWidget.activePlayer.canGoNext) ? 1.0 : 0.4
                Text {
                    anchors.centerIn: parent
                    text: "󰒭"
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 13
                    color: Theme.text
                }
                MouseArea {
                    id: nextCompMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(m) {
                        m.accepted = true;
                        if (mediaWidget.activePlayer && mediaWidget.activePlayer.canGoNext) mediaWidget.activePlayer.next();
                    }
                }
            }
        }
    }
}
