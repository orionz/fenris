
Fenris - a big scarry wolf

$ export FENRIS_URL='http://user@0.0.0.0:4567/'
$ fenris serve 5432
$ fenris connect DIR

Client:
  if its an integer - bind to a port
  else use a path
  if its a -- channel bind stdin

Broker:
  generate a new user automatically?

Server:
  handle tcp port AND unix sockets

PHASE 2: crypto

2) create short lived client certs validated by server
3) create short lived server certs validated by client

PHASE 3: roll credentials

#1 roll my credentials
#2 roll my users credentials
#3 roll my private key

