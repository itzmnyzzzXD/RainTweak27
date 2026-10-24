# Building a RainTweak27 IPA with GitHub Actions

This workflow builds the rootless Theos package and injects it into a decrypted Discord IPA on GitHub's hosted `xcode-27` runner. You do not need Xcode locally.

## Run it

1. Open the repository's **Actions** tab.
2. Select **Build IPA Artifact** and click **Run workflow**.
3. Paste a direct HTTPS download URL to a decrypted Discord `.ipa`.
4. When the workflow succeeds, open its run and download **RainTweak27-IPA**.
5. Extract the artifact ZIP. It contains `RainTweak.ipa`, the rootless `.deb` package, and `build-info.txt`.

## Input and signing

The source IPA must be one you are permitted to use and must be directly downloadable over HTTPS. The workflow does not fetch or decrypt Discord itself. The generated IPA is intended for a normal compatible sideload/signing workflow; this workflow does not provide an Apple signing certificate or provisioning profile.

The runner uses Xcode 27 to select the latest iOS SDK and compile the native pieces. A successful build validates compilation and archive structure, but actual iOS 27 support still needs on-device testing.
