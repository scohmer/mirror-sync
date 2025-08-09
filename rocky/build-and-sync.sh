podman build -t rocky-mirror-all ./dl.rockylinux.org
sudo mkdir -p /srv/yum
sudo chcon -Rt container_file_t /srv/yum
podman run --rm -v /srv/yum:/rocky-mirror:Z rocky-mirror-all
