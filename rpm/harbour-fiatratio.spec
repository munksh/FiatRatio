Name:       harbour-fiatratio
Summary:    fiat ratio – money from one salary to the next
Version:    1.1
Release:    1
License:    MIT
URL:        https://github.com/munksh/FiatRatio
Source0:    %{name}-%{version}.tar.bz2
Requires:   sailfishsilica-qt5 >= 0.10.9
BuildRequires:  pkgconfig(sailfishapp) >= 1.0.2
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  pkgconfig(Qt5Sql)
BuildRequires:  qt5-qttools-linguist
BuildRequires:  desktop-file-utils

%description
A budget month that starts when the salary comes. Shared costs entered at
the full price, with only your part counted. What comes back is planned
into the months ahead. Savings, a home and loans in one net worth, and
everything in one open file you can take anywhere.

%if 0%{?_chum}
Title: fiat ratio
Type: desktop-application
DeveloperName: Munkstolen
Categories:
 - Office
 - Utility
AIRating: V
AINote: Claude is my typist - I cross review with Mistral, and add the code once it looks good. Architecture, design, on-device testing, releases and maintenance by me; issues and input welcome.
PackageIcon: https://munkstolen.se/SFOS/harbour-fiatratio.png
Screenshots:
 - https://munkstolen.se/SFOS/fiatratio1.png
 - https://munkstolen.se/SFOS/fiatratio2.png
 - https://munkstolen.se/SFOS/fiatratio3.png
 - https://munkstolen.se/SFOS/fiatratio4.png
 - https://munkstolen.se/SFOS/fiatratio5.png
 - https://munkstolen.se/SFOS/fiatratio6.png
 - https://munkstolen.se/SFOS/fiatratio7.png
Custom:
  Repo: https://github.com/munksh/FiatRatio
Links:
  Homepage: https://github.com/munksh/FiatRatio
  Bugtracker: https://github.com/munksh/FiatRatio/issues
%endif

%prep
%setup -q -n %{name}-%{version}

%build
%qmake5 APP_VERSION=%{version}
make %{?_smp_mflags}

%install
rm -rf %{buildroot}
make install INSTALL_ROOT=%{buildroot}

desktop-file-install --delete-original \
  --dir %{buildroot}%{_datadir}/applications \
   %{buildroot}%{_datadir}/applications/*.desktop

%files
%defattr(-,root,root,-)
%{_bindir}/%{name}
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/*/apps/%{name}.png

%changelog
* Mon Oct 05 2026 Caesar Prometheus Ivarsson <caesar@munkstolen.se> - 1.1-1
- The About page lists the whole fiat family with full-size icons, and the
  package carries metadata for SailfishOS:Chum: title, icon and screenshots.

