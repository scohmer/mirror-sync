podman build -t rocky-mirror-all ./dl.rockylinux.org
sudo mkdir -p /srv/yum
sudo chcon -Rt container_file_t /srv/rocky-mirror
podman run --rm -v /srv/rocky-mirror:/rocky-mirror:Z rocky-mirror-all
