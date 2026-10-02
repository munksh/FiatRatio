// What is left of the month, the one number worth a glance. The + adds a row.
import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../js/format.js" as F

CoverBackground {
    id: cover

    // ---- state ----
    readonly property string periodId: { store.revision; return store.setUp ? store.currentPeriod() : "" }
    readonly property var sum: { store.revision; return periodId !== "" ? store.summary(periodId) : ({}) }
    readonly property var info: { store.revision; return periodId !== "" ? store.periodInfo(periodId) : ({}) }

    // ---- paper ----
    Rectangle {
        anchors.fill: parent
        visible: !FiatRatioTheme.ambient
        gradient: Gradient {
            GradientStop { position: 0.0; color: FiatRatioTheme.backgroundHigh }
            GradientStop { position: 1.0; color: FiatRatioTheme.backgroundLow }
        }
    }

    // ---- wordmark ----
    Label {
        anchors.top: parent.top
        anchors.topMargin: FiatRatioTheme.coverWordmarkTop
        anchors.horizontalCenter: parent.horizontalCenter
        horizontalAlignment: Text.AlignHCenter
        text: "fiat ratio"
        color: FiatRatioTheme.secondaryText
        font.pixelSize: Theme.fontSizeTiny
        font.family: FiatRatioTheme.serif
        font.italic: true
    }

    // ---- figure ----
    Column {
        y: cover.height * FiatRatioTheme.coverFigureFraction
        x: FiatRatioTheme.coverSideMargin
        width: parent.width - 2 * FiatRatioTheme.coverSideMargin
        spacing: Theme.paddingSmall
        visible: cover.periodId !== ""

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: F.plain(cover.sum.left || 0)
            color: (cover.sum.left || 0) < 0 ? FiatRatioTheme.wrong : FiatRatioTheme.accent
            font.pixelSize: FiatRatioTheme.coverFigureSize
            font.family: FiatRatioTheme.serif
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: Theme.fontSizeLarge
        }
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            //: Cover, under what is left: "left · 12 days"
            text: qsTr("left · %1 days").arg(cover.info.daysLeft || 0)
            color: FiatRatioTheme.secondaryText
            font.pixelSize: Theme.fontSizeExtraSmall
        }
    }
    Label {
        y: cover.height * FiatRatioTheme.coverFigureFraction
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        visible: cover.periodId === ""
        text: qsTr("not set up")
        color: FiatRatioTheme.secondaryText
        font.pixelSize: Theme.fontSizeSmall
        font.family: FiatRatioTheme.serif
        font.italic: true
    }

    // ---- cover actions ----
    CoverActionList {
        enabled: store.setUp
        CoverAction {
            iconSource: "image://theme/icon-cover-new"
            onTriggered: store.requestAdd()
        }
    }
}
