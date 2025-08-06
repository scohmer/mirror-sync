FROM debian:12

RUN apt-get update && \
    apt-get install -y debmirror gnupg curl rsync debian-archive-keyring && \
    apt-get clean

COPY sync-mirror.sh /usr/local/bin/sync-mirror.sh
RUN chmod +x /usr/local/bin/sync-mirror.sh

ENTRYPOINT ["/usr/local/bin/sync-mirror.sh"]
