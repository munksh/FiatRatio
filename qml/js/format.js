.pragma library

// Money is stored in minor units (öre, cents). Shown in whole units.
var symbols = { "SEK": "kr", "NOK": "kr", "DKK": "kr", "EUR": "€", "USD": "$", "GBP": "£", "RUB": "₽", "CHF": "CHF" }

function group(n) {
    var s = String(Math.abs(Math.round(n)))
    var out = ""
    while (s.length > 3) {
        out = "\u00A0" + s.slice(-3) + out
        s = s.slice(0, -3)
    }
    return s + out
}

function money(minor, currency) {
    var v = Number(minor || 0) / 100
    var sign = v < 0 ? "\u2212" : ""
    var sym = symbols[currency] || currency || ""
    if (sym === "$" || sym === "£")
        return sign + sym + group(v)
    return sign + group(v) + (sym ? "\u00A0" + sym : "")
}

function signed(minor, currency) {
    return (Number(minor) > 0 ? "+" : "") + money(minor, currency)
}

function plain(minor) {
    var v = Number(minor || 0) / 100
    return (v < 0 ? "\u2212" : "") + group(v)
}

// "1 234,50", "1234.5", "1 234" -> 123450. Returns 0 when it cannot read it.
function parse(text) {
    var s = String(text || "").replace(/[\s\u00A0\u202F]/g, "").replace(/\u2212/g, "-")
    if (s.indexOf(",") >= 0 && s.indexOf(".") >= 0)
        s = s.replace(/\./g, "")
    s = s.replace(",", ".")
    var v = parseFloat(s)
    return isNaN(v) ? 0 : Math.round(v * 100)
}

function forField(minor) {
    if (!minor)
        return ""
    var v = Number(minor) / 100
    return v % 1 === 0 ? String(v) : v.toFixed(2)
}

function isoDate(d) {
    function p(n) { return n < 10 ? "0" + n : String(n) }
    return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate())
}

function fromIso(s) {
    var parts = String(s).split("-")
    return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]))
}

function percent(share) {
    return Math.round(Number(share) * 100) + "\u00A0%"
}

// "Oktober" – some languages write month names in lower case; a title wants a capital.
function monthName(lang, month) {
    var s = Qt.locale(lang).standaloneMonthName(month - 1, 0)
    return s.charAt(0).toUpperCase() + s.slice(1)
}

// "2026-10" -> "Oktober 2026"
function monthTitle(lang, periodId) {
    if (!periodId || periodId.length < 7)
        return ""
    return monthName(lang, Number(periodId.substring(5, 7))) + " " + periodId.substring(0, 4)
}

// "8 okt"
function dayMonth(lang, isoDate) {
    if (!isoDate) return ""
    var d = fromIso(isoDate)
    var m = Qt.locale(lang).monthName(d.getMonth(), 1).replace(".", "")
    return d.getDate() + " " + m
}

// "8 okt 2027" when the year is not this one
function dayMonthYear(lang, isoDate) {
    if (!isoDate) return ""
    var d = fromIso(isoDate)
    var s = dayMonth(lang, isoDate)
    return d.getFullYear() === new Date().getFullYear() ? s : s + " " + d.getFullYear()
}

function shortMonth(lang, month) {
    return Qt.locale(lang).standaloneMonthName(month - 1, 1).replace(".", "")
}
