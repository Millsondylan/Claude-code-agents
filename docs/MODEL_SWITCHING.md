# Model Switching (Opus/Sonnet/Kimi in one Claude session)

This setup uses a unified local router so one `claude` process can use `/model` to switch between:

- `claude-opus-4-6`
- `claude-sonnet-4-6`
- `moonshotai/kimi-k2.5`

No process restart is required after launch (as long as you launched with the wrapper below).

## Architecture

- Claude CLI sends all requests to local router: `http://127.0.0.1:3001`
- Router forwards by selected model:
  - Claude models -> Anthropic API (using your normal Claude auth)
  - Kimi model -> local NVIDIA proxy on `127.0.0.1:3002`
- NVIDIA proxy forwards to NVIDIA with `NVIDIA_API_KEY`

## Files

- `model-switch/switcher.zsh` - shell wrapper + commands
- `model-switch/router-proxy/main.go` - unified model router
- `model-switch/build-router.sh` - builds `claude-model-router`
- `model-switch/generate-proxy-config.sh` - writes NVIDIA proxy config
- `model-switch/.env.example` - template
- `model-switch/.env.local` - local secrets (gitignored)

## Setup per device

```bash
cd ~/Documents/claude-agents/Claude-code-agents
./model-switch/install.sh
source ~/.zshrc
```

Then edit `model-switch/.env.local` and set `NVIDIA_API_KEY`.

## Daily usage

1. Start Claude normally:

```bash
claude
```

2. Inside Claude, use `/model` and select:
- Opus 4.6
- Sonnet 4.6
- Kimi K2.5 (`claude-kimi-k2-5`, routes internally to `moonshotai/kimi-k2.5`)

The router also follows your current `/model` selection for internal/sub-agent calls:
- If `/model` is Kimi, internal `claude-opus-*`/`claude-sonnet-*` calls are coerced to Kimi.
- If `/model` is Opus/Sonnet, traffic stays on Anthropic (your Claude subscription).

You can also switch from shell:

- `cc-model opus`
- `cc-model sonnet`
- `cc-model kimi`
- `which-model`
- `cc-up` (start/restart local router + NVIDIA proxy)
- `cc-status` (show service status)
- `cc-down` (stop both services)

## Security

- API key is in `model-switch/.env.local` only (gitignored)
- `.env.local` is mode `600`
- Do not commit real keys to tracked files

## Performance tuning

Defaults in `.env.local`:

- `KIMI_MAX_TOKENS=8192`
- `KIMI_DISABLE_THINKING=1`
- `KIMI_SMALLTALK_FAST=0`
- `KIMI_SMALLTALK_MAX_TOKENS=256`
- `TOPIC_DETECT_MODEL=claude-haiku-4-5-20251001`

Why:
- Kimi requests from Claude CLI often ask for very high max tokens (`32000`), which can add substantial latency.
- Disabling Kimi thinking (`chat_template_kwargs.thinking=false`) significantly reduces response time for many prompts.
- Small-talk fast path removes large tool lists for tiny non-coding prompts to reduce latency spikes.
- Claude also sends a background “new topic detection” request; routing that metadata call to Haiku is faster.
- Kimi latency is mostly provider-side on NVIDIA free tier; router/proxy overhead is small.

## Troubleshooting

If Kimi is missing in `/model`, type the exact id:

`claude-kimi-k2-5`

If router/proxy are not running:

```bash
source ~/.zshrc
cc-up
claude
```

This starts both local services and re-applies routing env.
