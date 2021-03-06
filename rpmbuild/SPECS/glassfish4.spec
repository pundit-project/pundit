%define gfuser glassfish
%define gfgroup %{gfuser}
%define name glassfish4
%define gfhome /opt/glassfish4
%define gfvar /var/opt/glassfish4
%define domaindir %{gfhome}/glassfish/domains/domain1

# Stop jar repacking
%define __jar_repack %{nil}

%if 0%{?suse_version}
%define with_fillup 1
%else
%define with_fillup 0
%endif

%if 0%{?centos_version}
%define pwdutils_prereq shadow-utils
%else
#%define pwdutils_prereq pwdutils
%endif

%if 0%{?centos_version} && 0%{?centos_version} < 600
%define _initddir %{_sysconfdir}/rc.d/init.d
%define have_mysql 0
%else
%define have_mysql 1
%endif

# We are using the zip archives from Maven central as the java.net
# download locations have been deprecated. The manuals are not available
# through Maven central and therefore have been excluded

Name:		glassfish4
Summary:	JavaEE 7 application server
Url:		https://javaee.github.io/glassfish/
Version:	4.1.1
Release:	1
License:	CDDL-1.1 or GPL-2.0-with-classpath-exception
Group:		Productivity/Networking/Other
Source0:	http://repo1.maven.org/maven2/org/glassfish/main/distributions/glassfish/%{version}/glassfish-%{version}.zip
Source1:	%{name}.init
#GC: Removing optional configuration for DERBY
#Source2:	sysconfig.%{name}
BuildArch:	noarch
#Prereq:		%pwdutils_prereq
%if %{with_fillup}
Prereq:		%fillup_prereq
%endif
Requires:	java >= 1.8.0
Requires:	jre >= 1.8.0
Requires(post): /sbin/chkconfig, /sbin/service
Requires(preun): /sbin/chkconfig, /sbin/service

%if %{have_mysql}
BuildRequires:	mysql-connector-java
%endif
Provides:	glassfish = %{version}
BuildRoot:	%{_tmppath}/%{name}-%{version}-build

# Note:
# It might be better to integrate the stuff nicely into the system in
# /etc, /usr, and /var.  But this might require some tweaking as
# GlassFish assumes everything to be in one single directory by
# default.  Therefore I choose the simple way to put it into one
# directory in /opt.

%description
GlassFish Server Open Source Edition provides a server for the
development and deployment of Java Platform, Enterprise Edition (Java
EE platform) applications and web technologies based on Java
technology.


%if %{have_mysql}
%package mysql
Summary:	JavaEE 7 application server
License:	CDDL-1.1 and GPL-2.0-with-classpath-exception
Group:		Productivity/Networking/Other
Requires:	%{name} = %{version}
Requires:	mysql-connector-java

%description mysql
GlassFish Server Open Source Edition provides a server for the
development and deployment of Java Platform, Enterprise Edition (Java
EE platform) applications and web technologies based on Java
technology.

This package adds the link to the JDBC Driver for MySQL
%endif

# GC: Removing manual as the tarball from maven central does not have it
#%package doc
#Summary:	JavaEE 7 application server
#License:	CDDL-1.1 and GPL-2.0-with-classpath-exception
#Group:		Productivity/Networking/Other
#Requires:	%{name} = %{version}
#
#%description doc
#GlassFish Server Open Source Edition provides a server for the
#development and deployment of Java Platform, Enterprise Edition (Java
#EE platform) applications and web technologies based on Java
#technology.
#
#This package contains the documentation for GlassFish.


%prep
%setup -q -c %{name}/%{version}


%build
# Nothing to do


