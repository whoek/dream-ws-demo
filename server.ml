(* server.,ml *)


(*

HOW IT WORKS

Client tracking — A global Hashtbl stores active Dream.websocket connections (simple and sufficient for most cases).

Broadcast — broadcast sends the same message to every connected client using Lwt_list.iter_p for concurrency.

Periodic timer — start_periodic_broadcast uses Lwt_unix.sleep to send a message every 60 seconds.

Error handling — The broadcast ignores failures (dead sockets) so one bad connection doesn't break the loop.



Open http://localhost:8080 in multiple browser tabs — you’ll see the server message appear every minute in all of them.You can easily extend this (e.g., use a Mutex + Hashtbl if you need stronger synchronization, add rooms/channels, etc.). Let me know if you want a version with JSON messages or more features!

*)



(* ==================== Global clients ==================== *)
let clients : (int, Dream.websocket) Hashtbl.t = Hashtbl.create 20

let next_id =
  let counter = ref 0 in
  fun () -> incr counter; !counter

let track ws =
  let id = next_id () in
  Hashtbl.add clients id ws;
  id

let forget id =
  Hashtbl.remove clients id

(* ==================== Broadcast ==================== *)
let broadcast msg =
  Hashtbl.to_seq_values clients
  |> List.of_seq
  |> Lwt_list.iter_p (fun ws ->
      Lwt.catch
        (fun () -> Dream.send ws msg)
        (fun _ -> Lwt.return_unit))

(* ==================== Periodic broadcast every minute ==================== *)
let start_periodic_broadcast () =
  let rec loop () =
    let%lwt () = Lwt_unix.sleep 60.0 in
    let t = Unix.gmtime (Unix.time ()) in
    let message = Printf.sprintf "🕒 Server broadcast at %02d:%02d:%02d UTC"
                    t.tm_hour t.tm_min t.tm_sec in
    let%lwt () = broadcast message in
    loop ()
  in
  loop ()

(* ==================== WebSocket handler ==================== *)
let websocket_handler _request =
  Dream.websocket (fun ws ->
    let id = track ws in
    let rec loop () =
      match%lwt Dream.receive ws with
      | Some _ -> loop ()
      | None ->
          forget id;
          Lwt.return_unit
    in
    loop ())

(* ==================== Manual Broadcast Route ==================== *)
let manual_broadcast request =
  match Dream.query request "msg" with
  | Some msg when msg <> "" ->
      let%lwt () = broadcast msg in
      Dream.html (Printf.sprintf "<h2>✅ Broadcast sent: <i>%s</i></h2>" msg)
  | _ ->
      Dream.html "<h2>❌ Missing 'msg' parameter</h2>"

(* ==================== Main ==================== *)
let () =
  Lwt.async start_periodic_broadcast;

  Dream.run
    ~port:8080
    @@ Dream.logger
    @@ Dream.router [
         (* Homepage *)
         Dream.get "/" (fun _ ->
           Dream.html {|
             <html><body>
               <h1>Dream WebSocket Broadcast Demo</h1>
               <p>Messages are sent to all clients every 60 seconds.</p>
               
               <h2>Manual Broadcast</h2>
               <form action="/broadcast" method="get">
                 <input type="text" name="msg" placeholder="Type message here" size="50">
                 <button type="submit">Send to all clients</button>
               </form>

               <script>
                 const ws = new WebSocket("ws://" + location.host + "/ws");
                 ws.onmessage = e => {
                   const div = document.createElement("div");
                   div.textContent = e.data;
                   document.body.appendChild(div);
                 };
               </script>
             </body></html>
           |});

         (* WebSocket endpoint *)
         Dream.get "/ws" websocket_handler;

         (* Manual broadcast endpoint *)
         Dream.get "/broadcast" manual_broadcast;
       ]
