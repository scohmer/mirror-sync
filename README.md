# Mirror Sync Project

This project is intended to modularize the syncronization of several available Linux distro mirrors. The overall strategy is to:

1. Build a container file with the distribution and major version.
    - install relevant packages for the task.
    - bring into the container and make executable a shell script that...
    - serves as the container entrypoint and...
2. runs the relevant command or commands per distro to sync the mirror (sync-mirror.sh)
3. build-and-sync.sh outside the container runs all of the commands necessary to build the container and run it.
4. the systemd .service unit calls build-and-sync.sh, providing a mechanism by which the...
5. ... systemd .timer calls the job for regular automated syncronization.
