# Note: the following macros should in principle be imported by the
# requiste packages

%define pchome  /opt/pundit-central
%define pcuser	root
%define pcgroup	root

Name:		pundit-central
Summary:	PuNDIT Central Server
Url:		http://pundit.gatech.edu/
Version:	1.0
Release:	1
License:	Apache License 2.0
Group:		Productivity/Networking/Other
Source:		%{name}.tar.gz
BuildArch:	noarch
Requires:       perl-Net-AMQP-RabbitMQ >= 2.30000
Requires:	python >= 2.6
Requires:	mysql >= 5.1
Requires:	mysql-server >= 5.1
Requires:	mysql-connector-python >= 1.1.6
Requires:	rabbitmq-server >= 3.6
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
%__install -d -m 755 %{buildroot}/etc/cron.d
%__cp -pr . %{buildroot}%{pchome}
%__mv -f %{buildroot}%{pchome}/etc/process-pundit-data.cron %{buildroot}/etc/cron.d

%clean
rm -rf %{buildroot}


%pre


%post


%preun


%postun


%files
%defattr(-,%{pcuser},%{pcgroup})
%{pchome}
/etc/cron.d
