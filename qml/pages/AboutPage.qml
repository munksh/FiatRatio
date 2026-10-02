import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"

Page {
    id: page

    function paint() { FiatRatioTheme.applyPalette(page) }
    Component.onCompleted: paint()

    Rectangle {
        anchors.fill: parent
        visible: !FiatRatioTheme.ambient
        gradient: Gradient {
            GradientStop { position: 0.0; color: FiatRatioTheme.backgroundHigh }
            GradientStop { position: 1.0; color: FiatRatioTheme.backgroundLow }
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: content.height + Theme.paddingLarge

        Column {
            id: content
            width: parent.width
            spacing: Theme.paddingMedium

            PageHead {
                title: qsTr("about")
                subtitle: "fiat ratio"
            }

            Label {
                x: Theme.horizontalPageMargin
                width: content.width - Theme.horizontalPageMargin * 2
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeMedium
                font.family: FiatRatioTheme.serif
                color: FiatRatioTheme.primaryText
                text: qsTr("The salary came on Friday. The rent goes on the 25th. The electricity cost more than last month.")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: content.width - Theme.horizontalPageMargin * 2
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: FiatRatioTheme.secondaryText
                text: qsTr("fiat ratio keeps the month from one salary to the next: what came in, what went out, and what is still to come. Shared costs are entered at the full price and only your part counts. Savings, a home and loans add up to one net worth.")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: content.width - Theme.horizontalPageMargin * 2
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: FiatRatioTheme.secondaryText
                text: qsTr("Everything goes out to one open file and comes back in from it: to a new phone, to another program, or out of the app altogether.")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: content.width - Theme.horizontalPageMargin * 2
                wrapMode: Text.WordWrap
                textFormat: Text.StyledText
                font.pixelSize: Theme.fontSizeExtraSmall
                color: FiatRatioTheme.secondaryText
                text: qsTr("<b>fiat</b> — Latin, <i>let there be</i>. From <i>fiat lux</i> in the Vulgate: let there be light, and there was light. The first app took the phrase. The rest of the family kept the verb.")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: content.width - Theme.horizontalPageMargin * 2
                wrapMode: Text.WordWrap
                textFormat: Text.StyledText
                font.pixelSize: Theme.fontSizeExtraSmall
                color: FiatRatioTheme.secondaryText
                text: qsTr("<b>ratio</b> — reckoning, account; also reason. The Romans kept their accounts in the same word they used for thinking clearly.")
            }

            Item { width: 1; height: Theme.paddingLarge }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.itemSizeSmall
                height: 1
                color: FiatRatioTheme.innerBorder
            }
            Item { width: 1; height: Theme.paddingMedium }

            Column {
                x: Theme.horizontalPageMargin
                width: content.width - Theme.horizontalPageMargin * 2
                spacing: Theme.paddingSmall

                Label {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: FiatRatioTheme.serif
                    font.italic: true
                    color: FiatRatioTheme.primaryText
                    text: "Magnum vectigal\nest parsimonia"
                }
                Label {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: FiatRatioTheme.secondaryText
                    text: qsTr("Thrift is a great income.")
                }
                Label {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: FiatRatioTheme.secondaryText
                    text: "Cicero, Paradoxa Stoicorum VI.49"
                }
            }

            Item { width: 1; height: Theme.paddingMedium }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.itemSizeSmall
                height: 1
                color: FiatRatioTheme.innerBorder
            }

            SectionLabel { x: Theme.horizontalPageMargin; text: qsTr("Your data") }

            Label {
                x: Theme.horizontalPageMargin
                width: content.width - Theme.horizontalPageMargin * 2
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: FiatRatioTheme.secondaryText
                text: qsTr("Everything is kept on the phone, in the app's own storage. Exports are saved to Documents/fiat-ratio. Nothing leaves the phone: no account, no bank connection, no network.")
            }
            Label {
                x: Theme.horizontalPageMargin
                width: content.width - Theme.horizontalPageMargin * 2
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: FiatRatioTheme.secondaryText
                text: qsTr("Permissions: Documents, to save exports, and Downloads, to read a file you bring in.")
            }

            SectionLabel { x: Theme.horizontalPageMargin; text: qsTr("Made by") }

            Label {
                x: Theme.horizontalPageMargin
                text: "Munkstolen"
                font.pixelSize: Theme.fontSizeMedium
                font.family: FiatRatioTheme.serif
                color: FiatRatioTheme.primaryText
            }
            Label {
                x: Theme.horizontalPageMargin
                text: "Caesar Prometheus Ivarsson"
                font.pixelSize: Theme.fontSizeExtraSmall
                color: FiatRatioTheme.secondaryText
            }

            BackgroundItem {
                width: content.width
                height: Theme.itemSizeMedium
                highlightedColor: FiatRatioTheme.highlightWash
                onClicked: Qt.openUrlExternally("https://munkstolen.se")
                Column {
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    Label {
                        text: "munkstolen.se"
                        color: FiatRatioTheme.primaryText
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    Label {
                        text: qsTr("Everything else I make")
                        color: FiatRatioTheme.secondaryText
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }
                }
            }

            BackgroundItem {
                width: content.width
                height: Theme.itemSizeMedium
                highlightedColor: FiatRatioTheme.highlightWash
                onClicked: Qt.openUrlExternally("https://github.com/munksh/FiatRatio")
                Column {
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    Label {
                        text: "github.com/munksh/FiatRatio"
                        color: FiatRatioTheme.primaryText
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    Label {
                        text: qsTr("Source and issues · MIT licence")
                        color: FiatRatioTheme.secondaryText
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }
                }
            }

            SectionLabel { x: Theme.horizontalPageMargin; text: qsTr("The fiat family") }

            Repeater {
                model: [
                    { name: "fiat agenda", what: qsTr("let there be doing — a task list"), icon: "images/family/harbour-fiatagenda.png", url: "https://openrepos.net/content/munkstolen/fiat-agenda-task-list" },
                    { name: "fiat margo", what: qsTr("let there be edge — keeps edges"), icon: "images/family/harbour-fiatmargo.png", url: "https://openrepos.net/content/munkstolen/fiat-margo-keeps-edges" },
                    { name: "fiat glossa", what: qsTr("let there be tongue — a translator"), icon: "images/family/harbour-fiatglossa.png", url: "https://openrepos.net/content/munkstolen/fiat-glossa-a-deepl-translator" },
                    { name: "fiat vox", what: qsTr("let there be voice — a chromatic tuner"), icon: "images/family/harbour-fiatvox.png", url: "https://openrepos.net/content/munkstolen/fiat-vox-chromatic-tuner" },
                    { name: "fiat pons", what: qsTr("let there be bridge — a native Qobuz client"), icon: "images/family/harbour-fiatpons.png", url: "https://openrepos.net/content/munkstolen/fiat-pons-native-qobuz-client" },
                    { name: "fiat lux", what: qsTr("let there be light — a light meter for film - Coming soon"), icon: "images/family/harbour-fiatlux.png", url: "" },
                    { name: "fiat cor", what: qsTr("let there be heart — a metronome"), icon: "images/family/harbour-fiatcor.png", url: "https://openrepos.net/content/munkstolen/fiat-cor-a-metronome" },
                    { name: "fiat passus", what: qsTr("let there be step — a step counter - Coming soon"), icon: "images/family/harbour-fiatpassus.png", url: "" },
                    { name: "fiat mos", what: qsTr("let there be habit — a habit tracker"), icon: "images/family/harbour-fiatmos.png", url: "https://openrepos.net/content/munkstolen/fiat-mos-habit-tracker" },
                    { name: "fiat imago", what: qsTr("let there be image — a photo editor - Coming soon"), icon: "images/family/harbour-fiatimago.png", url: "" },
                    { name: "fiat ratio", what: qsTr("let there be reckoning — this one"), icon: "images/family/harbour-fiatratio.png", url: "" }
                ]

                delegate: BackgroundItem {
                    width: content.width
                    height: Theme.itemSizeMedium
                    enabled: modelData.url !== ""
                    highlightedColor: FiatRatioTheme.highlightWash
                    onClicked: Qt.openUrlExternally(modelData.url)

                    Image {
                        id: familyIcon
                        x: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.itemSizeSmall
                        height: Theme.itemSizeSmall
                        sourceSize.width: Theme.itemSizeSmall
                        sourceSize.height: Theme.itemSizeSmall
                        fillMode: Image.PreserveAspectFit
                        source: modelData.icon
                    }
                    Column {
                        anchors.left: familyIcon.right
                        anchors.leftMargin: Theme.paddingLarge
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        Label {
                            width: parent.width
                            text: modelData.name
                            color: modelData.url !== "" ? FiatRatioTheme.accent : FiatRatioTheme.primaryText
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: FiatRatioTheme.serif
                        }
                        Label {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: modelData.what
                            color: FiatRatioTheme.secondaryText
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }
                    }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                text: qsTr("Version %1").arg(typeof appVersion !== "undefined" ? appVersion : qsTr("unknown"))
                color: FiatRatioTheme.secondaryText
                font.pixelSize: Theme.fontSizeExtraSmall
            }

            Item { width: 1; height: Theme.itemSizeExtraSmall }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.itemSizeSmall
                height: 1
                color: FiatRatioTheme.innerBorder
            }
            MunkstolenMark {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.itemSizeMedium
                frame: "ring"
                color: FiatRatioTheme.makerMark
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "munkstolen"
                color: FiatRatioTheme.makerMark
                font.pixelSize: Theme.fontSizeSmall
                font.family: FiatRatioTheme.serif
                font.italic: true
            }
        }

        VerticalScrollDecorator { }
    }
}
