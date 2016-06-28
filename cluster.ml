
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

(* The numer of compute nodes in the cluster.
   Note that the PBS server will be itself a compute node in the current setup
   which adds one compute node to that number.
*)
let nb_of_nodes = env_exn "CLUSTER_NODES" |> int_of_string

(* Here we use a prefix to all the names created below; it's just a practical
   choice; you can change all of that, see the `name` function just below. *)
let prefix = env_exn "PREFIX"
let name s = sprintf "%s-%s" prefix s

let configuration =
  Configuration.make ~gcloud_host ()

let deployment =
  let one_nfs_mount =
    let server = Node.make (name "nfs-server-vm") in
    Nfs.Mount.make
      ~server
      ~remote_path:("/" ^ name "storage")
      ~witness:"./.stratowitness"
      ~mount_point:"/nfswork"
  in
  let compute_node name =
    Node.make name
      ~java:`Oracle_7
      ~machine_type:(`Google_cloud `Highmem_8)
  in
  Deployment.make (name "one")
    ~configuration
    ~clusters:[
      Cluster.make (name "one-cluster")
        ~compute_nodes:(
          List.init nb_of_nodes (fun i ->
              compute_node (sprintf "%s-compute-%02d" prefix i)
            )
        )
        ~nfs_mounts:[one_nfs_mount]
        ~torque_server:(compute_node (name "pbs-server"))
        ~users:[
          User.make ~unix_uid:20420 (sprintf "%s-user" prefix);
        ]
    ]

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