%install
%__install -d -m 755 %{buildroot}/opt
%__install -d -m 755 %{buildroot}%{_initddir}
%__install -d -m 755 %{buildroot}%{_sbindir}
%__install -d -m 755 %{buildroot}%{gfvar}
%__cp -pr glassfish4 %{buildroot}/opt
%__chmod -Rf go-rwx %{buildroot}%{domaindir}/config
# Since RPMS should not replace files, we change the index.html to 
# index.htm. The default search path for glassfish will use index.htm
# as a fallback if index.html is not found. Therefore another rpm
# can override the default index file simply by adding index.html
%__mv %{buildroot}%{domaindir}/docroot/index.html %{buildroot}%{domaindir}/docroot/index.htm
%__mv %{buildroot}%{domaindir}/docroot %{buildroot}%{gfvar}
%__mv %{buildroot}%{domaindir}/autodeploy %{buildroot}%{gfvar}
%__ln_s -f %{gfvar}/docroot %{buildroot}%{domaindir}
%__ln_s -f %{gfvar}/autodeploy %{buildroot}%{domaindir}
#GC: Remove manual
#%__install -d -m 755 %{buildroot}%{gfhome}/doc
#%__cp -pr manual %{buildroot}%{gfhome}/doc
%if %{have_mysql}
%__ln_s %{_javadir}/mysql-connector-java.jar %{buildroot}%{domaindir}/lib
%endif
%__install -m 755 %SOURCE1 %{buildroot}%{_initddir}/%{name}
%__ln_s %{_initddir}/%{name} %{buildroot}%{_sbindir}/rc%{name}
#GC: Removing optional configuration for DERBY
#%if %{with_fillup}
#%__install -d -m 755 %{buildroot}%{_localstatedir}/adm/fillup-templates
#%__install -m 0644 %SOURCE2 %{buildroot}%{_localstatedir}/adm/fillup-templates
#%else
#%__install -d -m 755 %{buildroot}%{_sysconfdir}/sysconfig
#%__install -m 0644 %SOURCE2 %{buildroot}%{_sysconfdir}/sysconfig/%{name}
#%endif


%clean
rm -rf %{buildroot}


%pre
/usr/bin/getent group %{gfgroup} >/dev/null || \
	/usr/sbin/groupadd -r %{gfgroup}
/usr/bin/getent passwd %{gfuser} >/dev/null || \
	/usr/sbin/useradd -r -g %{gfgroup} -d %{gfhome} -s /sbin/nologin \
	-c "GlassFish JavaEE application server" %{gfuser}


%post
# Start and add service
/sbin/service %{name} start &>/dev/null
/sbin/chkconfig --add %{name}

# Open ports used by glassfish
iptables -I INPUT 1 -p tcp --dport 8080 -j ACCEPT
/sbin/service iptables save


%preun
# Close ports used by glassfish
iptables -D INPUT -p tcp --dport 8080 -j ACCEPT
/sbin/service iptables save

# Stop and remove service
/sbin/service %{name} stop &>/dev/null
/sbin/chkconfig --del %{name}


%postun
# Remove all leftover files (logs, caches, ...)
rm -rf %{gfhome}
rm -rf %{gfvar}

%files
%defattr(-,%{gfuser},%{gfgroup})
%{gfvar}
%{gfhome}
#GC: remove manual
#%docdir %{gfhome}/doc
#%exclude %{gfhome}/doc/manual
%if %{have_mysql}
%exclude %{domaindir}/lib/mysql-connector-java.jar
%endif
%attr(-,root,root) %{_initddir}/%{name}
%attr(-,root,root) %{_sbindir}/rc%{name}
#GC: removign optional configuration for DERBY
#%if %{with_fillup}
#%attr(-,root,root) %{_localstatedir}/adm/fillup-templates/*
#%else
#%attr(-,root,root) %config %{_sysconfdir}/sysconfig/%{name}
#%endif


%if %{have_mysql}
%files mysql
%defattr(-,%{gfuser},%{gfgroup})
%{domaindir}/lib/mysql-connector-java.jar
%endif


#GC: Remove manual
#%files doc
#%defattr(-,%{gfuser},%{gfgroup})
#%doc %{gfhome}/doc/manual


%changelog
* Tue May 23 2017 carcassi@umich.edu
- Using zip from maven central and removing manual
* Mon Feb 15 2016 carcassi@umich.edu
- Upgrade to version 4.1.1
- Using init script from glassfish4 and removing DERBY config
* Thu Aug 08 2013 rolf@rotkraut.de
- Upgrade to version 4.0
- Rename package to glassfish4, it may be installed next to glassfish 3
* Thu Mar 21 2013 rolf@rotkraut.de
- Initial package (3.1.2.2)
