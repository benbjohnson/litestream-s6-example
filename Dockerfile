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
	go build -ldflags '-w -extldflags "-static"' -o /usr/bin/myapp .


# This starts our final image; based on alpine to make it small.
FROM alpine

# Install packages.
RUN apk add gettext

# You can optionally set the replica URL directly in the Dockerfile.
# ENV REPLICA_URL=s3://BUCKETNAME/db

# Download and install the s6-overlay for process supervision.
ADD https://github.com/just-containers/s6-overlay/releases/download/v2.2.0.3/s6-overlay-amd64-installer /tmp/
RUN apk upgrade --update && \
	apk add bash && \
	chmod +x /tmp/s6-overlay-amd64-installer && \
	/tmp/s6-overlay-amd64-installer /

# Download the static build of Litestream directly into the path & make it executable.
ADD https://github.com/benbjohnson/litestream/releases/download/v0.3.4-alpha18/litestream-v0.3.4-alpha18-linux-amd64-static /usr/bin/litestream
RUN chmod +x /usr/bin/litestream

# Copy executable from builder.
COPY --from=builder /usr/bin/myapp /usr/bin/myapp

# Create data directory (although this will likely be mounted too)
RUN mkdir -p /data

# Notify Docker that the container wants to expose a port.
EXPOSE 8080

# Copy s6 init & service definitions.
COPY etc/cont-init.d /etc/cont-init.d
COPY etc/services.d /etc/services.d

# Copy Litestream configuration file.
COPY etc/litestream.yml /etc/litestream.yml

# Run the s6 init process on entry.
ENTRYPOINT [ "/init" ]

