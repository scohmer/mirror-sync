FROM debian:12

RUN apt-get update && \
    apt-get install -y debmirror gnupg curl rsync debian-archive-keyring && \
    apt-get clean

ENTRYPOINT ["/usr/local/bin/sync-mirror.sh"]
