Run this single command:  

```
nohup ./build-and-sync.sh > /var/log/debian-mirror.log 2>&1 &
```

Then track sync progress by:  

```
tail -f /var/log/debian-mirror.log
```
