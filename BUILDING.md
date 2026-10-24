# Build and install RainTweak27 without local Xcode

RainTweak27's CI uses GitHub's hosted `xcode-27` runner to compile the rootless tweak, build the OpenInDiscord extension, inject both into a supplied decrypted Discord IPA, and validate the resulting IPA archive. You do not need Xcode on your iPad or your own computer.

## Option A — build an IPA artifact and import it from Files

1. Open [Actions → Build IPA Artifact](https://github.com/itzmnyzzzXD/RainTweak27/actions/workflows/build-ipa.yml).
2. Choose **Run workflow**.
3. Enter a direct HTTPS download URL for a decrypted Discord IPA you are permitted to modify.
4. Keep the default bundle ID `com.itzmnyzzxd.discord`, unless your signing profile requires another identifier that your account can register.
5. Download the `RainTweak27-IPA-for-FrozenApps` artifact after the job succeeds.
6. In iPad Files, extract the downloaded artifact ZIP. Select the actual `RainTweak.ipa` file, not the ZIP, `.deb`, checksum, or build-info file.
7. In FrozenApps/SideStick, open **Files → IPA Library → Import IPA**, select the `.ipa`, then tap **Load into Signer**. In Signer, choose **Custom IPA** and run the app's normal signing and installation flow.

## Option B — download the release directly inside FrozenApps

Use this option only if you are authorised to publish the resulting modified Discord IPA publicly.

1. Open [Actions → Deploy Build](https://github.com/itzmnyzzzXD/RainTweak27/actions/workflows/deploy.yml).
2. Choose **Run workflow**, provide the source IPA URL and bundle ID, and set **Release the build** to true.
3. After a successful release, open FrozenApps/SideStick's **Center → App Catalog** and add the public source `itzmnyzzzXD/RainTweak27`.
4. Select the release's actual `.ipa` asset and choose **Download & prepare**. Then switch to Signer, load the Custom IPA if it has not already been selected, and run the signing/install flow.

The deploy workflow attaches `RainTweak.ipa`, its SHA-256 checksum, and the rootless `.deb` package to the release. The catalog only works when a real `.ipa` release asset exists; it does not install an unsigned app directly from GitHub.

## What install means here

The IPA is intentionally **not fake-signed** by CI. FrozenApps/SideStick imports it, signs it with your own Apple developer session, and installs the signed bundle over its paired-device connection. Follow its pairing, Local Network, tunnel/VPN, Apple Account, two-factor, provisioning, and device prompts. These prerequisites depend on your iPadOS version.

This is not a one-tap Safari/OTA install. A successful CI run confirms compile/packaging checks only; it does not guarantee Apple will accept signing, that the device will accept the install, or that RainTweak works on every iOS 27/Discord combination.

For detailed steps and troubleshooting, see [INSTALL-WITH-FROZENAPPS.md](INSTALL-WITH-FROZENAPPS.md).
