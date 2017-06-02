# Note: the following macros should in principle be imported by the
# requiste packages
%define gfvar   /var/opt/glassfish4
%define gfdocroot   /var/opt/glassfish4/docroot
%define gfautodeploy   /var/opt/glassfish4/autodeploy
%define gfhome  /opt/glassfish4
%define gfuser glassfish
%define gfgroup %{gfuser}

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
Requires:	glassfish4-mysql >= 4.1.1
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
# Unfortunately, glassfish does not seem to follow symlinks
# therefore we move the web ui directly in docroot
%__mv -f web-ui/* %{buildroot}%{gfdocroot}
%__ln_s -f %{puhome}/diirt/conf %{buildroot}%{gfhome}/.diirt
%__ln_s -f %{puhome}/diirt/web-pods.war %{buildroot}%{gfautodeploy}


%clean
rm -rf %{buildroot}


%pre
# Stops glassfish while installing
service glassfish4 stop


%post
# Restart glassfish
service glassfish4 start


%preun
# Stops glassfish while uninstalling
service glassfish4 stop


%postun
# Restart glassfish
service glassfish4 start


%files
%defattr(-,%{gfuser},%{gfgroup})
%{puhome}
%{gfhome}/.diirt
%{gfdocroot}/*
%{gfautodeploy}/web-pods.war
%exclude %{puhome}/web-ui
