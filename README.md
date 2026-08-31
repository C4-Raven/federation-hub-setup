# Federation Hub install

Run these in order, in a real terminal (not via Claude Code's `!` prefix --
sudo needs an actual TTY on this box, which that path doesn't have):

```
cd /home/tak/federation-hub-setup
bash 01-base-install.sh      # MongoDB 7.0 + openjdk-17-jdk + the .deb
bash 02-mongo-auth.sh        # locks down MongoDB with a generated password
bash 03-generate-certs.sh    # dedicated Federation Hub CA + server + admin certs
bash 04-finish-and-start.sh  # wires certs into config, registers systemd, starts it
```

Paste the output back to me after each one (or all four, if they all go
cleanly) and I'll verify before moving on to building the Raven-styled admin
tab that talks to it.

Each script prints what it did and what's next. If a step fails partway
through, tell me the error rather than re-running blind -- some of these
(cert generation, the mongo user) aren't cleanly re-runnable from scratch.
