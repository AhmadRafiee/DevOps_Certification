# [MULTI-STAGE BUILDS WITH DOCKER](https://duo.com/labs/tech-notes/multi-stage-builds-with-docker)

## 01. Introduction
One of the potential benefits of containers is being able to dramatically reduce the attack surface of a running application. However, oftentimes tools are needed to build the application (e.g compilers) that aren't needed in the container that runs the application in production. Multi-stage containers are perfect for this. Your Dockerfile builds multiple containers, where the first ones do the building of the application, and the final container uses the output of the initial containers.

The easiest way to get started with this is to have two FROM statements in your Dockerfile. The second FROM will build a second container and you can move files from the first container in the second one using the standard COPY command but with the flag --from=0 that will copy from the first container instead of from your local filesystem.

## 02. Walkthrough
Let's walk through building a container for CoreDNS. CoreDNS "is a DNS server/forwarder, written in Go." As this will generate a compiled binary, we can aim to have a final container that contains just the CoreDNS binary and nothing else, keeping the attack surface as minimal as possible.

Let's step through this Dockerfile

```bash
FROM golang:1.14

RUN git clone https://github.com/coredns/coredns.git /coredns
RUN cd /coredns && make

FROM scratch
COPY --from=0 /coredns/coredns /coredns

EXPOSE 53 53/udp
CMD ["/coredns"]
```
The first container starts with the official golang container (FROM golang:1.14), then git clones the CoreDNS repository into the /coredns directory. Then it runs make and generates the CoreDNS binary at the location /coredns/coredns.

Using FROM again starts a second container, in this case starting with the base container "scratch". Scratch is a special base container that is "an explicitly empty image, especially for building images 'FROM scratch'".

Next, COPY --from=0 /coredns/coredns /coredns uses the --from=0 flag to tell the COPY command to pull from the first container instead of the local filesystem so it pulls the /coredns/coredns binary from the first container and places it in the location /coredns in the current container.

EXPOSE exposes port 53 on TCP and UDP so the DNS service can be accessed. CMD designates /coredns as the command that's run when the container is started.

To build the container described above, put the Dockerfile commands listed into a file called Dockerfile and run docker build -t my-coredns-container . and it will build two containers but only tag the final container containing only the CoreDNS binary as "my-coredns-container" which can then be run with docker run my-coredns-container.

## 03. Naming Stages
For longer Dockerfiles, or just for clarity you can name the stages of the build using the AS command. For that replace the first line in the example above with FROM golang:1.14 AS builder. Then when referencing it later you would use the name instead of number, so you would use COPY --from=builder /coredns/coredns /coredns.

## 04. Using External Images
You can also reference an external image as a stage directly. For example if your container needs to use the default nginx config file, you can use COPY --from=nginx:latest /etc/nginx/nginx.conf /nginx.conf.

## 05. Summary
Multi-Staging builds in Docker allows for greater clarity in Dockerfiles, and simpler final production containers with a potentially smaller attack surface. If you want to separate out your build process and separate it from your final production containers, you can do so a fairly straightforward manner.

