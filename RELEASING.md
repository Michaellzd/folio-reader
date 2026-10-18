# Publishing

Run `./test.sh`, inspect the actual application, then `./package.sh`. The packaged app is ad hoc signed, not Apple-notarized. Keep this limitation visible in README and release notes until a Developer ID signing and notarization workflow is configured.

The first publication can be performed with GitHub CLI:

```sh
gh auth login
./publish.sh
```

The script creates the public `Michaellzd/folio-reader` repository only when it does not already exist, pushes the committed source, and publishes v1.0.0 with the application ZIPs and SHA256SUMS. It refuses to overwrite an existing remote repository. It never uploads files from the parent books directory.

Later releases use `.github/workflows/release.yml`: update Info.plist, release notes, and documentation; commit, tag `v<version>`, and push the tag. GitHub Actions runs tests, builds both architectures, creates the archive, and attaches real application downloads to the release. `GITHUB_TOKEN` is provided by GitHub Actions; no third-party action is used for uploading release assets. A workflow_dispatch run validates builds and uploads a CI artifact without publishing a release.

Before making a new release public, extract its ZIP and verify that the app launches, opens an EPUB through the file picker and Finder, restores position, and switches all four interface languages. Never bundle real books or private screenshots. The README image uses original demonstration text.
