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

#### Installation ####

Add PuNDIT yum repository.

     wget -O /etc/yum.repos.d/pundit.repo http://pundit.aglt2.org/pundit.repo

Install server component. Note that this will also install glassfish and mysql. 

     yum install pundit-central pundit-ui

Make sure mysql is running. You will need the mysql root password. By default, the password is blank.

     service mysqld start

Run the database initialization script. **It will prompt you for the mysql root password.**  By default, the password is blank.

     /opt/pundit-central/bin/initialize_pundit_database.sh

#### Build ####

After cloning the repository, run the master build script:

     ./build.sh

Make sure you have the required dependencies installed as they are documented inside the script itself. The result of the build are a series of rpms that are places in rpmbuild/RPMS. There is also a clean.sh script that deletes all intermediate step and a release.sh that can be used within the aglt2 network to deploy the rpms into the PuNDIT yum repository
