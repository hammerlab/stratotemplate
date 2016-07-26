#use "topfind";;
#thread;;
#require "biokepi";;

open Nonstd
module String = Sosa.Native_string
let (//) = Filename.concat

let env_exn s =
  try Sys.getenv s with _ ->
    ksprintf failwith "Missing environment variable %S" s

let prefix = env_exn "PREFIX"
let name s = sprintf "%s-%s" prefix s

let user = name "user"
let host = name "pbs-server"

let work_dir =
  env_exn "BIOKEPI_WORK_DIR"

let install_tools_path =
  try env_exn "INSTALL_TOOLS_PATH"
  with _ -> work_dir // "toolkit"

let pyensembl_cache_dir =
  try env_exn "PYENSEMBLE_CACHE_DIR"
  with _ -> work_dir // "pyensembl-cache"

let reference_genomes_path =
  try env_exn "REFERENCE_GENOME_PATH"
  with _ -> work_dir // "reference-genome"


let ketrew_host =
  ksprintf Ketrew.EDSL.Host.parse
    "ssh://%s@%s/%s/ketrew-host-playground"
    user host work_dir

let gatk_jar_location = `Wget (env_exn "GATK_JAR_URL")
let mutect_jar_location = `Wget (env_exn "MUTECT_JAR_URL")


let biokepi_machine =
  let host = ketrew_host in
  let max_processors = 8 in
  let run_program ?name ?(requirements = []) p =
    let open Ketrew.EDSL in
    let how =
      (* For now we like to abuse a bit Demeter's login node: *)
      if List.mem ~set:requirements `Quick_run
      || List.mem ~set:requirements `Internet_access
      then `On_login_node
      else `Submit_to_pbs
    in
    begin match how with
    | `On_login_node ->
      daemonize ~host p
    | `Submit_to_pbs ->
      let processors =
        List.find_map requirements
          ~f:(function `Processors n -> Some n | _ -> None) in
      let name =
        Option.map name ~f:(fun n ->
            String.map n ~f:(function
              | 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' as c -> c
              | other -> '_')) in
      pbs ~host ?name ?processors p
    end
  in
  let open Ketrew.EDSL in
  let open Biokepi.Setup.Download_reference_genomes in
  let toolkit =
    Biokepi.Setup.Tool_providers.default_toolkit ()
      ~host
      ~install_tools_path
      ~run_program
      ~gatk_jar_location:(fun () -> gatk_jar_location)
      ~mutect_jar_location:(fun () -> mutect_jar_location) in
  Biokepi.Machine.create (name "cluster")
    ~pyensembl_cache_dir
    ~max_processors
    ~get_reference_genome:(fun name ->
        Biokepi.Setup.Download_reference_genomes.get_reference_genome name
          ~toolkit
          ~host ~run_program
          ~destination_path:reference_genomes_path)
    ~host
    ~toolkit
    ~run_program
    ~work_dir:(work_dir // "work")
