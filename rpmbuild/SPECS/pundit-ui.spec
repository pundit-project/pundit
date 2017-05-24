%define puhome /opt/pundit-ui


Name:		pundit-ui
Summary:	PuNDIT Web User Interface
Url:		http://pundit.gatech.edu/
Version:	1.0
Release:	1
License:	Apache License 2.0
Group:		Productivity/Networking/Other
Source:		%{name}.tar.gz
BuildArch:	noarch
#Prereq:		%pwdutils_prereq
Requires:	glassfish >= 4.1.1
#Provides:	pundit-ui = %{version}
BuildRoot:	%{_tmppath}/%{name}-%{version}-build


%description
PuNDIT Web User Interface provides a user interface for the PuNDIT
project.


%prep
%setup -q -n pundit-ui


%build
# Nothing to do


%install
%__install -d -m 755 %{buildroot}%{puhome}
%__cp -pr . %{buildroot}%{puhome}
#%__chmod -Rf go-rwx %{buildroot}%{domaindir}/config
#%__mv %{buildroot}%{domaindir}/docroot %{buildroot}%{gfvar}
#%__mv %{buildroot}%{domaindir}/autodeploy %{buildroot}%{gfvar}
#%__ln_s -f %{gfvar}/docroot %{buildroot}%{domaindir}
#%__ln_s -f %{gfvar}/autodeploy %{buildroot}%{domaindir}


%clean
rm -rf %{buildroot}


%pre


%post


%preun


%postun


%files
%defattr(-,%{gfuser},%{gfgroup})
%{puhome}
