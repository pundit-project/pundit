# Note: the following macros should in principle be imported by the
# requiste packages

%define pchome  /opt/pundit-central

Name:		pundit-central
Summary:	PuNDIT Central Server
Url:		http://pundit.gatech.edu/
Version:	1.0
Release:	1
License:	Apache License 2.0
Group:		Productivity/Networking/Other
Source:		%{name}.tar.gz
BuildArch:	noarch
Requires:       perl-Net-RabbitMQ >= 0.2.8
Requires:	python >= 2.6
Provides:	pundit-central = %{version}
BuildRoot:	%{_tmppath}/%{name}-%{version}-build


%description
PuNDIT Central Server provides the components that receives the data from the agents and performs the network analysis.

%prep
%setup -q -n pundit-central


%build
# Nothing to do


%install
%__install -d -m 755 %{buildroot}%{pchome}
%__cp -pr . %{buildroot}%{pchome}


%clean
rm -rf %{buildroot}


%pre


%post


%preun


%postun


%files
%defattr(-,%{gfuser},%{gfgroup})
%{pchome}
