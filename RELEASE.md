# Highlightr Fork Release Checklist

This repo is a Pixel Boy-maintained fork of `raspu/Highlightr`.

## Versioning

- Keep upstream provenance visible in the tag.
- Use upstream-based fork tags: `<upstream-version>-pb.<n>`
- Examples:
  - first Pixel Boy fork release on upstream `2.3.0`: `2.3.0-pb.1`
  - another fork-only release still based on upstream `2.3.0`: `2.3.0-pb.2`
  - first fork release after pulling upstream `2.3.1`: `2.3.1-pb.1`
- Avoid plain `2.3.1` tags on the fork, because those are ambiguous with upstream.

## Checklist

1. Confirm the working tree is clean: `git status --short`
2. Confirm remotes:
   - `origin` should be `pixel-boy-org/Highlightr`
   - `upstream` should be `raspu/Highlightr`
3. Fetch everything: `git fetch origin --tags` and `git fetch upstream --tags`
4. If upstream shipped a fix you need, merge or rebase the upstream branch/tag first.
5. Decide the new fork version from the upstream base plus the next `-pb.<n>` suffix.
6. Update `CHANGELOG.md`:
   - add a new release section at the top
   - note the upstream base tag or commit
   - note the bundled `highlight.js` version if it changed
   - call out any Pixel Boy-specific patches
7. Validate the package:
   - `swift build`
   - `swift test`
8. If the release changes syntax assets, fonts, or editor rendering, validate the downstream consumer too:
   - `swift test` in `pixel-boy-editor`
   - run the Pixel Boy editor smoke test in the host app
9. Commit the release prep: `git commit -am "chore: release <version>"`
10. Create an annotated tag: `git tag -a <version> -m "<version>"`
11. Push the branch and tag: `git push origin HEAD` and `git push origin <version>`
12. After the tag is live, update downstream packages when you are ready:
   - bump `pixel-boy-editor` to the new Highlightr tag
   - resolve packages and rerun `swift test`

## Upstream Sync Notes

- Keep the fork delta small. If a fix is generally useful, upstream it when practical.
- When upstream lands a new macOS fix, pull it into this fork, rerun the steps above, and cut a new `-pb.<n>` release.
- If the vendored `highlight.min.js` changes, the file in this repo lives at `src/assets/highlighter/highlight.min.js`.
