import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"
import "../js/format.js" as F

Page {
    id: page

    property int accountId: 0
    readonly property var acc: { store.revision; return store.account(accountId) }
    readonly property var moves: { store.revision; return store.accountTransactions(accountId, 30) }
    readonly property bool shared: Number(acc.my_share) > 0 && Number(acc.my_share) < 1

    function paint() { FiatRatioTheme.applyPalette(page) }
    Component.onCompleted: paint()
    Connections { target: FiatRatioTheme; onAmbientChanged: page.paint() }

    Kinds { id: kinds }
    RemorsePopup { id: remorse }

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
            spacing: Theme.paddingSmall

            PageHead {
                title: page.acc.name || ""
                subtitle: kinds.label(page.acc.kind)
            }
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: F.money(page.acc.value || 0, page.acc.currency)
                color: Number(page.acc.value) < 0 ? FiatRatioTheme.wrong : FiatRatioTheme.accent
                font.pixelSize: Theme.fontSizeHuge
                font.family: FiatRatioTheme.serif
            }
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: text !== ""
                text: {
                    var parts = []
                    if (page.shared) parts.push(qsTr("your %1 of %2").arg(F.percent(page.acc.my_share)).arg(F.money(page.acc.whole, page.acc.currency)))
                    if (page.acc.shared_with) parts.push(qsTr("with %1").arg(page.acc.shared_with))
                    if (page.acc.rate) parts.push(qsTr("%1 % interest").arg(Number(page.acc.rate).toLocaleString(Qt.locale(appLanguage), "f", 2)))
                    if (page.acc.value_date) parts.push(qsTr("value from %1").arg(F.dayMonthYear(appLanguage, page.acc.value_date)))
                    return parts.join(" · ")
                }
                color: FiatRatioTheme.secondaryText
                font.pixelSize: Theme.fontSizeExtraSmall
            }
            Item { width: 1; height: Theme.paddingMedium }

            LinkText {
                x: Theme.horizontalPageMargin - Theme.paddingSmall
                visible: kinds.valued(page.acc.kind)
                text: qsTr("a new value")
                onClicked: pageStack.push(Qt.resolvedUrl("ValueDialog.qml"), {
                    "accountId": page.accountId, "accountName": page.acc.name,
                    "share": page.acc.my_share, "currency": page.acc.currency })
            }
            LinkText {
                x: Theme.horizontalPageMargin - Theme.paddingSmall
                visible: kinds.debt(page.acc.kind)
                text: qsTr("the interest changed")
                onClicked: {
                    var d = pageStack.push(Qt.resolvedUrl("TextDialog.qml"),
                                           { "title": qsTr("interest"), "label": qsTr("Interest, % a year"), "numeric": true })
                    d.accepted.connect(function() { store.addRate(page.accountId, Number(String(d.value).replace(",", "."))) })
                }
            }
            LinkText {
                x: Theme.horizontalPageMargin - Theme.paddingSmall
                visible: !kinds.valued(page.acc.kind)
                text: kinds.debt(page.acc.kind) ? qsTr("pay something off") : qsTr("move money here")
                onClicked: pageStack.push(Qt.resolvedUrl("AddDialog.qml"), { "presetToAccountId": page.accountId })
            }
            LinkText {
                x: Theme.horizontalPageMargin - Theme.paddingSmall
                visible: !kinds.valued(page.acc.kind) && page.acc.kind !== "person"
                text: qsTr("correct the balance")
                onClicked: pageStack.push(Qt.resolvedUrl("BalanceDialog.qml"), {
                    "accountId": page.accountId, "accountName": page.acc.name,
                    "share": page.acc.my_share, "currency": page.acc.currency,
                    "current": Number(page.acc.value), "debt": kinds.debt(page.acc.kind) })
            }
            LinkText {
                x: Theme.horizontalPageMargin - Theme.paddingSmall
                text: qsTr("close it")
                color: FiatRatioTheme.secondaryText
                onClicked: remorse.execute(qsTr("Closing"), function() {
                    store.closeAccount(page.accountId)
                    pageStack.pop()
                })
            }

            SectionLabel {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                horizontalAlignment: Text.AlignRight
                height: implicitHeight + Theme.paddingLarge
                verticalAlignment: Text.AlignBottom
                visible: page.moves.length > 0
                text: qsTr("Moves")
            }
            Repeater {
                model: page.moves
                TxnRow {
                    item: ({ "date": modelData.date, "amount": modelData.amount,
                             "description": modelData.origin === "correction" ? qsTr("balance correction") : modelData.description,
                             "status": modelData.status, "other": modelData.other, "other_kind": modelData.other_kind,
                             "isMove": String(modelData.other || "") !== "" })
                }
            }
        }
        VerticalScrollDecorator { }
    }
}
