# External APIs

How Spacewalker talks to third-party services, and where the secrets live.

## Secrets — where keys go (and never go)

- **All keys live in `config/external_apis.conf`** — a simple `KEY=value` file, **gitignored**
  (see `.gitignore`). It is the single, persistent source of truth. Add new providers there.
- **Never commit a key.** This doc and everything tracked in git must stay secret-free.
- Tooling reads a key by name (e.g. `PIXELLAB_API_KEY`). A session copy may be mirrored to
  `scratchpad/.pixellab_key` for local scripts — also gitignored — but the `.conf` is canonical.
- To add a provider: append a `NAME_API_KEY=...` line under its own header in the `.conf`.

Verify a key is ignored before it ever risks a commit:
`git check-ignore config/external_apis.conf` → must print the path.

---

## PixelLab — pixel-art generation & animation

- **Site / dashboard:** https://www.pixellab.ai/  ·  **Base URL:** `https://api.pixellab.ai/v2`
- **Auth:** header `Authorization: Bearer <PIXELLAB_API_KEY>` on every request.
- **Plan:** Tier 3 "Pixel Architect" — generation-quota + USD credits (check `GET /balance`).
- **Docs:** `GET /v2/llms.txt` (LLM-friendly), `GET /v2/openapi.json` (full schema),
  https://api.pixellab.ai/v2/docs (interactive). Official Python/JS SDKs + an MCP server exist.
- **Async pattern:** most generation endpoints return a `background_job_id`; poll
  `GET /background-jobs/{job_id}` until `status == "completed"`, then read the result images.

### Endpoints we currently use
| Endpoint | Sync? | Use in Spacewalker |
|---|---|---|
| `POST /create-image-pixflux` | sync | Generate a single sprite (≤400px). Params: description, image_size{width,height}, no_background, detail, shading, outline, seed, color_image. Returns `image.base64`. |
| `POST /animate-with-text-v3` | async | Idle-loop frames for fabricated devices. first_frame ≤256px, frame_count 4-16 even, budget w×h×frames ≤524288. |
| `POST /remove-background` | sync | Knock out backgrounds. NOTE: has eaten real graphics on station art — prefer `no_background:true` at generation instead. |

### Potentials — endpoints worth leveraging later
- **`/generate-8-rotations-v3`, `/rotate`, `/create-character-v3`** — 8-direction crew /
  ship rotations (walk-cycle + facing without hand-drawing each angle).
- **`/create-tileset`, `/create-tileset-sidescroller`, `/create-isometric-tile`, `/map-objects`** —
  procedural room floors/walls and star-map objects in one consistent style.
- **`/inpaint(-v3)`, `/edit-image(s-v2)`** — surgically fix ONE bad region/frame instead of
  regenerating a whole sprite (e.g. repair a single dissolved animation frame).
- **`/interpolation-v2`, `/edit-animation-v2`** — smooth or retime an existing animation
  (raise frame count / calm motion) rather than re-rolling it from scratch.
- **`/resize`** — clean pixel-art downscale to display size (kills minification shimmer).
- **`/generate-font-pro`** — a bespoke pixel UI font.
- **`/image-to-pixelart(-pro)`, `/generate-with-style-v2`** — convert or style-match external art.
- **`/create-1-direction-object` + `/objects/{id}/animations`** — PixelLab's native top-down
  "object with idle animation" flow; likely steadier for device idles than `animate-with-text`.

### Gotchas
- `remove-background` / `resize`: `image_size` is an OBJECT `{width,height}`.
- Background-node processes in this env die after 1-2 iterations — run generation loops in the
  FOREGROUND with a timeout and skip-existing checks.
- Keep every generated key OUT of the repo; outputs (PNGs) are fine to commit.
