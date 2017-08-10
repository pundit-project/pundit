PuNDIT
======


PuNDIT will integrate and enhance several software tools needed by the High Energy Physics (HEP) community to provide an infrastructure for identifying, diagnosing and localizing network problems. In particular, the core of PuNDIT is the Pythia tool that uses perfSONAR data to detect, identify and locate network performance problems. The Pythia algorithms, originally based on one-way latency and packet loss, will be re-implemented incorporating the lessons learned from its first release and augmenting those algorithms with additional metrics from perfSONAR throughput and traceroute measurements.  The PuNDIT infrastructure will build upon other popular open-source tools including smokeping, ESnet's Monitoring and Debugging Dashboard (MaDDash) and the Open Monitoring Distribution (OMD) to provide a user-friendly network diagnosis framework.


### Funding ###

    PuNDIT is funded by National Science Foundation award numbers 1440571 and 1440585

### Project Duration ###

    September 2014 - August 2016

### Principal Investigators ###

    Shawn McKee, University of Michigan (smckeeumich.edu)
    Constantine Dovrolis, Georgia Tech (dovroliscc.gatech.edu)
    
## Installation ##
### pundit-central installation ###

##### 1. Add PuNDIT yum repository. 

     wget -O /etc/yum.repos.d/pundit.repo http://pundit.aglt2.org/pundit.repo

##### 2. Install server component. Note that this will also install glassfish and mysql.

     yum install pundit-central pundit-ui

##### 3. Run the pundit-central initialization script. #####

**It will prompt you for the mysql root password.**  By default, the password is blank. The script will create database and RabbitMQ users and update the configuration files. It will also start mysql and rabbitmq-server if they are not already running, and it will make sure mysql chkconfig is on.

     /opt/pundit-central/bin/initialize-pundit-central.sh

![A screenshot of central-ui initialization](http://i.imgur.com/Rw8BZqT.png)

Note that the default configuration of MySQL from your distribution may need to be modified. Please refer to the [MySQL configuration notes](https://github.com/pundit-project/pundit/wiki/MySQL-configuration-notes).

#### 4. Prepare agent initialization properties ####

After initializing pundit-central, you will have a file that looks like this:

    > cat /opt/pundit-central/etc/pundit-agent.credentials
    agent-user=pundit-agent
    agent-password=<randomly-generated-password>
    central-hostname=<your-host.site.org>

You will need to add the list of all nodes on which you will install the agent. This will instruct the agent installation which network paths to look at

    agent-peers=<your-node.site.org>,<other-node.othersite.com>,<next-node.nextsite.edu>

Here's an example:
![A screenshot of credentials example](http://i.imgur.com/9DdDfkW.png)

##### (Optional) you can also publish the credentials file on the pundit-central node #####

Copy pundit-agent.credentials (after filling in the details) to /var/opt/glassfish4/docroot/:

	cp /opt/pundit-central/etc/pundit-agent.credentials /var/opt/glassfish4/docroot/pundit-agent.credentials

Change the permission:

	chmod 644 /var/opt/glassfish4/docroot/pundit-agent.credentials
	

#### 5. Check out the installed ui (and pundit-agent.credentials if published on the same server) ####

The installed ui can be accessed at your_hostname:8080.

![A screenshot of ui running](http://i.imgur.com/ON6nrve.png?1)
	
![A screenshot of published credentials](http://i.imgur.com/Vyc4Z1U.png?1)


### pundit-agent installation ###

##### 1. Add PuNDIT yum repository. #####

     wget -O /etc/yum.repos.d/pundit.repo http://pundit.aglt2.org/pundit.repo

##### 2. Install pundit-agent on the perfsonar nodes. #####

	yum install pundit-agent


##### 3. Copy the pundit agent file with the initialization properties and run the pundit-central initialization script. For conventience, the location can be a local file or a URL. #####

	/opt/pundit-agent/bin/initialize-pundit-agent.sh <location-of-pundit-agent.credentials>

The script can be run again in case you want to update the configuration.

![A screenshot of agent init](http://i.imgur.com/N8i2XiE.png)


##### 4. Check the log to see if pundit-agent is running. #####

	tail -f /var/log/perfsonar/pundit-agent.log
	
![A screenshot of agent log](http://i.imgur.com/HOneinb.png)

![A screenshot of agent log](http://i.imgur.com/OLldcan.png)

##### 5. Check the pundit-ui*. #####

![A screenshot of agent log](http://i.imgur.com/qWE0gDG.png)

###### * pundit-ui uses the average delay for a given time window in constrast to perfsonar's built-in plotting tool that uses the minimum delay, and the delay graphs on pundit-ui might appear abnormally noisy. ######

### Build ###

After cloning the repository, run the master build script:

     ./build.sh

Make sure you have the required dependencies installed as they are documented inside the script itself. The result of the build are a series of rpms that are places in rpmbuild/RPMS. There is also a clean.sh script that deletes all intermediate step and a release.sh that can be used within the aglt2 network to deploy the rpms into the PuNDIT yum repository
