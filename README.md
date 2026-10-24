# RainTweak

Tweak to inject Rain into discord

## Installation

For this fork, build the IPA through [GitHub Actions → Build IPA Artifact](https://github.com/itzmnyzzzXD/RainTweak27/actions/workflows/build-ipa.yml). The upstream project’s releases remain available at [RainTweak releases](https://codeberg.org/raincord/RainTweak/releases).
**iOS 27 support is experimental.** The fork now builds against the latest iOS SDK available on its CI runner, but runtime compatibility still needs device testing.

<details>
<summary>Issues & Workaround</summary>
<br/>
To resolve the fixable issue, you need to match the app's bundle ID with your provisioning profile's App ID (excluding the team ID prefix):
<table>
<tr>
    <th>Issue</th>
    <th>Fixable</th>
    <th>Example</th>
</tr>
<tr>
    <td>Cannot change app icons</td>
    <td>✓</td>
    <td rowspan="5"><img src="https://adriancastro.dev/e0hbonxknepw.jpg" width="300"></td>
</tr>
<tr>
    <td>Cannot share items to Discord</td>
    <td>✗</td>
</tr>
<tr>
    <td>Cannot use passkeys</td>
    <td>✗</td>
</tr>
</table>

## Doing this will break notifications if the app is backgrounded or closed

</details>


## RainTweak27 build artifacts (no local Xcode required)

This fork includes a GitHub Actions workflow that builds the tweak, injects it into a supplied decrypted Discord IPA, validates the output archive, and uploads `RainTweak.ipa` as a downloadable workflow artifact.

1. Open **Actions → Build IPA Artifact → Run workflow**.
2. Paste a direct **HTTPS download URL for a decrypted Discord IPA** into `ipa_url`.
3. Run the workflow and wait for the build job to finish.
4. Open that run and download the **RainTweak27-IPA-for-FrozenApps** artifact ZIP. Extract `RainTweak.ipa` from it.

The workflow uses GitHub's `xcode-27` runner and doesn't require Xcode to be installed on your own device. It does still require a compatible input IPA; the workflow cannot safely obtain or decrypt Discord's proprietary app package automatically. The resulting IPA is unsigned or has signing removed by the injection tooling, so install it through your usual sideloading/signing process.

The workflow preserves the original package build and app-injection flow. iOS 27 runtime compatibility is not claimed until the resulting IPA has been tested on a device running iOS 27.


## Install on iPad through FrozenApps

The workflow outputs an intentionally non-fake-signed IPA with the default signing bundle ID `com.itzmnyzzxd.discord` for FrozenApps/SideStick's **Custom IPA → Sign → Install** flow. You can change the ID when dispatching the workflow if your provisioning setup requires another identifier. Download the `RainTweak27-IPA-for-FrozenApps` Actions artifact, extract the ZIP in Files, then import the actual `.ipa` via **Files → IPA Library → Import IPA** and tap **Load into Signer**. In Signer, choose the Custom IPA source and follow its pairing, tunnel, Apple Account, signing, and installation prompts. The build does not sign an app with your personal certificate in CI.

See [INSTALL-WITH-FROZENAPPS.md](INSTALL-WITH-FROZENAPPS.md) for the complete flow and troubleshooting. This is not direct OTA installation; iOS requires the IPA to be signed and installed using a supported method.

For a direct download from FrozenApps/SideStick's **App Catalog**, use [Deploy Build](https://github.com/itzmnyzzzXD/RainTweak27/actions/workflows/deploy.yml) with **Release the build** enabled, then add `itzmnyzzzXD/RainTweak27` as a custom catalog source. This makes the `.ipa` a public release asset, so use that route only if you are authorised to redistribute the modified Discord app. Otherwise, import the artifact from Files as described above.
