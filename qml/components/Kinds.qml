import QtQuick 2.0

// What a place for money is called, and which heading it stands under.
QtObject {
    readonly property var groups: [
        { "key": "saved", "title": qsTr("Savings"), "kinds": ["savings", "investment", "pension", "crypto", "deposit"] },
        { "key": "owned", "title": qsTr("Things"), "kinds": ["property", "vehicle", "possessions"] },
        { "key": "debt", "title": qsTr("Loans"), "kinds": ["loan", "mortgage", "credit"] },
        { "key": "people", "title": qsTr("Between people"), "kinds": ["person"] }
    ]
    function label(kind) {
        switch (kind) {
        case "pot": return qsTr("the month's money")
        case "savings": return qsTr("savings")
        case "investment": return qsTr("investments")
        case "pension": return qsTr("pension")
        case "crypto": return qsTr("crypto")
        case "deposit": return qsTr("deposit")
        case "property": return qsTr("home")
        case "vehicle": return qsTr("vehicle")
        case "possessions": return qsTr("belongings")
        case "loan": return qsTr("loan")
        case "mortgage": return qsTr("mortgage")
        case "credit": return qsTr("credit")
        case "person": return qsTr("between people")
        }
        return kind || ""
    }
    function valued(kind) {
        return ["investment", "pension", "crypto", "property", "vehicle", "possessions"].indexOf(kind) >= 0
    }
    function debt(kind) {
        return ["loan", "mortgage", "credit"].indexOf(kind) >= 0
    }
}
