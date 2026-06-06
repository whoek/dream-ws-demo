# dream-ws-demo
Ocaml Dream - webservice demo from Grok


## Pre-requisites and Run

`opam install dream`

`opam exec ./server.exe`


Open http://localhost:8080 in multiple browser tabs — you’ll see the server message appear.


## How it works


Client tracking — A global Hashtbl stores active Dream.websocket connections (simple and sufficient for most cases).

Broadcast — broadcast sends the same message to every connected client using Lwt_list.iter_p for concurrency.

Periodic timer — start_periodic_broadcast uses Lwt_unix.sleep to send a message every 60 seconds.

Error handling — The broadcast ignores failures (dead sockets) so one bad connection doesn't break the loop.
