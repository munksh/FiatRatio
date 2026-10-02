#!/usr/bin/env python3
"""Standard buckets, categories and glossary terms, with their translations.
Writes qml/data/standard.json, which the app reads at start. The database keeps
only a category's key (plus a name, when the user renamed it), so a phone in
another language shows these names in that language.

Columns: en sv de ru fr. en and sv are kept by the author. de and ru are open
to the community. fr is drafted but not shipped: add "fr" to SHIPPED (and a
translations/harbour-fiatratio-fr.ts) when someone looks after it.

    python3 tools/make_standard.py"""
import json, os

SHIPPED = ["en", "sv", "de", "ru"]
COLUMNS = ["en", "sv", "de", "ru", "fr"]
MAINTAINED = {"en": "author", "sv": "author", "de": "community", "ru": "community"}

B = {  # buckets
 "needs": ["Needs", "Behov", "Bedarf", "Необходимое", "Besoins"],
 "wants": ["Wants", "Önskemål", "Wünsche", "Желания", "Envies"],
 "savings": ["Savings", "Sparande", "Sparen", "Сбережения", "Épargne"],
 "technical": ["Technical", "Tekniskt", "Technisches", "Технические", "Technique"],
 "exceptional": ["Exceptional", "Oförutsett", "Außergewöhnlich", "Непредвиденное", "Exceptionnel"],
}
# key, kind, parent, bucket, then names in COLUMNS order
C = [
 ("food", "expense", None, "needs", "Food", "Mat", "Essen", "Еда", "Alimentation"),
 ("groceries", "expense", "food", "needs", "Groceries", "Livsmedel", "Lebensmittel", "Продукты", "Courses"),
 ("restaurant", "expense", "food", "wants", "Restaurants", "Restaurang", "Restaurant", "Рестораны", "Restaurants"),
 ("fika", "expense", "food", "wants", "Coffee and fika", "Fika", "Kaffee und Kuchen", "Кофе и перекусы", "Cafés"),
 ("snacks", "expense", "food", "wants", "Snacks and fast food", "Snacks och snabbmat", "Snacks und Fast Food", "Снеки и фастфуд", "Grignotage et fast-food"),
 ("alcohol", "expense", "food", "wants", "Alcohol", "Alkohol", "Alkohol", "Алкоголь", "Alcool"),
 ("home", "expense", None, "needs", "Home", "Boende", "Wohnen", "Жильё", "Logement"),
 ("rent", "expense", "home", "needs", "Rent", "Hyra", "Miete", "Аренда", "Loyer"),
 ("housing", "expense", "home", "needs", "Housing costs", "Boendekostnader", "Wohnnebenkosten", "Коммунальные расходы", "Charges du logement"),
 ("mortgage_interest", "expense", "home", "needs", "Mortgage interest", "Ränta på bolån", "Hypothekenzinsen", "Проценты по ипотеке", "Intérêts du prêt immobilier"),
 ("household", "expense", "home", "needs", "Household", "Hushåll", "Haushalt", "Хозяйство", "Ménage"),
 ("maintenance", "expense", "home", "needs", "Maintenance", "Underhåll", "Instandhaltung", "Обслуживание", "Entretien"),
 ("repairs", "expense", "home", "needs", "Repairs", "Reparationer", "Reparaturen", "Ремонт", "Réparations"),
 ("renovation", "expense", "home", "wants", "Renovation", "Renovering", "Renovierung", "Обновление жилья", "Rénovation"),
 ("garden", "expense", "home", "wants", "Garden", "Trädgård", "Garten", "Сад", "Jardin"),
 ("transport", "expense", None, "needs", "Transport", "Transport", "Verkehr", "Транспорт", "Transport"),
 ("transport_public", "expense", "transport", "needs", "Public transport", "Kollektivtrafik", "Öffentlicher Verkehr", "Общественный транспорт", "Transports en commun"),
 ("transport_car", "expense", "transport", "needs", "Car", "Bil", "Auto", "Автомобиль", "Voiture"),
 ("fuel", "expense", "transport", "needs", "Fuel", "Drivmedel", "Kraftstoff", "Топливо", "Carburant"),
 ("parking", "expense", "transport", "needs", "Parking", "Parkering", "Parken", "Парковка", "Stationnement"),
 ("taxi", "expense", "transport", "wants", "Taxi", "Taxi", "Taxi", "Такси", "Taxi"),
 ("transport_fees", "expense", "transport", "needs", "Tolls and fees", "Avgifter och tullar", "Gebühren und Maut", "Сборы и пошлины", "Péages et frais"),
 ("travel", "expense", None, "wants", "Travel", "Resor", "Reisen", "Путешествия", "Voyages"),
 ("travel_flights", "expense", "travel", "wants", "Flights", "Flyg", "Flüge", "Авиабилеты", "Vols"),
 ("travel_train", "expense", "travel", "wants", "Train", "Tåg", "Bahn", "Поезд", "Train"),
 ("travel_bus", "expense", "travel", "wants", "Bus", "Buss", "Bus", "Автобус", "Bus"),
 ("travel_boat", "expense", "travel", "wants", "Boat", "Båt", "Schiff", "Паром", "Bateau"),
 ("travel_hotel", "expense", "travel", "wants", "Accommodation", "Boende på resa", "Unterkunft", "Проживание", "Hébergement"),
 ("travel_fees", "expense", "travel", "wants", "Travel fees", "Reseavgifter", "Reisegebühren", "Сборы в поездке", "Frais de voyage"),
 ("health", "expense", None, "needs", "Health", "Hälsa", "Gesundheit", "Здоровье", "Santé"),
 ("health_medical", "expense", "health", "needs", "Healthcare and medicine", "Vård och medicin", "Arzt und Medizin", "Медицина", "Soins et médicaments"),
 ("hygiene", "expense", "health", "needs", "Hygiene", "Hygien", "Hygiene", "Гигиена", "Hygiène"),
 ("sports", "expense", "health", "needs", "Sports and fitness", "Sport och träning", "Sport und Fitness", "Спорт", "Sport"),
 ("leisure", "expense", None, "wants", "Leisure", "Fritid", "Freizeit", "Досуг", "Loisirs"),
 ("entertainment", "expense", "leisure", "wants", "Entertainment and streaming", "Nöje och streaming", "Unterhaltung und Streaming", "Развлечения и подписки", "Divertissement et streaming"),
 ("hobbies", "expense", "leisure", "wants", "Hobbies", "Hobbyer", "Hobbys", "Хобби", "Loisirs créatifs"),
 ("books", "expense", "leisure", "wants", "Books", "Böcker", "Bücher", "Книги", "Livres"),
 ("education", "expense", "leisure", "wants", "Education", "Utbildning", "Bildung", "Образование", "Formation"),
 ("gambling", "expense", "leisure", "wants", "Gambling", "Spel", "Glücksspiel", "Азартные игры", "Jeux d'argent"),
 ("social_club", "expense", "leisure", "wants", "Clubs and societies", "Föreningar", "Vereine", "Клубы и общества", "Associations"),
 ("shopping", "expense", None, "wants", "Shopping", "Shopping", "Einkäufe", "Покупки", "Achats"),
 ("clothes", "expense", "shopping", "wants", "Clothes", "Kläder", "Kleidung", "Одежда", "Vêtements"),
 ("computer_phone", "expense", "shopping", "needs", "Computer and phone", "Dator och telefon", "Computer und Telefon", "Компьютер и телефон", "Ordinateur et téléphone"),
 ("it", "expense", "shopping", "wants", "Software and services", "Programvara och tjänster", "Software und Dienste", "Программы и сервисы", "Logiciels et services"),
 ("tech", "expense", "shopping", "wants", "Electronics", "Elektronik", "Elektronik", "Электроника", "Électronique"),
 ("giving", "expense", None, "wants", "Giving", "Gåvor", "Schenken", "Подарки", "Dons"),
 ("gifts", "expense", "giving", "wants", "Gifts", "Presenter", "Geschenke", "Подарки", "Cadeaux"),
 ("charity", "expense", "giving", "wants", "Charity", "Välgörenhet", "Spenden", "Благотворительность", "Dons caritatifs"),
 ("finance", "expense", None, "technical", "Finance", "Ekonomi", "Finanzen", "Финансы", "Finances"),
 ("insurance", "expense", "finance", "needs", "Insurance", "Försäkring", "Versicherung", "Страхование", "Assurances"),
 ("bank_fees", "expense", "finance", "technical", "Bank fees", "Bankavgifter", "Bankgebühren", "Банковские комиссии", "Frais bancaires"),
 ("loan_interest", "expense", "finance", "technical", "Loan interest", "Låneränta", "Kreditzinsen", "Проценты по кредитам", "Intérêts d'emprunt"),
 ("fines", "expense", "finance", "exceptional", "Fines", "Böter", "Bußgelder", "Штрафы", "Amendes"),
 ("services", "expense", None, "needs", "Services", "Tjänster", "Dienstleistungen", "Услуги", "Services"),
 ("reimbursable", "expense", None, "needs", "To be reimbursed", "Utlägg", "Auslagen", "К возмещению", "À rembourser"),
 ("unidentified", "expense", None, "technical", "Unidentified", "Oidentifierat", "Unbekannt", "Неопознанное", "Non identifié"),
 ("salary", "income", None, None, "Salary", "Lön", "Gehalt", "Зарплата", "Salaire"),
 ("benefits", "income", None, None, "Benefits", "Ersättningar", "Leistungen", "Пособия", "Allocations"),
 ("side_income", "income", None, None, "Side income", "Extrainkomst", "Nebeneinkommen", "Подработка", "Revenus annexes"),
 ("music_income", "income", None, None, "Music income", "Musikintäkter", "Musikeinnahmen", "Доходы от музыки", "Revenus musicaux"),
 ("sold_items", "income", None, None, "Sold items", "Sålt", "Verkäufe", "Продажи вещей", "Ventes d'objets"),
 ("gifts_received", "income", None, None, "Gifts received", "Fått i gåva", "Geschenke erhalten", "Полученные подарки", "Cadeaux reçus"),
 ("interest_income", "income", None, None, "Interest", "Ränteintäkter", "Zinserträge", "Процентный доход", "Intérêts perçus"),
 ("dividends", "income", None, None, "Dividends", "Utdelning", "Dividenden", "Дивиденды", "Dividendes"),
 ("tax_refund", "income", None, None, "Tax refund", "Skatteåterbäring", "Steuererstattung", "Возврат налога", "Remboursement d'impôt"),
 ("vat_refund", "income", None, None, "VAT refund", "Momsåterbetalning", "Umsatzsteuererstattung", "Возврат НДС", "Remboursement de TVA"),
 ("cashback", "income", None, None, "Cashback and refunds", "Återbetalningar", "Rückerstattungen", "Кэшбэк и возвраты", "Remboursements"),
 ("shared_repaid", "income", None, None, "Shared costs paid back", "Delade kostnader tillbaka", "Geteilte Kosten zurück", "Возврат общих расходов", "Frais partagés remboursés"),
 ("other_income", "income", None, None, "Other income", "Övriga intäkter", "Sonstige Einnahmen", "Прочие доходы", "Autres revenus"),
 ("cash_withdrawal", "neutral", None, None, "Cash withdrawal", "Kontantuttag", "Bargeldabhebung", "Снятие наличных", "Retrait d'espèces"),
 ("correction", "neutral", None, None, "Correction", "Korrigering", "Korrektur", "Корректировка", "Correction"),
]
TERMS = {
 "amortisation": [
   "Amortisation: paying down the loan itself, not the interest.",
   "Amortering: att betala av själva lånet, inte räntan.",
   "Tilgung: die Rückzahlung des Kredits selbst, nicht der Zinsen.",
   "Погашение основного долга: выплата самого кредита, а не процентов.",
   "Amortissement : le remboursement du capital, pas des intérêts.",
 ],
 "interest": [
   "Interest: what borrowing costs. It does not make the loan smaller.",
   "Ränta: vad det kostar att låna. Lånet blir inte mindre av den.",
   "Zinsen: was das Leihen kostet. Der Kredit wird dadurch nicht kleiner.",
   "Проценты: цена кредита. Долг от них не уменьшается.",
   "Intérêts : le coût de l'emprunt. Ils ne réduisent pas la dette.",
 ],
 "net_worth": [
   "Net worth: everything you own minus everything you owe, your part only.",
   "Nettoförmögenhet: allt du äger minus allt du är skyldig, bara din del.",
   "Nettovermögen: alles, was du besitzt, minus alles, was du schuldest – nur dein Anteil.",
   "Чистый капитал: всё, чем вы владеете, минус все долги, только ваша доля.",
   "Patrimoine net : tout ce que vous possédez moins vos dettes, votre part seulement.",
 ],
 "transfer": [
   "Transfer: money moved between your own places. Not spending, not income.",
   "Överföring: pengar flyttade mellan dina egna ställen. Varken utgift eller inkomst.",
   "Umbuchung: Geld zwischen deinen eigenen Konten. Weder Ausgabe noch Einnahme.",
   "Перевод: деньги между вашими же счетами. Не расход и не доход.",
   "Virement : de l'argent entre vos propres comptes. Ni dépense ni revenu.",
 ],
 "my_share": [
   "Your part: what is yours of something shared. The whole is shown beside it.",
   "Din del: det som är ditt av något ni delar. Helheten visas bredvid.",
   "Dein Anteil: was dir von etwas Geteiltem gehört. Das Ganze steht daneben.",
   "Ваша доля: ваша часть общего. Полная сумма показана рядом.",
   "Votre part : ce qui vous revient d'un bien partagé. Le total figure à côté.",
 ],
 "planned": [
   "Planned: expected but not paid yet. It already counts against what is left.",
   "Planerad: väntad men inte betald. Den räknas redan bort från det som är kvar.",
   "Geplant: erwartet, aber noch nicht bezahlt. Zählt schon gegen den Rest.",
   "Запланировано: ожидается, но ещё не оплачено. Уже вычтено из остатка.",
   "Prévu : attendu mais pas encore payé. Déjà déduit de ce qui reste.",
 ],
}


def pick(values):
    return {l: v for l, v in zip(COLUMNS, values) if l in SHIPPED}


def main():
    out = {"languages": SHIPPED,
           "maintained": {l: MAINTAINED.get(l, "community") for l in SHIPPED},
           "buckets": {k: pick(v) for k, v in B.items()},
           "categories": {c[0]: {"kind": c[1], "parent": c[2], "bucket": c[3], **pick(c[4:])} for c in C},
           "terms": {k: pick(v) for k, v in TERMS.items()}}
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "qml", "data", "standard.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    print(len(out["categories"]), "categories,", len(out["buckets"]), "buckets,", len(out["terms"]), "terms")


if __name__ == "__main__":
    main()
