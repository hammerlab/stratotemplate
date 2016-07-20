
#use "topfind";;
#thread;;
#require "stratocumulus";;

open Nonstd
open Stratocumulus.Deploy
let (//) = Filename.concat

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

let gcloud_zone = env_exn "GCLOUD_ZONE"

let authorize_keys =
  let i = open_in @@ env_exn "SSH_CONFIG_DIR" // "kserver.pub" in
  let rec read_all acc =
    try read_all (input_line i :: acc)
    with _ -> acc in
  List.filter_map (read_all []) ~f:(function
    | "" -> None
    | more -> Some (`Inline more))

let nfs_mounts =
  env_exn "CLUSTER_NFS_MOUNTS"
  |> String.split ~on:(`Character ':')
  |> List.map ~f:(fun csv ->
      String.split ~on:(`Character ',') csv
      |> begin function
      | vm :: remote_path :: witness :: mount_point :: [] ->
        let server = Node.make vm ~zone:gcloud_zone in
        Nfs.Mount.make ~server ~remote_path ~witness ~mount_point
      | other ->
        ksprintf failwith "Wrong format for CLUSTER_NFS_MOUNTS: %S" csv
      end)


let configuration =
  Configuration.make ~gcloud_host ()

let deployment =
  (* let one_nfs_mount =
    let server = Node.make (name "nfs-nfsservervm") in
    Nfs.Mount.make
      ~server
      ~remote_path:("/nfs-pool")
      ~witness:"./.stratowitness"
      ~mount_point:"/nfswork"
  in *)
  let compute_node name =
    Node.make name
      ~zone:gcloud_zone
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
        ~nfs_mounts
        ~torque_server:(compute_node (name "pbs-server"))
        ~users:[
          User.make ~unix_uid:20420 (sprintf "%s-user" prefix);
        ]
        ~authorize_keys
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
