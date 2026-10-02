import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"
import "../js/format.js" as F

// What you have and what you owe, always your part, the whole beside it.
Page {
    id: page

    property string periodId: ""
    property bool coachHidden: false
    readonly property string currency: { store.revision; return store.setting("base_currency", "SEK") }
    readonly property var accountList: { store.revision; return store.accounts() }
    readonly property var worth: { store.revision; return store.netWorth() }
    readonly property var series: { store.revision; return store.netWorthSeries(60) }

    function paint() { FiatRatioTheme.applyPalette(page) }
    Component.onCompleted: paint()
    Connections { target: FiatRatioTheme; onAmbientChanged: page.paint() }

    function inGroup(kindsList) {
        var out = []
        for (var i = 0; i < accountList.length; ++i)
            if (kindsList.indexOf(accountList[i].kind) >= 0) out.push(accountList[i])
        return out
    }

    Kinds { id: kinds }

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

        PullDownMenu {
            highlightColor: FiatRatioTheme.chromeAccent
            // Nearest the thumb.
            MenuItem {
                text: qsTr("Add")
                color: FiatRatioTheme.primaryText
                onClicked: pageStack.push(Qt.resolvedUrl("AssetKindPage.qml"))
            }
        }

        Column {
            id: content
            width: parent.width

            PageHead {
                title: qsTr("net worth")
                subtitle: qsTr("your part")
            }

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: F.money(page.worth.net || 0, page.currency)
                color: (page.worth.net || 0) < 0 ? FiatRatioTheme.wrong : FiatRatioTheme.accent
                font.pixelSize: Theme.fontSizeHuge
                font.family: FiatRatioTheme.serif
            }
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("net worth")
                color: FiatRatioTheme.secondaryText
                font.pixelSize: Theme.fontSizeSmall
            }
            Item { width: 1; height: Theme.paddingMedium }
            LineChart {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                points: page.series
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                horizontalAlignment: Text.AlignRight
                text: qsTr("five years")
                color: FiatRatioTheme.secondaryText
                font.pixelSize: Theme.fontSizeTiny
            }
            MoneyRow { label: qsTr("Assets"); value: F.money(page.worth.assets || 0, page.currency) }
            MoneyRow { label: qsTr("Debts"); value: F.money(-(page.worth.debts || 0), page.currency) }

            Repeater {
                model: kinds.groups
                Column {
                    width: content.width
                    readonly property var members: page.inGroup(modelData.kinds)
                    visible: members.length > 0
                    SectionLabel {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        horizontalAlignment: Text.AlignRight
                height: implicitHeight + Theme.paddingLarge
                verticalAlignment: Text.AlignBottom
                        text: modelData.title
                    }
                    Repeater {
                        model: parent.members
                        BackgroundItem {
                            id: item
                            width: content.width
                            height: Math.max(Theme.itemSizeMedium, info.height + 2 * Theme.paddingSmall)
                            highlightedColor: FiatRatioTheme.highlightWash
                            readonly property bool shared: Number(modelData.my_share) > 0 && Number(modelData.my_share) < 1
                            onClicked: pageStack.push(Qt.resolvedUrl("AccountPage.qml"), { "accountId": modelData.id })
                            Column {
                                id: info
                                anchors {
                                    left: parent.left; leftMargin: Theme.horizontalPageMargin
                                    right: valueLabel.left; rightMargin: Theme.paddingMedium
                                    verticalCenter: parent.verticalCenter
                                }
                                Label {
                                    width: parent.width
                                    text: modelData.name
                                    truncationMode: TruncationMode.Fade
                                    color: item.highlighted ? FiatRatioTheme.accent : FiatRatioTheme.primaryText
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                                Label {
                                    width: parent.width
                                    truncationMode: TruncationMode.Fade
                                    color: FiatRatioTheme.secondaryText
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                    text: {
                                        var parts = [kinds.label(modelData.kind)]
                                        if (item.shared) parts.push(qsTr("%1 of %2").arg(F.percent(modelData.my_share)).arg(F.plain(modelData.whole)))
                                        if (modelData.shared_with) parts.push(qsTr("with %1").arg(modelData.shared_with))
                                        if (modelData.rate) parts.push(qsTr("%1 % interest").arg(Number(modelData.rate).toLocaleString(Qt.locale(appLanguage), "f", 2)))
                                        return parts.join(" · ")
                                    }
                                }
                            }
                            Label {
                                id: valueLabel
                                anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
                                text: F.money(modelData.value, modelData.currency)
                                color: Number(modelData.value) < 0 ? FiatRatioTheme.wrong : FiatRatioTheme.primaryText
                                opacity: Number(modelData.in_net_worth) === 1 ? 1.0 : 0.5
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }
                    }
                }
            }
            Item { width: 1; height: Theme.paddingLarge }
            EmptyNote {
                visible: page.accountList.length === 0
                text: qsTr("Nothing yet. Savings, a home, a loan, money lent to a friend.")
            }
            Item { width: 1; height: Theme.paddingLarge }
            CoachMark {
                visible: store.demo && store.coachStep === 4 && !page.coachHidden
                text: visible ? qsTr("Your half of the home counts, with the total beside it. Add a loan with Add: the app asks where the money went and plans the payments.") : ""
                nextText: qsTr("got it")
                onNext: page.coachHidden = true
                onEnd: page.coachHidden = true
            }
        }
        VerticalScrollDecorator { }
    }
}
