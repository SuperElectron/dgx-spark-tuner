# Reading vLLM's own recipe for a model

    https://recipes.vllm.ai/<org>/<model>

What the maintainers recommend — as against `arena-recipe.md`, which is what
competitors happened to run. Where the two disagree is the interesting part.

## Read it in the browser

The page is a configurator: hardware, variant, strategy, KV offload, nodes and
features are toggles that **rewrite the emitted serve command**. A text fetch
returns one default and hides the rest.

Toggles are URL params, so navigate rather than click:

    https://recipes.vllm.ai/<org>/<model>?variant=nvfp4&hardware=rtx_5090
      &features=tool_calling,reasoning,spec_decoding,text_only

`get_page_text` returns every hardware section, not just the selected one. The
emitted command is rendered, not article text — screenshot it.

## What to read, and the error each catches

- **Hardware.** GB10 is not listed and likely never will be. Pick the closest
  analogue **by kernel path, not memory size**, and say which axis you chose:
  the page names the kernels vLLM selects per architecture, and that is what
  transfers. Capacity twins with different memory bandwidth do not. **State
  plainly that no throughput number on the page applies to us.**
- **Variant.** The page recommends a checkpoint per goal and publishes the trade
  in measured numbers — footprint against accuracy, KV headroom against draft
  quality. That trade assumes a card. Ask which side of it our box is on before
  inheriting the choice; a build optimised for a 32 GB card is optimising for a
  constraint we do not have.
- **Features.** Each toggle emits a flag. They are how you find dead weight the
  recipe never disables — a multimodal checkpoint served as text, an encoder
  never called. Compare the emitted command against ours field by field.
- **Prerequisites and caveats.** Version pins, flags called "not optional in
  practice", known-issue sections. Stated once, near the top, easy to skip.
- **What the page does not say.** Silence on a knob means the guide supports
  neither side of a later round that tunes it. Record the silence.

## Other sources, in the order they earn their keep

- The **checkpoint's README** — its serve command, version pins, and any eval
  table against the unquantized parent.
- The checkpoint's **`generation_config.json`** — sampling and chat-template
  defaults that silently override vLLM's. Confirm these before writing one into
  an `EXPERIMENT.md` as a suspected defect; the engine logs when it happens.
- The **HF model tree** for the parent — who else quantized it, and whether a
  build suits our constraint better.
- **The engine's own startup log.** Which kernels it actually selected is ground
  truth and outranks every document above, this page included.

## Where it goes

`docs/runtime.md`, beside `model-card.md`. The pinned URL and read date go in
`model-card.md` with the other links; the analysis does not — `SKILL.md` §2
holds that file to links and dates. The page carries its own "Updated" date;
record both.
