name: Update pw-silhouettes spritesheet

# Keeps pw-silhouettes/spritesheet.png + spritesheet.json current with the latest
# plane-watch/pw-silhouettes release, without ever needing the browser to fetch them
# (GitHub sends no Access-Control-Allow-Origin on release assets, so that path is
# blocked by CORS - see the comment above PW_SPRITESHEET_PNG_PATH in index.html).
# This runs update-pw-silhouettes.sh inside GitHub's own runner instead: that's a
# server-to-server curl, which isn't subject to CORS at all, and if the sheet
# actually changed it commits the update straight back into this repo - which is
# what makes GitHub Pages pick it up and redeploy.

on:
  schedule:
    # Weekly, Sunday 03:17 UTC - not on the hour, so it doesn't pile up with the herd
    # of jobs everyone else schedules for :00. Adjust to taste.
    - cron: '17 3 * * 0'
  # Lets you trigger a refresh on demand from the Actions tab instead of waiting for
  # the schedule - handy right after this workflow is first added, or after a new
  # pw-silhouettes release you want immediately.
  workflow_dispatch: {}

permissions:
  # Needed so the final step can push the commit back to this repo. If your org has
  # tightened the default GITHUB_TOKEN permissions, this line is what overrides that
  # for this workflow specifically - no separate PAT/secret required.
  contents: write

jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v5

      - name: Fetch latest pw-silhouettes release
        # Invoked via `bash` rather than `./update-pw-silhouettes.sh` - if this file's
        # executable bit gets dropped (e.g. by a web upload or a checkout that doesn't
        # preserve Unix file modes), running it as `./script.sh` fails with exit code 126
        # ("permission denied") even though the file's contents are fine. `bash script.sh`
        # doesn't need the exec bit at all, so it works either way.
        run: bash update-pw-silhouettes.sh

      - name: Commit and push if the sheet changed
        run: |
          if git diff --quiet -- pw-silhouettes/; then
            echo "Already up to date - nothing to commit."
            exit 0
          fi
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git add pw-silhouettes/spritesheet.png pw-silhouettes/spritesheet.json
          git commit -m "chore: update pw-silhouettes spritesheet"
          git push
