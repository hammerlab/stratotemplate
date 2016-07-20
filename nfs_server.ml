
#use "topfind";;
#thread;;
#require "stratocumulus";;

open Nonstd
open Stratocumulus.Deploy

let env_exn s =
  try Sys.getenv s with _ ->
    ksprintf failwith "Missing environment variable %S" s


(* Set the host (in the Ketrew sense) that will run the `gcloud` commands,
   if you follow the instructions in the `README.md` file, this is your Google
   username and the name of your VM. *)
let gcloud_host = env_exn "GCLOUD_HOST"

(* Here we use a prefix to all the names created below; it's just a practical
   choice; you can change all of that, see the `name` function just below. *)
let prefix = env_exn "PREFIX"
let name s = sprintf "%s-%s" prefix s

let gcloud_zone = env_exn "GCLOUD_ZONE"

let storage_size = `GB (env_exn "SIZE_GB" |> int_of_string)

let configuration =
  Configuration.make ~gcloud_host ()

let deployment =
  let nfs =
    Nfs.Fresh.make (name "nfs") ~size:storage_size
      ~zone:gcloud_zone
      ~witness:(`Create "./.stratowitness")
  in
  Deployment.make (name "nfstrato")
    ~configuration
    ~nfs_deployments:[ nfs ]


let () =
  let cmds =
    Stratocumulus.Deploy.command_line deployment
      ~up_command:"up"
      ~down_command:"down"
      ~print_command:"display"
      ~status_command:"status"
      ~ketrew_config_command:"ketrew-configuration"
  in
  let open Cmdliner in
  let version = Stratocumulus.Metadata.version |> Lazy.force in
  let sub_command ~info ~term = (term, info) in
  let default_cmd =
    let doc = "Some workflows to setup google cloud clusters" in
    let man = [
      `S "AUTHORS";
      `P "Sebastien Mondet <seb@mondet.org>"; `Noblank;
      `S "BUGS";
      `P "Browse and report new issues at"; `Noblank;
      `P "<https://github.com/smondet/stratotemplate>.";
    ] in
    sub_command
      ~term:Term.(ret (pure (`Help (`Plain, None))))
      ~info:(Term.info Sys.argv.(0) ~version ~doc ~man) in
  match Term.eval_choice default_cmd cmds with
  | `Ok f -> f
  | `Error _ -> exit 1
  | `Version | `Help -> exit 0
