
Fenris - a big scarry wolf

Usage:

fenris help -- this help
fenris info -- info about your fenris account
fenris rekey -- rekey the account - two keys active at once
fenris add CONSUMER -- add a consumer to the allowed lists
fenris remove CONSUMER -- remove a consumer from the allowed lists
fenris provide BINDING -- provide a resource -- TCP socket or unix socket
fenris consume [ PROVIDER [ BINDING ] ] -- consume all providers on default bindings (or one on a specified binding)
fenris bind PROVIDER BINDING - set a default binding for a provider
fenris exec COMMAND -- runs consume logic while executing a shell command

Admin Usage:
fenris useradd NAME -- add a new user
fenris userdel NAME -- delete a user
fenris users -- get a list of all users

Bindings:
  1234, :1234, 0.0.0.0:1234
    are all the same - a tcp binding
  foo, ./foo, /tmp/foo
    all represent unix sockets
  --
    specifies stdin/stdout
