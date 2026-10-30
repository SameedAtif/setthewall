# Set The Wall

**An agent-assisted pipeline for designing, placing, and listing wall art.**

Set The Wall turns a style brief into a finished, framed, composited piece and a
search-optimized Etsy listing. The work is broken into explicit pipeline steps with
human review gates, grounded in a version-controlled knowledge base, and driven through a
single-page notebook UI.

---

## What it does

The pipeline is organized into three phases and five tracks:

| Phase | Track | Cadence | Output |
|---|---|---|---|
| **1 — Style & art** | Track A | Per style | A locked style spec: mood, content type, frame form |
| | Track B | Per scene | Per-scene axes: wall condition, furniture weight, room type, shape, space math, color role |
| | Track C | Daily | Generated art, culled to human-selected finalists |
| **2 — Decor & placement** | — | Daily/weekly | Frame, mat, grouping, and a composited lifestyle scene |
| **3 — E-commerce** | Etsy Module 1 | Daily | Title, tags, attributes, description, photos, and a published listing |

Every step is registered in [`config/step_registry.yml`](config/step_registry.yml) with its
ownership level (agent-ready, agent-assisted, or human-only) and execution mechanism. The
pipeline never silently skips a human gate.

### Highlights

- **Notebook UI** — each run is a Jupyter-like page of step cells with prose output,
  inline artifacts, and plain-English feedback that is interpreted into structured decisions.
- **Human-in-the-loop by design** — style locks, finalist picks, frame and placement
  approvals, pricing, and publishing all require a human gate.
- **Grounded knowledge base** — rules, prompts, scene templates, and style specs live under
  [`knowledge_base/`](knowledge_base/) and every rule carries a source and citation.
- **Deterministic where it matters** — placement and compositing math is never delegated to
  an LLM; image models are used only for generation and photoreal finishing.
- **Swappable providers** — OpenAI-compatible Qwen, Anthropic, OpenAI, Gemini/Replicate image
  generation, Tavily search, and Etsy are configured through environment variables.
- **Safe defaults** — image generation and Etsy start in `manual` mode, writing prompts or
  payloads to `tmp/` so the pipeline runs without any external credentials.

---

## Tech stack

| Layer | Technology |
|---|---|
| Runtime | Ruby 3.3.6, Rails 8.0 |
| Database | PostgreSQL (Solid Cache, Queue, and Cable schemas) |
| Frontend | Hotwire (Turbo + Stimulus), Import Maps, Tailwind CSS |
| LLM | RubyLLM with structured response schemas |
| Images | `ruby-vips` for deterministic compositing; Gemini / Replicate adapters |
| Search | Tavily |
| Testing | RSpec, FactoryBot, Capybara, SimpleCov |
| Quality | RuboCop (Omakase), ERB Lint, Brakeman, bundler-audit, gitleaks, shellcheck |
| Deployment | Docker, Kamal, Thruster |

---

## Prerequisites

- **Ruby 3.3.6** — [mise](https://mise.jdx.dev/) is the recommended toolchain manager
- **PostgreSQL** running locally
- **libvips** (required by `ruby-vips`)
- **Google Chrome** (optional, for system specs)

Run `mise run validate:doctor` at any time to diagnose missing tools or API keys.

---

## Getting started

```bash
git clone https://github.com/SameedAtif/setthewall.git
cd setthewall

cp .env.example .env
mise install
mise run setup        # bundle install, prepare databases, install git hooks

bin/dev               # web + Tailwind watcher + Solid Queue worker
```

Open <http://localhost:3000>. The pipeline is usable immediately in manual mode; add
provider keys to `.env` as you enable LLM, image-generation, search, or Etsy steps.

### Configuration

All configuration lives in `.env` (git-ignored). The main groups are:

| Variable(s) | Purpose |
|---|---|
| `QWEN_API_KEY`, `QWEN_API_BASE`, `QWEN_MODEL` | Default OpenAI-compatible LLM provider |
| `ANTHROPIC_API_KEY`, `OPENAI_API_KEY` | Alternative LLM providers |
| `TAVILY_API_KEY` | Live web search for style validation and reference gathering |
| `IMAGE_GEN_PROVIDER`, `GEMINI_API_KEY`, `REPLICATE_API_KEY` | Art generation provider |
| `ETSY_ADAPTER`, `ETSY_API_KEY`, `ETSY_API_SECRET`, `ETSY_OAUTH_TOKEN`, `ETSY_SHOP_ID` | Etsy publishing |

See [`docs/API_KEYS.md`](docs/API_KEYS.md) for acquisition steps, required scopes, and
cost-tracking constants. Never commit `.env` or `config/master.key`.

---

## Running the pipeline

1. Create a run from the notebook home page.
2. Run cells in order, or use **Run to decision** to stop at the next human gate.
3. Review the prose output and artifacts, then approve, edit, reject, or re-run the cell.
4. Re-running a cell marks downstream cells stale; re-run them manually to keep the run coherent.
5. Approving the final dossier commits the run and publishes it through the configured
   Etsy adapter.

---

## Testing and validation

```bash
bundle exec rspec              # unit, integration, and system specs
mise run validate:fast         # pre-push subset (format, lint, security, unit specs)
mise run validate              # full validation chain, mirrors CI
```

The full validation chain includes RuboCop, ERB Lint, Zeitwerk autoload checks, step-registry
parity, knowledge-base integrity, YAML parsing, shell checks, Brakeman, bundler-audit,
gitleaks, actionlint, database checks, a production asset build, and RSpec. CI runs the same
oracle on every push and pull request.

Before running a production pipeline, the knowledge base must be committed — the preflight
check refuses to run against uncommitted rules.

---

## Project structure

```text
app/
  agents/          QA, evidence, placement, and listing agents
  llm/schemas/     Structured response schemas for every LLM step
  services/        Pipeline, workflow, image generation, compositing, Etsy, search
  steps/           Track A/B/C, Phase 2, and Phase 3 step classes
  views/           Notebook UI (runs, run steps, dossier)
config/
  step_registry.yml  Canonical pipeline definition and ownership
  deploy.yml         Kamal deployment template
knowledge_base/    Rules, prompts, scene templates, style specs
phases/            Original phase specifications
docs/              API key guide, UI plans, and design notes
tools/scripts/     Validation, security, and environment checks
```

---

## Documentation

- [`docs/API_KEYS.md`](docs/API_KEYS.md) — credentials and provider setup
- [`docs/notebook-ui-plan.md`](docs/notebook-ui-plan.md) — notebook architecture and scope
- [`knowledge_base/README.md`](knowledge_base/README.md) — editing rules and provenance
- [`phases/`](phases/) — Phase 1, 2, and 3 product specifications

---

## Deployment

The app ships with a Dockerfile and a Kamal configuration. Update `config/deploy.yml` with
your image, servers, registry, proxy host, and database connection, then provision secrets
through `.kamal/secrets`:

```bash
bin/kamal setup
bin/kamal deploy
```

`config/master.key` is intentionally untracked. Supply `RAILS_MASTER_KEY` through your
secret manager or CI environment; never commit it to the repository.
