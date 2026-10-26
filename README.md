# Crystal Relay (patched)

Automatic rebuilds of [Crystal Relay](https://github.com/seluvia/crystal-relay-public) with two features removed:

- **Live Feedback Heartbeat.** Upstream pings the developer's Cloudflare Worker with your Twitch name and channel URL whenever you're live. The settings toggle was removed and the setting is hardcoded to on, so you can't disable it.
- **`!screm` developer chat commands.** Upstream lets the Twitch account `Screminpal_` resize your avatar, move your VRChat player, and put your channel point rewards on sale from your chat. This runs before your own command permissions and can't be turned off.

Everything else is upstream's code, built with upstream's own build scripts.

## Install

1. Download the zip from the [latest release](https://github.com/mja00/crystal-relay-patched/releases) and extract it over your existing Crystal Relay folder (or anywhere new).
2. Run `Crystal Relay.exe`.

From then on, the in-app updater pulls from this repo, not upstream, so updates stay patched.

## How it works

`.github/workflows/sync.yml` runs every 6 hours. If upstream's latest release isn't mirrored here yet, it:

1. Clones upstream at that release tag.
2. Applies `patches/*.patch` with a 3-way merge (`scripts/Apply-Patches.ps1`).
3. Points the app's update check at this repo.
4. Fails if guards find the heartbeat service, the heartbeat endpoint, or the `!screm` handler wired back in.
5. Runs the test that requires `Screminpal_` to be rejected.
6. Builds with upstream's matching release, bug fix, or beta script (`scripts/Build-Package.ps1`).
7. Publishes a release here with the same tag and asset name, so the updater recognizes it.

If upstream changes the patched code, the run fails and no release is published. Existing installs stay on the last good build until the patches are refreshed.

To rebuild a specific release manually, run the workflow from the Actions tab with its upstream tag, for example `v3.2.0-bugfix8`.

## Limits

These patches remove the two known mechanisms. A new feature with different names that does the same thing would not trip the guards. The World Guard check, which upstream also forces on, is left untouched.
