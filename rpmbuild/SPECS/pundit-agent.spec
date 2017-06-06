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
%__install -d -m 755 %{buildroot}/etc/init.d
%__install -d -m 755 %{buildroot}/etc/cron.d
%__install -d -m 755 %{buildroot}/etc/cron.hourly
%__cp -pr . %{buildroot}%{pahome}
%__mv -f %{buildroot}%{pahome}/system/etc/cron.d/pundit-localization-daemon %{buildroot}/etc/cron.d
%__mv -f %{buildroot}%{pahome}/system/etc/cron.hourly/pundit-cleanowamp %{buildroot}/etc/cron.hourly
%__mv -f %{buildroot}%{pahome}/system/etc/init.d/pundit-agent %{buildroot}/etc/init.d



%clean
rm -rf %{buildroot}


%pre


%post
case "$1" in
  1) # This is an initial install.
	chmod 0755 /etc/init.d/pundit-agent 
	chmod +x /opt/pundit-agent/bin/pundit_daemon.pl
	chkconfig --add pundit-agent
	
  ;;
  2)
	chmod +x /opt/pundit-agent/bin/pundit_daemon.pl
	chkconfig --del pundit-agent
    	chkconfig --add pundit-agent
  ;;
esac

%preun
	service pundit_agent stop
	chkconfig --del pundit-agent

%postun


%files
%defattr(-,%{pauser},%{pagroup})
%{pahome}
/etc/cron.d/pundit-localization-daemon
/etc/cron.hourly/pundit-cleanowamp
/etc/init.d/pundit-agent
