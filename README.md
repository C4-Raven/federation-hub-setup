# Federation Hub Setup

Scripts to stand up [TAK Server Federation Hub](https://tak.gov) end-to-end on
a fresh box: MongoDB, the Federation Hub package itself, a dedicated CA with
server/admin certs, and a running systemd service -- ready to manage from its
native admin console.

Federation Hub is TAK Server's dedicated service for linking separate TAK
deployments together, so units on one server can share position, chat, and
other CoT data with units on another. It runs as its own set of Java
processes (a policy manager, plugin manager, UI, and broker) coordinated over
an embedded Apache Ignite cluster, backed by MongoDB for storage, and
presents its own admin console distinct from the main TAK Server web UI.

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

## Contents

- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Install](#install)
- [Verifying the install](#verifying-the-install)
- [After install](#after-install)
- [Federating with a partner](#federating-with-a-partner)
- [Troubleshooting](#troubleshooting)
- [Security notes](#security-notes)
- [Known issues in this Federation Hub release](#known-issues-in-this-federation-hub-release)
- [Uninstalling](#uninstalling)

## Architecture

The `.deb` package installs four separate Java processes under one systemd
unit, all coordinated over a local Apache Ignite cluster (not a network
service -- it's an in-process coordination layer between the four):

| Process | Role |
| --- | --- |
| **Broker** | Speaks the actual federation protocol to remote hubs over TLS -- ports `9101` (v1) and `9102` (v2). This is the only process that talks to the outside world for federated CoT traffic. |
| **Policy manager** | Owns the federation policy graph -- which CAs are trusted, which outgoing connections exist, and the data-sharing rules between them. |
| **Plugin manager** | Tracks registered plugins for extending what Federation Hub can do with federated data. |
| **UI** | Serves the admin console and its REST API on port `9100`, gated by mTLS client-cert login (or, in theory, Keycloak/OAuth -- see [Known issues](#known-issues-in-this-federation-hub-release)). |

Persistent state (policies, CA groups, registered plugins) lives in MongoDB,
not in a config file -- the YAML files under
`/opt/tak/federation-hub/configs/` hold connection settings and secrets, not
the policy data itself.

## Prerequisites

- A Debian/Ubuntu box with `sudo` access and a real terminal (not run through
  an automation tool that lacks a TTY -- see the note below).
- The Federation Hub `.deb` package downloaded separately (TAK.gov account
  required) and placed somewhere `01-base-install.sh` can find it.
- A DNS name for the host already resolving correctly, since the generated
  server certificate is issued for that specific hostname.
- Ports `9100`-`9102` reachable from wherever you'll administer the hub from
  and wherever partner federations will connect from.
- If the box already runs a TAK Server / OpenTAKServer install, be aware it
  likely already holds port `8080` for its own insecure HTTP listener -- see
  [Known issues](#known-issues-in-this-federation-hub-release).

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

| Script | What it does |
| --- | --- |
| `01-base-install.sh` | Installs MongoDB 7.0 and `openjdk-17-jdk`, then installs the Federation Hub `.deb`. |
| `02-mongo-auth.sh` | Generates a random password, creates a Mongo user for Federation Hub, and switches MongoDB from no-auth to auth-required. |
| `03-generate-certs.sh` | Builds a **dedicated** Federation Hub CA (kept separate from any TAK Server / EUD CA already on the box), then issues a server cert for the hub's hostname and an admin client cert (`fedhub-admin.p12`) for logging into the console. |
| `04-finish-and-start.sh` | Wires the generated keystore/truststore paths and passwords into Federation Hub's config files, registers the systemd service, and starts it. |

Each script prints what it did and what's next. If a step fails partway
through, don't just re-run it blind -- some of these (cert generation, the
Mongo user) aren't cleanly re-runnable from scratch. Fix the underlying issue
first.

## Verifying the install

After step 4, confirm all three ports actually came up:

```bash
sudo systemctl status federation-hub --no-pager
sudo ss -tlnp | grep -E ':(9100|9101|9102)\b'
```

You should see the broker log lines for both federation protocol versions
starting, and the UI logging that Jetty started with an SSL connector on
`9100`. If `9100` never appears, check `journalctl -u federation-hub` for a
port conflict (see [Troubleshooting](#troubleshooting)).

## After install

- Native admin console: `https://<your-host>:9100` (requires the generated
  `fedhub-admin.p12` client certificate for mTLS login -- see step 3's output
  for where that and its password land).
- Federation broker ports: `9101` (v1) and `9102` (v2).
- Generated secrets (Mongo password, keystore/truststore passwords) live in
  `/opt/tak/federation-hub/certs/.fedhub-cert-passwords` and inside the
  written config files -- back these up somewhere safe, they aren't
  reproducible without regenerating certs from scratch.

See [`C4-Raven/c4raven-ui`](https://github.com/C4-Raven/c4raven-ui)'s
[Federation Hub tab](https://github.com/C4-Raven/c4raven-ui/tree/master/docs/federation-hub)
for a Raven-styled admin UI that talks to the same instance without needing
that client certificate for everyday use.

## Federating with a partner

Federation trust is mutual and CA-based -- there's no single "add a
federation partner" button, it's a two-sided cert exchange plus, optionally,
an outbound connection:

1. **Exchange CAs.** From CA Manager (or the Raven UI's CA Groups tab),
   export this hub's own CA and send it to the partner; have them send you
   theirs. Each side uploads the other's CA under *Add New Certificate
   Authority* / *Add CA*.
2. **Decide connection direction.** If the partner is going to dial in to
   you, nothing further is needed on your side once their CA is trusted --
   they configure the outgoing connection pointed at your broker's `9101` or
   `9102`. If you're dialing out to them instead, add an **Outgoing**
   connection in Policy Manager (or Raven's Federations tab) with their
   broker's host and port.
3. **Draw the policy.** In Policy Manager, drag a line between the CA
   group/outgoing connection nodes to create a data-sharing rule. Rules can
   allow all groups through, or restrict to specific TAK groups by name.
4. **Watch it connect.** Active Connections (Policy Manager's Matrix view, or
   Metrics Dashboard) will show the peer once the TLS handshake and policy
   match up on both ends.

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| `federation-hub` service fails to start, no port `9100` in `ss` output | Something else already holds the port the UI's leftover default connector wants -- see [Known issues](#known-issues-in-this-federation-hub-release). |
| MongoDB connection refused in the broker/UI logs | `02-mongo-auth.sh` didn't complete, or MongoDB was restarted with a different config afterward -- check `sudo systemctl status mongod`. |
| Browser shows "not secure" on the admin console | Expected -- the server cert is signed by this hub's own dedicated CA, not a public one, so no browser will trust it by default. Import `fedhub-admin.p12` as a client cert; that's what actually gates login, separately from the server cert's trust. |
| Admin console asks for a client certificate you don't have | You need `fedhub-admin.p12` (from step 3) imported into your browser or OS certificate store, plus its password from `.fedhub-cert-passwords`. |
| A partner's connection never shows as active | Confirm both sides actually uploaded each other's CA (not just generated their own), and that the outgoing side's host/port match the broker's real listening address. |

## Security notes

- The Federation Hub CA is deliberately **separate** from any CA already used
  for TAK Server / EUD client certs on the same box, so a compromise of one
  doesn't automatically extend trust to the other.
- `fedhub-admin.p12` is a full client identity with admin rights to the
  console -- treat it like a root credential. Copy it off the server over a
  secure channel, not left sitting in a shared Downloads folder.
- Generated passwords (Mongo, keystore, truststore) are stored in plaintext
  in `.fedhub-cert-passwords` and the Federation Hub config YAML files,
  readable by whichever local user Federation Hub runs as. This is how the
  package itself is designed to work -- there's no external secrets manager
  integration -- so treat filesystem access to that user as equivalent to
  having those credentials.

## Known issues in this Federation Hub release

Found while building the above:

- The UI service's embedded web server doesn't fully release its default
  Spring Boot connector before adding its own TLS one, so if anything else on
  the box already holds port 8080 (common -- e.g. an existing TAK Server
  install's insecure HTTP listener), the whole UI service fails to start.
  Worked around here by pointing `server.port`/`server.address` at an
  internal, loopback-only port via JVM system properties in
  `federation-hub-ui.sh`, rather than changing anything else on the box.
- The bundled Keycloak/OAuth login option is broken: the login flow completes
  and Keycloak issues a token with the correct claims, but Federation Hub's
  own session validation still rejects it afterward. mTLS with the generated
  admin client cert is the only working login path in this release.

## Uninstalling

There's no automated teardown script here (the install is destructive enough
-- a fresh CA, a Mongo user, a systemd service -- that a blind uninstall
script would be riskier than doing it deliberately). To remove by hand:

```bash
sudo systemctl disable --now federation-hub
sudo apt remove takserver-fed-hub
# back up first if you want to keep them:
sudo rm -rf /opt/tak/federation-hub
```

MongoDB and its data are left untouched, since other things on the box may
depend on it -- remove that separately if it's no longer needed.
