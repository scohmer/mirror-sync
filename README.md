podman build -t debian-mirror:bookworm .

```
sudo mkdir -p /srv/debian-mirror
sudo chown -R root:root /srv/debian-mirror
sudo chcon -Rt container_file_t /srv/debian-mirror  # For SELinux
```

debian-mirror-sync.service
```
[Unit]
Description=Sync Debian 12 mirror (dists only)
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/podman run --rm \
  -v /srv/debian-mirror:/debian-mirror:Z \
  debian-mirror:bookworm

# Optional: Add some logging
StandardOutput=journal
StandardError=journal
```


debian-mirror-sync.timer
```
[Unit]
Description=Run Debian mirror sync daily

[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

Enable and start the timer
```
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now debian-mirror-sync.timer
```

For a run
```
sudo systemctl start debian-mirror-sync.service
```
