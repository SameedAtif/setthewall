# Knowledge Base

This directory is the live source of truth for every rule the pipeline applies. It is
version-controlled; git history is the audit trail and `git diff` review is the validation gate.

## Editing rules

1. Edit the YAML/Markdown files here directly — never edit generated copies elsewhere.
2. Every rule must carry `meta.source` and `meta.citation`. Uncited rules are not permitted.
3. Commit before running the pipeline. `Workflow::PreflightCheck` will refuse to run a
   production pipeline against uncommitted knowledge-base changes.
4. `docs/source_knowledge_base/` holds untouched copies of the original phase documents.
   They are the provenance trail. Do not edit them; do not read them at runtime.

## Provenance notes

- **Arrangement-book citations carry page numbers.** The source scan has them embedded.
- **Business-strategy citations use chapter titles, not page numbers.** Those source PDFs do
  not expose reliable page numbers. This is a difference in source format, not a lower
  sourcing standard.
- **Page 56 of the arrangement book carries OCR noise.** Any rule tracing to p. 56 should be
  treated as directionally reliable rather than a verbatim quote. Where a rule needed p. 56's
  content, cleaner passages elsewhere in the same book were used instead.
- **Etsy rules (`volatility: live`) describe a system Etsy controls and changes.** Re-verify
  against the current Etsy Seller Handbook periodically. Do not treat them as permanently
  accurate the way the arrangement-book rules can be.
