# fiat ratio — money, the Fiat way
TARGET = harbour-fiatratio

# Version: one source of truth, the spec. The spec passes it to qmake
# (%qmake5 APP_VERSION=%{version}); a plain qmake run in Qt Creator falls back.
isEmpty(APP_VERSION) {
    APP_VERSION = 0.0.0-dev
}
DEFINES += APP_VERSION=\\\"$$APP_VERSION\\\"

CONFIG += sailfishapp sailfishapp_i18n
QT += sql

SOURCES += \
    src/main.cpp \
    src/store.cpp \
    src/bundle.cpp

HEADERS += \
    src/store.h \
    src/bundle.h

# Files the build refuses to go without. The shared parts and the family icons
# come from Fiat Lux through tools/copy-family-parts.sh; without them the app is
# a white screen.
REQUIRED_FILES = \
    $${TARGET}.desktop \
    qml/$${TARGET}.qml \
    qml/qmldir \
    qml/FiatRatioTheme.qml \
    qml/js/format.js \
    qml/data/schema.sql \
    qml/data/standard.json \
    qml/components/PageHead.qml \
    qml/components/SectionLabel.qml \
    qml/components/MunkstolenMark.qml \
    qml/components/WordChoice.qml \
    qml/components/LinkText.qml \
    qml/components/FiatButton.qml \
    qml/pages/images/family/harbour-fiatratio.png \
    LICENSE
for(f, REQUIRED_FILES) {
    !exists($$PWD/$$f): error("Missing $$f -- expected it at $$PWD/$$f. Run tools/copy-family-parts.sh")
}

DISTFILES += \
    qml/harbour-fiatratio.qml \
    qml/FiatRatioTheme.qml \
    qml/qmldir \
    qml/cover/*.qml \
    qml/pages/*.qml \
    qml/components/*.qml \
    qml/js/*.js \
    qml/data/* \
    qml/pages/images/family/*.png \
    rpm/harbour-fiatratio.spec \
    harbour-fiatratio.desktop \
    README.md

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172

licensefile.files = $$PWD/LICENSE
licensefile.path = /usr/share/licenses/$${TARGET}
INSTALLS += licensefile

# sv and en are kept by the author in this repository. de and ru are open for
# the community (Weblate). harbour-fiatratio-en.ts exists so an English override
# can win over a phone set to another language.
TRANSLATIONS += \
    translations/harbour-fiatratio-en.ts \
    translations/harbour-fiatratio-sv.ts \
    translations/harbour-fiatratio-de.ts \
    translations/harbour-fiatratio-ru.ts
