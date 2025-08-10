podman build -t rocky-mirror ./dl.rockylinux.org
sudo mkdir -p /srv/yum/rocky/pub
sudo chcon -Rt container_file_t /srv/yum/rocky/pub
podman run --rm -v /srv/yum/rocky/pub:/rocky-mirror:Z rocky-mirror-all
