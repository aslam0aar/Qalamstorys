# QalamStorys

Motivational story and card-deck reading app by @explainit.simply. Live at https://qalamstorys.netlify.app

- `index.html`: the whole app (React + htm from CDNs, no build step).
- `img/<deck>/NN.jpg`: blog card-deck images, referenced from the `BLOGS` list in index.html.
- `supabase/supabase-setup.sql`: Circle backend (already applied to the project; don't re-run).
- `netlify.toml`: Netlify publishes the repo root as-is.

## Publishing
Every push to `main` deploys to qalamstorys.netlify.app automatically. Pull requests get a Netlify preview link first.

## Adding a card deck
1. Add the images as `img/<slug>/01.jpg`, `02.jpg`, ...
2. Add an entry to `BLOGS` in index.html with a higher `added` number than the current max (blogs sort newest first).
3. Open a pull request, check the preview, merge.
