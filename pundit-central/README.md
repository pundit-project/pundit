Pundit Central Service
=================

This is **non-production** code for the PuNDIT project.

This code is meant to be deployed on the central server.

It consists of:

 - The pundit_central daemon 
   - This daemon operates on the detected events written to the central database by the PuNDIT agents. It produces possible faulty links and ranges for metrics for delays, losses and reordering.
   
Dependencies

 - Config::General 
   - This is available on CPAN 