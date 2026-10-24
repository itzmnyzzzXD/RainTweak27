# Install RainTweak27 with FrozenApps

RainTweak27 builds a modified Discord IPA. The IPA produced by this workflow is intentionally **not fake-signed**. FrozenApps/SideStick's normal custom-IPA path imports the file, signs it with your own Apple developer session, and installs the signed application over the paired-device connection.

## Build the IPA

1. Open [Actions → Build IPA Artifact](https://github.com/itzmnyzzzXD/RainTweak27/actions/workflows/build-ipa.yml).
2. Choose **Run workflow**, enter a direct HTTPS URL for a decrypted Discord IPA that you are permitted to use, and leave the bundle ID as `com.itzmnyzzxd.discord` unless your signing setup requires a different identifier. It must match the App ID your signing account provisions.
3. Let the build finish. Download the **RainTweak27-IPA-for-FrozenApps** artifact.
4. On your iPad, open the downloaded artifact ZIP in Files and extract it. Select the `.ipa` file inside; do not select the ZIP, `.deb`, checksum, or build-info text file.

## Import, sign, and install on iPad

1. Open FrozenApps/SideStick and enter **Files → IPA Library**.
2. Tap **Import IPA**, then select the extracted `RainTweak.ipa` file.
3. Open the imported package and confirm its metadata. Tap **Load into Signer**.
4. Switch to **Signer**, choose the **Custom IPA** source, and run the install flow.
5. Follow the app's own pairing, Local Network, tunnel/VPN, Apple Account authentication, two-factor, and signing prompts. The app signs the imported IPA with your developer session and then requests installation over the paired device connection.

The workflow rewrites the main app's bundle ID and adjusts its embedded app-extension IDs to match. This avoids trying to provision Discord's original publisher-owned identifier with your personal account. Use an identifier that your signing account can register; if you change it, ensure it is the identifier used by your provisioning profile. The tweak still reports Discord's expected identifier to its own code at runtime.\n\nThe exact prerequisites depend on your iPadOS version. The pairing/tunnel steps must be completed before installation; this is not a one-tap Safari or OTA install. A successful GitHub build only confirms that the IPA archive is structurally valid. It does not prove that Apple will accept the signing request or that the app will launch on your device.

## Troubleshooting

- **"Not an IPA" or invalid archive:** extract the Actions artifact ZIP first and choose the actual `.ipa` file.
- **Signing fails:** review the error in Signer. App ID, provisioning, certificate limits, account eligibility, and the app's entitlements can affect the result.
- **Installation fails:** check pairing status, Local Network permission, the required tunnel/VPN, free-app limits, and the actual device-side error.
- **App opens but Rain doesn't load:** confirm that the source Discord IPA is compatible with the current tweak and that its React Native architecture meets RainTweak's requirements.

Only use IPA files you are authorised to modify and install. Keep the downloaded IPA private unless you have the rights needed to redistribute the modified Discord app.
