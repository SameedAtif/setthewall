# API Keys Required to Run the Pipeline

Every key below goes into `.env` (git-ignored). Copy `.env.example` to `.env` first:

```bash
cp .env.example .env
```

The pipeline is deliberately safe with **no keys at all** — the image-generation and Etsy
adapters default to `manual` (write a prompt/payload to `tmp/` and pause for you), and the
LLM steps simply fail cleanly until a provider key is set. Acquire keys in the order below as
you move through the pipeline.

---

## 1. LLM provider — Qwen (configured) or Anthropic/OpenAI — *required for every LLM step*

Used by all classification, synthesis, and copywriting steps (Track A, Track B, C1 prompt
synthesis, P2_3 theme check, P3 title/tags/description, and the module 07 KB-evolution
proposer).

### Qwen (current default)

Qwen is an OpenAI-compatible provider. Set these three variables:

| Variable | Where | Value |
|---|---|---|
| `QWEN_API_KEY` | `.env` | your Qwen (DashScope) API key |
| `QWEN_API_BASE` | `.env` | `https://dashscope-intl.aliyuncs.com/compatible-mode/v1` |
| `QWEN_MODEL` | `.env` | `qwen3.8-max` |

When `QWEN_API_KEY` is set, `config/initializers/ruby_llm.rb` routes the OpenAI provider at
`QWEN_API_BASE`, registers `QWEN_MODEL` in the database model registry, and
`PIPELINE_TEXT_MODEL` / `PIPELINE_VISION_MODEL` both default to `QWEN_MODEL`.

### Anthropic (alternative)

| Variable | Where | How to get it |
|---|---|---|
| `ANTHROPIC_API_KEY` | `.env` | https://console.anthropic.com → API Keys (billing required) |

Optional OpenAI alternative (both may be set; RubyLLM picks per provider):

| Variable | Where | How to get it |
|---|---|---|
| `OPENAI_API_KEY` | `.env` | https://platform.openai.com/api-keys |

> **Model names are config, not keys.** If you switch providers, set real model ids explicitly:
>
> ```bash
> PIPELINE_TEXT_MODEL=...     # text model id
> PIPELINE_VISION_MODEL=...   # must accept image inputs
> ```

---

## 2. Web search — Tavily — *required for Track A (A0 / A1)*

The `Search::ReasonedRunner` in module 00b refuses to answer without a real search, so A0
("validate the style") and A1 ("build a reference set") need a live search API.

| Variable | Where | How to get it |
|---|---|---|
| `TAVILY_API_KEY` | `.env` | https://app.tavily.com (free tier is enough — A0/A1 run per-style, rarely) |

---

## 3. Image generation — Gemini "Nano Banana 2" (current) or Replicate (Flux) — *required for Track C (C1) and P3_1b*

Only needed once you switch `IMAGE_GEN_PROVIDER` from `manual`. Until then the manual adapter
writes the prompt to `tmp/manual_gen_prompts/` and waits for you to paste a URL.

### Gemini — "Nano Banana 2" (configured default)

| Variable | Where | Value |
|---|---|---|
| `IMAGE_GEN_PROVIDER` | `.env` | `gemini` |
| `GEMINI_API_KEY` | `.env` | Gemini API key (with billing enabled — image models are not on the free tier) |
| `GEMINI_API_BASE` | `.env` | `https://generativelanguage.googleapis.com/v1beta` |
| `GEMINI_IMAGE_MODEL` | `.env` | `gemini-3.1-flash-image` ("Nano Banana 2") |
| `GEMINI_COST_PER_IMAGE` | `.env` | cost-tracking constant, default `0.04` |

### Replicate — Flux (alternative)

| Variable | Where | How to get it |
|---|---|---|
| `IMAGE_GEN_PROVIDER` | `.env` | set to `replicate` (`manual` is the safe default) |
| `REPLICATE_API_KEY` | `.env` | https://replicate.com/account/api-tokens |
| `REPLICATE_MODEL_SLUG` | `.env` | default `black-forest-labs/flux-1.1-pro` — verify current slug on Replicate |
| `REPLICATE_COST_PER_IMAGE` | `.env` | cost-tracking constant, default `0.04` |

---

## 4. Etsy — Open API v3 — *required for listing publish (P3_8) and stats (module 07)*

Only needed once you switch `ETSY_ADAPTER` from `manual` to `api`. Until then the manual
adapter writes the full listing payload to `tmp/manual_etsy_payloads/` for you to publish by hand.

| Variable | Where | How to get it |
|---|---|---|
| `ETSY_ADAPTER` | `.env` | set to `api` when ready (`manual` is the safe default) |
| `ETSY_API_KEY` | `.env` | https://www.etsy.com/developers → create an app (the "keystring") |
| `ETSY_API_SECRET` | `.env` | the app's shared secret (used in the OAuth 2.0 flow) |
| `ETSY_OAUTH_TOKEN` | `.env` | access token from Etsy's OAuth 2.0 authorization-code flow |
| `ETSY_SHOP_ID` | `.env` | numeric shop id, from Shop Manager → Settings → Info & Appearance |

The OAuth token needs the `listings_w` scope (to create listings) and `listings_r` /
`shops_r` (to read the taxonomy + stats). Verify current endpoints/scopes against
https://developers.etsy.com before going live — the Etsy API changes without notice
(these rules are tagged `volatility: live` in the knowledge base).

---

## 5. Optional / unused

| Variable | Notes |
|---|---|
| `IMAGE_GEN_API_KEY` | Listed in module 00's `.env` template but not read by any adapter — the Replicate adapter uses `REPLICATE_API_KEY` instead. Leave blank. |

---

## Quick-start order

1. `QWEN_API_KEY` + `QWEN_API_BASE` + `QWEN_MODEL` — unlocks Track A/B and all copywriting (already configured).
2. `TAVILY_API_KEY` — unlocks the live research steps (A0/A1).
3. `GEMINI_API_KEY` + `IMAGE_GEN_PROVIDER=gemini` — unlocks real image generation (C1/P3_1b).
4. `ETSY_API_KEY` / `ETSY_API_SECRET` / `ETSY_OAUTH_TOKEN` / `ETSY_SHOP_ID` + `ETSY_ADAPTER=api` — unlocks real publish (P3_8) and stats (module 07).

Run `bash tools/scripts/doctor.sh` (or `mise run validate:doctor`) to see at a glance which
keys are still blank.
