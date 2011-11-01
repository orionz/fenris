Fenris - a VPN for cloud services
=================================

This tool is designed for allow for secure service discovery, authentication,
and communication between any TCP services.  Modern TCP services frequently
have many different ways of implemented autnetication with different levels or
quality.  This service is an attempt to unify these with a single simple
autentication layer.

Sample Workflow
---------------

In an example workflow you would first want to create two subaccounts.  One to
be a service provider and one to be a service consumer.  Assume for this my
master account is named 'demo'.  At any point you can type

    fenris info

to see what user you are logged in as.  And what other users you are connected
to.

    fenris useradd consumer
      New user created 'demo-customer'

    fenris useradd provider
      New user created 'demo-provider'

Specify a user with either the -u command line switch or the FENRIS_USER
environment variable.

Next assume I want to provide access to a memcache daemon running on port 11211
to the consumer.

    fenris -u demo-provider add demo-consumer

This gives 'demo-consumer' access to my service.  I can revoke his ability to
use the service later with

    fenris -u demo-provider remove demo-consumer

To provide access with a fenris daemon simple do

    fenris -u demo-provider provide 127.0.0.1:11211

Note that by default fenris will attempt to provide access to other fenris
nodes by listening on your HOSTNAME:10001. If you need a different port or if
hostname does not match a resolvable IP you can use --host and --port switches
to specify another bind point.

    fenris -u demo-provider --host 0.0.0.0 --port 8888 provide 127.0.0.1:11211

Now as the consumer...

To securly mount the provided memcache on local port 9999 you can type

    fenris -u demo-consumer consume demo-provider 127.0.0.1:9999

Or if you bind it to a default port which is useful for consuming multiple
providers at once.

    fenris -u demo-consumer bind demo-provider 127.0.0.1:9999
    fenris -u demo-consumer consume

Setup
-----

    gem install fenris

One important dependancy of fenris is eventmachine compiled with TLS support.
Without this it will not be able to manage a proxy.  You will have a fenris
username and authtoken.  Simple set the environment variable

    export FENRIS_USER="myuser"

And you will be prompted for the authtoken the first time you run the command.

How it Works
------------

  ![How it works](raw/master/images/fenris.jpg)


