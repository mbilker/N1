# VERSION:        0.1
# DESCRIPTION:    Image to build N1 and create a .rpm file, derived from Atom's Dockerfile

# Base docker image
FROM fedora:21

# Install dependencies
RUN yum install -y \
    make \
    gcc \
    gcc-c++ \
    glibc-devel \
    git-core \
    libgnome-keyring-devel \
    rpmdevtools \
    nodejs \
    npm

RUN npm install -g npm@3.3.10 --loglevel error

ADD . /n1
WORKDIR /n1
