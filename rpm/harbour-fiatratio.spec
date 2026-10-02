Name:       harbour-fiatratio
Summary:    Fiat Ratio – money from one salary to the next
Version:    0.9
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
%license %{_datadir}/licenses/%{name}/LICENSE
