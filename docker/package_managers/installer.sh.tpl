#!/usr/bin/env bash
# This script installs debs in installables.tar through dpkg and apt-get.
# It expects to be volume-mounted inside a docker image, in /tmp/pkginstall
# along with the installables.tar.
set -e
pushd /tmp/pkginstall
%{install_commands}
popd
umount -l /tmp/pkginstall
rm -rf /tmp/*
