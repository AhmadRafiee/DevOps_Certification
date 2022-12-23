# [dockerfile best-practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
## Pipe Dockerfile through `stdin`
Docker has the ability to build images by piping Dockerfile through stdin with a local or remote build context. Piping a Dockerfile through stdin can be useful to perform one-off builds without writing a Dockerfile to disk, or in situations where the Dockerfile is generated, and should not persist afterwards.

```bash
echo -e 'FROM busybox\nRUN echo "hello world"' | docker build -
```
```bash
docker build -<<EOF
FROM busybox
RUN echo "hello world"
EOF
```
The following example builds an image using a Dockerfile that is passed through stdin. No files are sent as build context to the daemon.

```bash
docker build -t myimage:latest -<<EOF
FROM busybox
RUN echo "hello world"
EOF
```

## Here’s an example from the buildpack-deps image:
```bash
RUN apt-get update && apt-get install -y \
  bzr \
  cvs \
  git \
  mercurial \
  subversion \
  && rm -rf /var/lib/apt/lists/*
```

## Below is a well-formed RUN instruction that demonstrates all the apt-get recommendations.
```bash
RUN apt-get update && apt-get install -y \
    aufs-tools \
    automake \
    build-essential \
    curl \
    dpkg-sig \
    libcap-dev \
    libsqlite3-dev \
    mercurial \
    reprepro \
    ruby1.9.1 \
    ruby1.9.1-dev \
    s3cmd=1.1.* \
 && rm -rf /var/lib/apt/lists/*
```

## Here is an example .dockerignore file:
```bash
# comment
*/temp*
*/*/temp*
temp?
```

This file causes the following build behavior:
| Rule | Behavior |
| :-------- | :------- |
| `# comment` | Ignored. |
| `*/temp*` | Exclude files and directories whose names start with `temp` in any immediate subdirectory of the root. For example, the plain file `/somedir/temporary.txt` is excluded, as is the directory `/somedir/temp`.
 |
| `*/*/temp*` | Exclude files and directories starting with `temp` from any subdirectory that is two levels below the root. For example, `/somedir/subdir/temporary.txt` is excluded. |
| `temp?` | Exclude files and directories in the root directory whose names are a one-character extension of `temp`. For example, `/tempa` and `/tempb` are excluded. |