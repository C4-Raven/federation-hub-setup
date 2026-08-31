# Federation Hub Setup

Scripts to stand up [TAK Server Federation Hub](https://tak.gov) end-to-end on
a fresh box: MongoDB, the Federation Hub package itself, a dedicated CA with
server/admin certs, and a running systemd service -- ready to manage from its
native admin console.

<table>
<tr>
<td><img src="docs/screenshots/policy-manager.jpg" alt="Policy Manager"></td>
<td><img src="docs/screenshots/ca-manager.jpg" alt="CA Manager"></td>
</tr>
<tr>
<td align="center"><sub>Policy Manager -- drag-and-drop federation rules</sub></td>
<td align="center"><sub>CA Manager -- trusted certificate authorities</sub></td>
</tr>
</table>

<p align="center">
  <img src="docs/screenshots/metrics-dashboard.jpg" alt="Metrics Dashboard" width="700">
  <br>
  <sub>Live broker metrics</sub>
</p>

## Install

Run these **in order**, in a real terminal -- `sudo` needs an actual TTY,
which won't be available if you're piping this through an automation tool:

```bash
cd federation-hub-setup
bash 01-base-install.sh      # MongoDB 7.0 + openjdk-17-jdk + the .deb
bash 02-mongo-auth.sh        # locks down MongoDB with a generated password
bash 03-generate-certs.sh    # dedicated Federation Hub CA + server + admin certs
bash 04-finish-and-start.sh  # wires certs into config, registers systemd, starts it
```

Each script prints what it did and what's next. If a step fails partway
through, don't just re-run it blind -- some of these (cert generation, the
Mongo user) aren't cleanly re-runnable from scratch. Fix the underlying issue
first.

## After install

- Native admin console: `https://<your-host>:9100` (requires the generated
  `fedhub-admin.p12` client certificate for mTLS login -- see step 3's output
  for where that and its password land).
- Federation broker ports: `9101` (v1) and `9102` (v2).

See [`C4-Raven/c4raven-ui`](https://github.com/C4-Raven/c4raven-ui)'s
[Federation Hub tab](https://github.com/C4-Raven/c4raven-ui/tree/master/docs/federation-hub)
for a Raven-styled admin UI that talks to the same instance without needing
that client certificate for everyday use.
