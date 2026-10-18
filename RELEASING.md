# Publishing

Run `./test.sh`, `./test-web.sh`, and `./test-reader.sh`, inspect the actual application, then `./package.sh`. The packaged app is ad hoc signed, not Apple-notarized. Keep this limitation visible in README and release notes until a Developer ID signing and notarization workflow is configured.

The first publication can be performed with GitHub CLI:

```sh
gh auth login
./publish.sh
```

The script creates the public `Michaellzd/folio-reader` repository only when it does not already exist, pushes the committed source, and publishes the version from Info.plist with the application ZIPs and SHA256SUMS. It refuses to overwrite an existing remote repository. It never uploads files from the parent books directory.

For later manual releases, update Info.plist and release notes, run the tests and packaging, push the committed source, and use `gh release create` with the two application ZIPs and SHA256SUMS.

An optional GitHub Actions template is included at `Tools/github-release-workflow.yml`. Automation is not enabled in this repository. To enable it, authorize GitHub CLI's `workflow` scope and copy the template to `.github/workflows/release.yml`. The current connection grants repository publishing access and does not grant workflow editing. Once enabled, `v*` tags run tests, build both architectures, and attach application downloads to the release. `GITHUB_TOKEN` is provided by GitHub Actions; a workflow_dispatch run validates builds and uploads a CI artifact without publishing a release.

Before making a new release public, extract its ZIP and verify that the app launches, opens an EPUB through the file picker and Finder, restores position, and switches all four interface languages. Never bundle real books or private screenshots. The README image uses original demonstration text.
