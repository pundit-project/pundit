# Note: the following macros should in principle be imported by the
# requiste packages
%define gfvar   /var/opt/glassfish4
%define gfdocroot   /var/opt/glassfish4/docroot
%define gfautodeploy   /var/opt/glassfish4/autodeploy
%define gfhome  /opt/glassfish4

%define puhome  /opt/pundit-ui

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
%__install -d -m 755 %{buildroot}%{gfhome}
%__install -d -m 755 %{buildroot}%{gfdocroot}
%__install -d -m 755 %{buildroot}%{gfautodeploy}
%__cp -pr . %{buildroot}%{puhome}
%__ln_s -f web-ui/* %{buildroot}%{gfdocroot}
%__ln_s -f diirt/conf %{buildroot}%{gfhome}/.diirt
%__ln_s -f diirt/web-pods.jar %{buildroot}%{gfautodeploy}
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
%{gfhome}/.diirt
%{gfdocroot}/*
%{gfautodeploy}/web-pods.jar
