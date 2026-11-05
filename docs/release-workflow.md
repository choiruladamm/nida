# Personal release workflow

Issue [#34](https://github.com/choiruladamm/nida/issues/34). This is local personal distribution, not notarized public distribution. No Apple Developer credentials, checkout, updater service or self-hosted runner is introduced.

## CI and merge

`.github/workflows/ci.yml` runs on PRs to main and pushes to main. One `verify` job runs release-tool regression tests, Swift tests and Release compilation. It uses the standard `xcode-27` preview runner and explicitly selects `/Applications/Xcode_27.app` (Xcode 27.0). The runner image has macOS 27, matching the current test baseline; deployment remains macOS 26. See [GitHub's runner announcement](https://github.com/actions/runner-images/issues/14404) and [image inventory](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md).

Runs are bounded to 25 minutes and superseded runs are cancelled per PR/branch. Checkout has no persisted credentials; workflow permissions are read-only. No build artifact upload, signing secret or cache service is needed. Standard public-repo compute is free under the checked GitHub policy; paid larger runners are not used. The preview image may have queue/capacity limitations. Hardware smoke stays local.

The intended main protection requires the GitHub Actions `verify` check, up-to-date branches, and PRs (including administrators); zero mandatory external approvals lets the solo owner accept their own PR after local review. Protection activation and actual hosted-run evidence are recorded in the issue, not assumed from this YAML. Merging never installs an app.

## Commands

```sh
make release-test # Failure-path tests, no installed-app mutations
make icons        # Regenerate committed native icon assets
make dmg          # Package committed HEAD as a personal installer candidate
make promote      # Fetch/test/build/install exact CI-passed origin/main
make rollback     # Swap installed Stable with the single previous binary
```

`python3`, GitHub CLI authentication and Xcode command-line tools are required. `make dmg` and `make promote` reject a dirty source tree. They use `git archive` into temporary source directories and never switch/delete the owner's checkout or feature branch. `make promote` requires the latest push CI for the exact fetched main SHA to have succeeded; no missing/pending/failed check bypass is supplied. The API check requires network access and fails closed. Rollback is local and does not need GitHub.

## Candidate, icon and DMG

Candidates live under `~/Library/Application Support/NidaReleases/candidates/<SHA>/Nida.app`, outside both app sandboxes and cleanable repository build output. The tool runs Swift tests and Release compilation first. Source SHA is baked into the signed Info.plist; each candidate gets a receipt with version/build/SHA and a bundle tree hash. Reuse checks both the signature and receipt hash. Build output stays in NidaReleases/DerivedData; last-build.log identifies failed build steps. Candidate caches can be removed manually when no tool is running; keep the current previous.app backup.

Both app configurations have native macOS icon assets. Stable uses the existing moon direction on a dark green surface; Dev adds an amber DEV badge. `scripts/generate-icons.swift` renders them with AppKit, without an image service or new dependencies. Product artwork still needs owner visual acceptance. The separate template menu symbols stay moon/hammer.

`make dmg` wraps that same verified candidate with an Applications shortcut. It creates a temporary UDZO image, mounts it read-only, checks app identity/signature/source/tree hash and the shortcut, then detaches and publishes the DMG plus SHA-256 sidecar under NidaReleases/packages. Filenames include version/build/source prefix. A failed packaging attempt never replaces the installed app. A DMG can be used for first install/reinstall; routine updates use promote. No image is automatically uploaded or published.

Personal candidate version is 0.2.0 (5); published 0.2.0 (4) is unchanged. The full source SHA distinguishes candidate builds with the same version; select accepted code before treating a candidate as daily Stable.

## Promotion, login registration and rollback

Before stopping Stable, the tool verifies the candidate's identity, ad-hoc signature, sandbox entitlement, executable and exact source SHA. It checks the current login record, rejects a foreign build-folder Stable process/symlink target, and stages/verifies copies plus a backup. Build/check/copy/permission failures leave the installed app and running process untouched.

Only then does it stop the exact `/Applications/Nida.app` process, replace the app in its parent filesystem and restore the owner's login-enabled intent. Release-only maintenance flags run before window/delivery startup and only at the installed path. `--restore-login-enabled` unregisters/reregisters from that path only when promotion recorded enabled-and-allowed beforehand. Disabled/revoked consent is not silently enabled. The OS record must still match the installed path and desired state; errors fail the promotion. This addresses the observed stale Debug URL during the earlier bootstrap.

The tool opens the new Stable and checks that exactly one installed process stays present through a short startup interval. This does not prove absence of later runtime bugs. One prior app is retained as NidaReleases/previous.app; rollback swaps binaries without touching sandbox data or Dev. An identical candidate is a no-op. Installation requires write access to Applications; there is no silent sudo/escalation.

On detected replacement/registration/startup failure, the old binary is restored and relaunched. If recovery itself fails, copies are retained and their paths printed instead of being deleted. For a prior app without the maintenance protocol, rollback preserves the already-valid OS login record without invoking unsupported flags. It refuses changed enabled intent or a stale enabled URL, which need repair through that app’s Settings toggle. Approval denied by macOS cannot be bypassed. A failed/partial registration needs an explicit System Settings check, not a claimed successful auto-launch.

A per-state-directory lock blocks concurrent package/promote/rollback operations. An abrupt kill can leave `.lock`; inspect for a running release.py process and recovery directories before manually removing a stale lock. No automatic deletion of possible recovery data is performed. Future incompatible data migrations require a separate rollback design: restoring an app binary does not reverse migrated data.

## Verification boundary

Fixture tests cover invalid candidates, copy failure, rename failure, startup/registration failure, failed recovery retention, single-backup rollback, unchanged candidates, cached tampering, dirty sources, CI failure/pending/missing states, icon sizes and disabled login intent parsing. These tests do not alter Applications or real login settings. Native tests/build/smoke, mounted DMG verification, real hosted CI, real installation/rollback and hardware observations must be reported separately.

Do not install an unmerged candidate merely to make acceptance green. Once this workflow is merged and main CI succeeds, run promote for that exact main commit. Actual restart/login, permissions, owner icon/DMG fit, VoiceOver, fullscreen/Spaces and external displays remain observed-only checks. No automated reboot/logout is performed.
