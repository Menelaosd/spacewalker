# PixelLab API — Reference (Spacewalker)

Compiled reference for the PixelLab v2 API — every capability, params, sync/async, limits.
Authoritative source: the OpenAPI schema (`scratchpad/pixellab_openapi.json`); the marketing page (https://www.pixellab.ai/pixellab-api) only adds pricing/prose. Where something is inferred from our own use it's marked *(inferred)*.

## Conventions (apply to every endpoint)

- **Base URL:** `https://api.pixellab.ai/v2` — all paths below are relative to it.
- **Auth:** `Authorization: Bearer <API_TOKEN>` on every request (token from https://pixellab.ai/account). Missing/bad → `401`. Keep the token OUT of the repo (we store it in the session scratchpad `.pixellab_key`).
- **Body:** `POST`, `application/json`, `additionalProperties:false` (unknown keys rejected).
- **`Base64Image` object** (used for every image in/out): `{ "type":"base64" (default), "base64":"<data>" (required), "format":"png" (default) }`. `base64` accepts a raw string or a `data:image/png;base64,...` URI.
- **`Usage` object** (on most responses): `{ "type":"usd"|"generations", "usd":num|null, "generations":num|null }`.
- **Sync vs async:** sync endpoints return the image(s) inline in the `200`. Async endpoints return `{ background_job_id, status:"processing" }` — poll `GET /background-jobs/{id}` every 5–10 s until `status=="completed"`, then read `last_response` (image jobs → `last_response.images[]`; character jobs → id fields).

## Auth, jobs, limits & errors

- **`GET /background-jobs/{id}`** → `{ id, status, created_at, last_response, usage }`. `status` ∈ `processing|completed|failed`. `404` if not yours; jobs auto-clean after completion.
- **`GET /balance`** → `{ credits:{type:"usd",usd}, subscription:{status,plan,generations,total} }`.
- **Error codes:** `202` accepted(async) · `400` bad request · `401` bad token · `402` out of credits/generations · `403` not your resource · `409` direction already animated (use `replace_existing`) · `422` validation · `423` locked/still generating (keep polling) · **`429` concurrency/rate limit** · **`529` rate limit exceeded / overloaded**. No `503`, no numeric cap, no `Retry-After` header documented.
- **Concurrency + backoff *(inferred — we hit 429/529 hard at ~24 concurrent)*:** cap in-flight jobs to **4–6** (worker pool); jitter polls (~6 s ± rand); on `429` exponential backoff from ~2 s (cap ~30–60 s); on `529` back off longer (~5–10 s start) and cut total request rate; on `402` stop (top up balance); on `423` keep polling, don't resubmit; cap retries ~5–6 then fail cleanly.

---

## 1. Text → Image

| Endpoint | Mode | Max size | Notes |
|---|---|---|---|
| `POST /create-image-pixflux` | **sync** | 16–**400** | default text→image; init_image, color_image, style knobs |
| `POST /create-image-pixflux-background` | **async** | 16–400 | identical body to pixflux, non-blocking |
| `POST /create-image-pixen` | **sync** | area ≤512×512, w/h ÷4 | `enhance_prompt`; no shading/init/color_image |
| `POST /generate-image-v2` (Pro) | **async** | ~512² sq / 688×384 16:9 | reference_images (≤4), style_image; returns a GRID (small sizes → many images) |

**pixflux / pixflux-background body** — required `description`, `image_size{width,height}`. Optional: `text_guidance_scale`(1–20, def 8), `outline`, `shading`, `detail`, `view`, `direction`, `isometric`(bool), `no_background`(bool), `background_removal_task`(`remove_simple_background`|`remove_complex_background`), `init_image`(Base64Image), `init_image_strength`(1–999, def 300), `color_image`(Base64Image — forced palette), `seed`. Response sync: `image.base64`; async: `last_response.image.base64`.

**pixen body** — required `description`, `image_size` (÷4, ≤512²). Optional `outline`, `detail`(def `highly detailed`), `view`, `direction`, `no_background`, `enhance_prompt`(bool → richer prompt, +~0.05 gen, echoed in `enhanced_prompt`), `seed`.

**generate-image-v2 body** — required `description`(1–2000), `image_size`. Optional `seed`, `no_background`(def true), `reference_images[]`(≤4 `{image,size,usage_description?}`), `style_image`, `style_options{color_palette,outline,detail,shading}` (all bool, def true).

---

## 2. Style-guided generation

| Endpoint | Mode | Max size | Style input |
|---|---|---|---|
| `POST /create-image-bitforge` | **sync** | 16–**200** | single `style_image` + `style_strength` 0–100 (**def 0** — raise it!) |
| `POST /generate-with-style-v2` (Pro) | **async** | 16–**512** | 1–4 `style_images` (each needs `width`/`height` 1–512) + `style_description`(≤500); no strength knob |

**bitforge** — required `description`, `image_size`(16–200). Style: `style_image`, `style_strength`(0–100, def 0, 50=balanced), `text_guidance_scale`(1–20, def 8). Also `color_image`(forced palette), `init_image`+`init_image_strength`, inpainting (`inpainting_image`,`mask_image`), `coverage_percentage`, `skeleton_keypoints`+`skeleton_guidance_scale`, outline/shading/detail/view/direction/isometric/oblique, `no_background`, `seed`. Response: `image.base64`.
**Gotcha:** bitforge biases HARD toward the style image's palette (this is why our NPC gens locked onto VEGA's blue/gold). Counter with an explicit `color_image` and/or moderate `style_strength`. `style_image` has NO width/height fields → no dimension-match requirement here (that constraint was our earlier misdiagnosis; it applies to endpoints whose style/reference images are dimensioned objects, e.g. generate-with-style-v2 / generate-image-v2).

---

## 3. Image → pixelart

| Endpoint | Mode | Sizing | Style control |
|---|---|---|---|
| `POST /image-to-pixelart` | **sync** | input 16–1280; `output_size` 16–**320** (both required) | `text_guidance_scale`(1–20, def 8) |
| `POST /image-to-pixelart-pro` | **async** | auto-detects native scale (>2048px input downscaled); no size params | `description`(≤2000) free-text |

Both take `image`(Base64Image) + `seed`. Base returns `image.base64`; pro polls → `last_response`.

---

## 4. Text animation

| Endpoint | Mode | Size | Frames |
|---|---|---|---|
| `POST /animate-with-text-v3` **(use this)** | **async** | `first_frame`/`last_frame` max **256×256** | `frame_count` 4–16 EVEN (def 8) |
| `POST /animate-with-text-v2` (Pro) | **async** | 32–256 | fixed by size (32/64→16, 128/170/256→4) |
| `POST /animate-with-text` (v1) | **sync** | fixed 64×64 | model makes 4 |

**v3 body** — required `first_frame`(Base64Image), `action`(1–1000). Optional `last_frame`(guides motion/interpolation), `frame_count`(4–16 even, def 8), `seed`, `no_background`, `enhance_prompt`. **Pixel budget: `w×h×frame_count ≤ 524,288`** → at 256×256 the max is **8 frames** (that's the "max 14/16" error we hit on the keyed astronaut — a 256-wide image caps frames). Poll → `last_response.images[]`. **v3 echoes the reference as frame 0** (so N frames = ref + N-1 generated). Our proven recipe: pass `first_frame == last_frame` as a pose anchor to stop head/limb drift.

---

## 5. Skeleton & character animation

**Character pipeline (async, stateful):**
- `POST /create-character-with-4-directions` (and `-8-directions`) — mints a `character_id` + 4 (or 8) facing sprites. Body: `description`, `image_size`(16–128), `template_id`(`mannequin`|`bear`|`cat`|`dog`|`horse`|`lion`), `proportions`(preset/custom), `directions`(optional per-side reference `Base64Image`s, must match `image_size`), style knobs, `color_image`+`force_colors`, `seed`. Returns `character_id` immediately + `background_job_id`.
- `POST /animate-character` — animate that character. `mode`: **template** (named `template_animation_id` e.g. `walk`,`run`,`attack`,`breathing-idle`… — 1 gen/dir, all dirs by default), **v3** (custom `action_description`, `frame_count` 4–16, optional `custom_start_frame`/`end_frame` interpolation — south only by default), **pro** (20–40 gen/dir, sequential). Returns one `background_job_id` per direction.
- `GET /characters/{id}` — fetch finished character: `directions`, `rotation_urls`, `animations[]` → `directions[].frames[]` (public frame URLs). `DELETE` removes it.

**Skeleton animator (sync, stateless):**
- `POST /estimate-skeleton` — `{image}` → `keypoints[]` (`{x,y,label,z_index}`).
- `POST /animate-with-skeleton` — required `image_size`(16–256), `reference_image`, `skeleton_keypoints` (**array of frames, each an array of `Point`**). `Point.label` ∈ 18-value `SkeletonLabel` (NOSE, NECK, RIGHT/LEFT SHOULDER/ELBOW/ARM/HIP/KNEE/LEG, RIGHT/LEFT EYE/EAR). Optional `guidance_scale`(1–20, def 4), view/direction, init_images, inpainting, color_image, seed. Returns `images[]` inline (1 per frame).

---

## 6. Rotation & turnarounds

| Endpoint | Mode | Size | Use |
|---|---|---|---|
| `POST /rotate` | **sync** | 16–200 | one subject → one new angle (`from_direction`→`to_direction`, or `direction_change`/`view_change` degrees) |
| `POST /generate-8-rotations-v3` | **async** | ≤256 | full 8-dir turnaround from a single **south-facing** `first_frame` |
| `POST /generate-8-rotations-v2` (Pro) | **async** | 32–168 | 8-dir with modes `rotate_character`/`create_with_style`(text)/`create_from_concept` |

`rotate` body: `image_size`, `from_image`, `from_view`/`to_view`(`side`|`low top-down`|`high top-down`), `from_direction`/`to_direction`(8 dirs), `image_guidance_scale`(1–20, def 3), init/mask/color_image, seed. v3 body: `first_frame`, `no_background`, `seed`. v2 body: `method`, `image_size`(32–168), `reference_image`|`concept_image`|`description`, `view`, `no_background`, `seed`.

---

## 7. Editing, inpainting & background

| Endpoint | Mode | Note |
|---|---|---|
| `POST /edit-image` | **async** | full re-gen from `description` onto a target canvas; NO mask. `image`,`image_size`(16–400),`description`(≤500),`width`/`height`(16–400),`text_guidance_scale`(1–10, def 8),`color_image`,`no_background`(def true),`seed` |
| `POST /edit-images-v2` (Pro) | **async** | batch; `method` `edit_with_text`(needs `description`) or `edit_with_reference`(needs `reference_image`); `edit_images[]`(1–16); output 32–512; packs frames into a grid at small sizes |
| `POST /remove-background` | **sync** | `image`,`image_size`(1–400),`background_removal_task`(simple/complex),`text`(hint),`seed` → transparent PNG inline |
| `POST /inpaint`, `POST /inpaint-v3` | (separate) | TRUE mask-based inpainting (paint a region, regen only it) — not edit-image |
| `POST /resize` | | clean pixel-art rescale |

---

## 8. UI & font generation (async, Pro)

- `POST /generate-ui-v2` — pixel-art UI elements (buttons, bars, slots, dialogue boxes) from `description`(1–2000). Optional `image_size`(def 256², ≤~512²), `color_palette`(≤200 chars), `concept_image`, `no_background`(def true), `seed`. → `last_response.images[]` (transparent PNGs). **Directly relevant if we ever move the code-drawn UI to sprite assets.**
- `POST /generate-font-pro` — a full styled pixel font from `description` + `weight`(`Bold`|`Regular`). Optional `image_size`(`1K`|`2K`), `glyph_px`(8|16|32|64, def 16), `font_name`, `seed`. → `last_response`: `images[0]` (glyph atlas) + **`ttf_base64`** (a real `.ttf`, importable straight into Godot as a FontFile).

---

## 9. Shared enums & the "which endpoint?" cheat-sheet

**Enums (exact strings):**
- `outline`: `single color black outline` · `single color outline` · `selective outline` · `lineless`
- `shading`: `flat shading` · `basic shading` · `medium shading` · `detailed shading` · `highly detailed shading`
- `detail`: `low detail` · `medium detail` · `highly detailed`  *(character-create uses `high detail`)*
- `view` (CameraView): `side` · `low top-down` · `high top-down`
- `direction`: `north` · `north-east` · `east` · `south-east` · `south` · `south-west` · `west` · `north-west`

**Which endpoint do I use?**
| Goal | Endpoint |
|---|---|
| Sprite from a text prompt | `create-image-pixflux` (≤400) / `create-image-pixen` (larger) |
| Match an existing art style | `create-image-bitforge` + `style_image` (+`color_image` to hold palette) |
| Consistent themed SET | `generate-with-style-v2` (1–4 style refs) |
| Animate a sprite I have | `animate-with-text-v3` (`first_frame`,`action`; anchor with `last_frame`) |
| Rig/template walk-run-attack | character pipeline: `create-character-with-4-directions` → `animate-character` (template) |
| Precise per-frame poses | `estimate-skeleton` → `animate-with-skeleton` |
| Full 8-direction turnaround | `generate-8-rotations-v3` (from south frame) |
| One new angle | `rotate` |
| Convert real art/render to pixels | `image-to-pixelart` / `-pro` |
| Text-edit an image | `edit-image`; mask a region → `inpaint-v3` |
| Strip background | `remove-background` |
| UI kit sprites / a font | `generate-ui-v2` / `generate-font-pro` |

**Rules of thumb:** lock palette with `color_image`; fix `seed` for reproducibility; `no_background:true` for game sprites; for a coherent character make ONE clean south frame then rotate/animate it rather than re-prompting each angle; prefer v3 animation over v1/v2; keep concurrency ≤4–6.
