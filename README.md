# Stratotemplate

Configuration template for stratocumulus &amp; more

## Recommended Usage

### Set up your “GClouder”

#### Create a GCloud VM

* Log in to Google Cloud, go to the "console" (which is the main dashboard) &
  enter the Compute Instance Dashboard.
* From here, create a new VM that will be your virtual devbox to work from (it doesn't need to be beefy).
   * Make sure that, under "Identity and API Access", you select "Allow full
     access to all Cloud APIs."
* Add your SSH key to the instance (under **Management, disk, networking,
  SSH keys > SSH Keys** at the bottom).

And click to let the magic happen.

#### Setup The Host

To SSH into your machine you can use `ssh username@instance-ip`, instance-ip is found on the
information page for your instance after it boots up.<br/>
You can also setup a `Host` in your `~/.ssh/config` file.<br/>
Let's call it `GClouder` in the following.

Get to the GClouder:

    ssh GClouder

Install a few more things:

    sudo apt-get update
    sudo apt-get install -y unzip build-essential git

The VM comes with `gcloud` installed but this deployment does not have full
capabilities; we need to get a fresh one
(Cf. also <https://code.google.com/p/google-cloud-sdk/issues/detail?id=336>):

    curl https://sdk.cloud.google.com | bash

… saying `Yes` to everything … and then, you need to reload your `.bashrc` (just
type `bash`).

For some reason the zone has to be configured again (replace `us-east1-c` with
your favorite part of the world):

    gcloud config set compute/zone us-east1-c


Create an SSH key-pair for for `gcloud` itself:

    gcloud compute ssh $(hostname) ls

and accept the prompts (with an empty password).


### Get The Configuration Template

We use Git, so that you the user can save their configuration:

    git clone https://github.com/smondet/stratotemplate.git
    cd stratotemplate

### Get a Ketrew Server

This section creates a functional Ketrew server with Google-Container-Engine.

Edit the file `configuration.env`, make sure you're happy with the `$PREFIX` and
`$TOKEN` values.

Get the script, and run it:

    wget https://raw.githubusercontent.com/hammerlab/stratocumulus/master/tools/gcpketrew.sh -O gcpketrew.sh

    . configuration.env
    sh gcpketrew.sh up
    # The first time this may prompt for a `[Y/n]` question.

When the command returns the deployment is partially ready, one needs to ask for
the status a few times before the “External IP” is available:

    sh gcpketrew.sh status

When it's ready, a little more configuration is required (*is this command fails;
wait and try again a minute or so later until it succeeds; the container engine
may be slow at creating “pods”*):

    sh gcpketrew.sh configure+local

(**Warning:** the `+local` part will append a line to the
`~/.ssh/authorized_keys` file, use `configure` if you don't want that).

At any time the `status` command will give you the URL of the Ketrew server's
WebUI.

Of course, you can save your changes to the `stratotemplate` repository like any
other git repo.

When you want to take the server down (and delete everything related to it):

    sh gcpketrew.sh down


### Get a Stratocumulus Environment

We're going to use Docker to get a fully functional OCaml/Opam/Stratocumulus
environment.

Get Docker:

    sudo apt-get install -y docker.io

Get the image:

    sudo docker pull smondet/stratocumulus

Make `$PWD` accessible by the container:

    chmod -R a+rw .

Get in:

    sudo  docker run -it  -v $PWD:/hostuff/ smondet/stratocumulus bash

Now you're in the right environment to submit stratocumulus deployment jobs.

    cd /hostuff

Edit further `configuration.env` to set `GCLOUD_HOST`, `CLUSTER_NODES` … cf.
comments in the file.

    . configuration.env

Use the URL provided above by `sh gcpketrew.sh status` to create a Ketrew
configuration:

    ketrew init --conf ./ketrewdocker/ --just-client $(cat $KETREW_URL)

Create an NFS server with storage:

    KETREW_CONFIG=./ketrewdocker/configuration.ml ocaml nfs_server.ml up submit

Create a compute cluster:

    KETREW_CONFIG=./ketrewdocker/configuration.ml ocaml cluster.ml up submit

The 2 above commands submit workflows to the Ketrew server, you can monitor them
with the WebUI (see `cat $KETREW_URL`).

Replace `up` with `down` to take the deployments down ☺
