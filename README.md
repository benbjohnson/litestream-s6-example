Litestream/s6 Example
=====================

This repository provides an example of running a Go application in the same
container as Litestream by using [s6-overlay][]. This allows developers to
release their SQLite-based application and provide replication in a single
container.

[s6-overlay]: https://github.com/just-containers/s6-overlay


## How it works

The Go application provided in `main.go` will compile into a static binary
called `myapp` inside the Docker container. This application simply keeps
track of the number of page views in a SQLite database. A static build of
Litestream is downloaded into the container to provide replication to an
S3-compatible object store. Both the application & Litestream are started
via a small init system called `s6`.

The Dockerfile is well-commented but this is the high level overview:

1. s6 is started via the entrypoint (`/init`)

1. s6 runs `etc/cont-init.d/00-litestream-restore` to restore the database if
   the database doesn't currently exist in `/data/db`.

1. s6 starts the `myapp` and `litestream` services via their `run` definitions
   in the `etc/services.d` directory. Litestream is automatically restarted on
   failure.

1. When `myapp` stops or crashes, the `finish` script is executed which causes
   s6 to shut down Litestream as well.


## Usage

### Prerequisites

To test this locally, you'll need to have an S3-compatible store to connect to.
Please see the [Litestream Guides](https://litestream.io/guides/) to get set up
on your preferred object store.

You'll also need to update the replica URL in `etc/litestream.yml` in this
repository to your appropriate object store.

You'll also need to set your object store credentials in your shell environment:

```sh
export LITESTREAM_ACCESS_KEY_ID=XXX
export LITESTREAM_SECRET_ACCESS_KEY=XXX
```


### Building & running the container

You can build the application with the following command:

```sh
docker build -t myapp .
```

Once the image is built, you can run it with the following command. _Be sure to
change the `REPLICA_URL` variable to point to your bucket_.

```sh
docker run \
  -p 8080:8080 \
  -v ${PWD}:/data \
  -e REPLICA_URL=s3://YOURBUCKETNAME/db \
  -e LITESTREAM_ACCESS_KEY_ID \
  -e LITESTREAM_SECRET_ACCESS_KEY \
  myapp
```

Let's break down the options one-by-one:

- `-p 8080:8080`—maps the container's port 8080 to the host machine's port 8080
  so you can access the application's web server.

- `-v ${PWD}:/data`—mounts a volume from your current directory on the host
  to the `/data` directory inside the container.

- `-e REPLICA_URL=...`—sets an environment variable for your replica. This is
  used by the startup script to restore the database from a replica if it
  doesn't exist and it is used in the Litestream configuration file.

- `-e LITESTREAM_ACCESS_KEY_ID` & `-e LITESTREAM_SECRET_ACCESS_KEY`—passes
  through your current environment variables for your S3 credentials to the
  container. You can also use `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
  instead.


### Testing it out

In another window, you can run:

```sh
curl localhost:8080
```

and you should see:

```
This server has been visited 1 times.
```

Each time you run cURL, it will increment that value by one.


### Recovering your database

You can simulate a catastrophic disaster by stopping your container and then
deleting your database:

```
rm -rf db db-shm db-wal .db-litestream
```

When you restart the container again, it should print:

```
No database found, restoring from replica if exists
```

and then begin restoring from your replica. The visit counter on your app should
continue where it left off.

