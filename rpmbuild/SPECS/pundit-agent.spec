%define pahome  /opt/pundit-agent
%define pauser  root
%define pagroup  root

Name:		pundit-agent
Summary:	PuNDIT Agent
Url:		http://pundit.gatech.edu/
Version:	1.0
Release:	1
License:	Apache License 2.0
Group:		Productivity/Networking/Other
Source:		%{name}.tar.gz
BuildArch:	noarch
Requires:       perl-Net-AMQP-RabbitMQ >= 2.30000
Provides:	pundit-agent = %{version}
BuildRoot:	%{_tmppath}/%{name}-%{version}-build


%description
PuNDIT Agent gathers data from perfSONAR, does the first pass in processing and sends to the central server.

%prep
%setup -q -n pundit-agent


%build
# Nothing to do


%install
%__install -d -m 755 %{buildroot}%{pahome}
%__cp -pr . %{buildroot}%{pahome}


%clean
rm -rf %{buildroot}


%pre


%post


%preun


%postun


%files
%defattr(-,%{pauser},%{pagroup})
%{pahome}
