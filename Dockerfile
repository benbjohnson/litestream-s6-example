# Use the Go image to build our application.
FROM golang:1.16 as builder

# Copy the present working directory to our source directory in Docker.
COPY . /src/myapp

# Change the current directory in Docker to our source directory.
WORKDIR /src/myapp

# Build our application as a static build.
# The mount options add the build cache to Docker to speed up multiple builds.
RUN --mount=type=cache,target=/root/.cache/go-build \
	--mount=type=cache,target=/go/pkg \
	go build -ldflags '-s -w -extldflags "-static"' -tags osusergo,netgo,sqlite_omit_load_extension -o /usr/local/bin/myapp .

# Download the static build of Litestream directly into the path & make it executable.
# This is done in the builder and copied as the chmod doubles the size.
ADD https://github.com/benbjohnson/litestream/releases/download/v0.3.5/litestream-v0.3.5-linux-amd64-static.tar.gz /tmp/litestream.tar.gz
RUN tar -C /usr/local/bin -xzf /tmp/litestream.tar.gz

# Download the s6-overlay for process supervision.
# This is done in the builder to reduce the final build size.
ADD https://github.com/just-containers/s6-overlay/releases/download/v2.2.0.3/s6-overlay-amd64-installer /tmp/
RUN chmod +x /tmp/s6-overlay-amd64-installer


# This starts our final image; based on alpine to make it small.
FROM alpine

# You can optionally set the replica URL directly in the Dockerfile.
# ENV REPLICA_URL=s3://BUCKETNAME/db

# Copy executable & Litestream from builder.
COPY --from=builder /usr/local/bin/myapp /usr/local/bin/myapp
COPY --from=builder /usr/local/bin/litestream /usr/local/bin/litestream

# Install s6 for process supervision.
COPY --from=builder /tmp/s6-overlay-amd64-installer /tmp/s6-overlay-amd64-installer
RUN /tmp/s6-overlay-amd64-installer /

RUN apk add bash

# Create data directory (although this will likely be mounted too)
RUN mkdir -p /data

# Notify Docker that the container wants to expose a port.
EXPOSE 8080

# Copy s6 init & service definitions.
COPY etc/cont-init.d /etc/cont-init.d
COPY etc/services.d /etc/services.d

# Copy Litestream configuration file.
COPY etc/litestream.yml /etc/litestream.yml

# The kill grace time is set to zero because our app handles shutdown through SIGTERM.
ENV S6_KILL_GRACETIME=0

# Sync disks is enabled so that data is properly flushed.
ENV S6_SYNC_DISKS=1

# Run the s6 init process on entry.
ENTRYPOINT [ "/init" ]

