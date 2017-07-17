PuNDIT
======


PuNDIT will integrate and enhance several software tools needed by the High Energy Physics (HEP) community to provide an infrastructure for identifying, diagnosing and localizing network problems. In particular, the core of PuNDIT is the Pythia tool that uses perfSONAR data to detect, identify and locate network performance problems. The Pythia algorithms, originally based on one-way latency and packet loss, will be re-implemented incorporating the lessons learned from its first release and augmenting those algorithms with additional metrics from perfSONAR throughput and traceroute measurements.  The PuNDIT infrastructure will build upon other popular open-source tools including smokeping, ESnet's Monitoring and Debugging Dashboard (MaDDash) and the Open Monitoring Distribution (OMD) to provide a user-friendly network diagnosis framework.


#### Funding ####

    PuNDIT is funded by National Science Foundation award numbers 1440571 and 1440585

#### Project Duration ####

    September 2014 - August 2016

#### Principal Investigators ####

    Shawn McKee, University of Michigan (smckeeumich.edu)
    Constantine Dovrolis, Georgia Tech (dovroliscc.gatech.edu)

##### pundit-central installation #####

Add PuNDIT yum repository.

     wget -O /etc/yum.repos.d/pundit.repo http://pundit.aglt2.org/pundit.repo


Install server component. Note that this will also install glassfish and mysql. 

     yum install pundit-central pundit-ui

Run the pundit-central initialization script. **It will prompt you for the mysql root password.**  By default, the password is blank. The script will create database and RabbitMQ users and update the configuration files. It will also start mysql and rabbitmq-server if they are not already running, and it will make sure mysql chkconfig is on.

     /opt/pundit-central/bin/initialize-pundit-central.sh

##### Prepare agent initialization properties #####

After initializing pundit-central, you will have a file that looks like this:

    > cat /opt/pundit-central/etc/pundit-agent.credentials
    agent-user=pundit-agent
    agent-password=<randomly-generated-password>
    central-hostname=<your-host.site.org>

You will need to add the list of all nodes on which you will install the agent. This will instruct the agent installation which network paths to look at

    agent-peers=<your-node.site.org>,<other-node.othersite.com>,<next-node.nextsite.edu>

##### pundit-agent installation #####

Add PuNDIT yum repository.

     wget -O /etc/yum.repos.d/pundit.repo http://pundit.aglt2.org/pundit.repo

Install pundit-agent on the perfsonar nodes.

	yum install pundit-agent

Copy the pundit agent file with the initialization properties and run the pundit-central initialization script. For conventience, the location can be a local file or a URL.

	/opt/pundit-agent/bin/initialize-pundit-agent.sh <location-of-pundit-agent.credentials>

The script can be run again in case you want to update the configuration.

#### Build ####

After cloning the repository, run the master build script:

     ./build.sh

Make sure you have the required dependencies installed as they are documented inside the script itself. The result of the build are a series of rpms that are places in rpmbuild/RPMS. There is also a clean.sh script that deletes all intermediate step and a release.sh that can be used within the aglt2 network to deploy the rpms into the PuNDIT yum repository
