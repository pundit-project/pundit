#!/bin/bash

# Make sure we are in the correct directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

spectool -g -C SOURCES SPECS/perl-Net-AMQP-RabbitMq.spec
rpmbuild --define "_topdir `pwd`" -ba SPECS/perl-Net-AMQP-RabbitMq.spec
rpmbuild --define "_topdir `pwd`" -ba SPECS/pundit-agent.spec
rpmbuild --define "_topdir `pwd`" -ba SPECS/pundit-central.spec
spectool -g -C SOURCES SPECS/glassfish4.spec
rpmbuild --define "_topdir `pwd`" -ba SPECS/glassfish4.spec
rpmbuild --define "_topdir `pwd`" -ba SPECS/pundit-ui.spec
