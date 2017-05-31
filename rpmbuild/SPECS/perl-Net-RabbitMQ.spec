%define perl_vendorarch %(eval "`%{__perl} -V:installvendorarch`"; echo $installvendorarch)
%define _unpackaged_files_terminate_build 0

%define real_name Net-RabbitMQ

Name:		perl-Net-RabbitMQ
Version:	0.2.8
Release:	1%{?dist}
Summary:	Perl module for message queuing with RabbitMQ

Group:		Applications/CPAN
License:	Artistic/GPL
URL:		http://search.cpan.org/dist/Net-RabbitMQ/
Source0:	/root/rpmbuild/SOURCES/%{real_name}-%{version}.tar.gz

BuildRequires:	librabbitmq >= 0.5.2
BuildRequires:  perl(DynaLoader)
BuildRequires:  perl(Scalar::Util)
BuildRequires:  perl >= 5.10
Requires: librabbitmq >= 0.5.2
Requires: perl(DynaLoader)
Requires: perl(Scalar::Util)
Requires: perl >= 5.10

%description
Perl module to support RabbitMQ

%prep
%setup -n %{real_name}-%{version}

%build
echo "y" | perl Makefile.PL INSTALLDIRS="vendor" --nolive
make %{?_smp_mflags}

%install
make install DESTDIR=%{buildroot}

%files
%defattr(-, root, root, 0755)
%dir
%{perl_vendorarch}/Net/RabbitMQ.pm
%{perl_vendorarch}/auto/Net/RabbitMQ/RabbitMQ.so

%doc
%{_mandir}/man3/Net::RabbitMQ.3pm*

%changelog
* Fri Dec 04 2015 Jorge Batista <batistaj@umich.edu> - 0.2.8
- Initial package.
  . Obtained Net--RabbitMQ-0.2.8.tar.gz package from CPAN link (above)
    Note unusual use of '--' in naming.
  . Untarred the package to make some corrections and rename.
  . Removed all ._* files (MAC OSX leftovers from original authors)
  . Re-tarred the files as Net-RabbitMQ-0.2.8.tar.gz
  . Placed the tar file under ~/rpmbuild/SOURCES
  . Built this spec file
