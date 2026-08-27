# busyagent image — packaging for the busyagent busybox applet

This repository builds the Docker image for
[busyagent](https://github.com/lloydzhou/busybox) (phase1-single-turn):
a busybox build with a full LLM agent applet, shipped as a `FROM scratch`
single-binary image.

The busybox source tree is **not** part of this repository — it is
downloaded from the upstream fork at build time (`BUSYBOX_REF`), the same
separation docker-library/busybox keeps from busybox.git.

## Build / push (multi-arch)

```bash
docker buildx build --platform linux/amd64,linux/arm64 \
  -t lloydzhou/busyagent:latest -t lloydzhou/busybox:latest --push .
```

## Quick start

```bash
docker run --rm --network host \
  -v busyagent-data:/root/.busyagent \
  -e BB_AGENT_BASE_URL=http://host:8317/v1 \
  -e BB_AGENT_API_KEY=sk-xxx \
  -e BB_AGENT_MODEL=your-model \
  -it lloydzhou/busyagent
```

Interactive REPL (busybox lineedit: UTF-8 input, history, sessions
auto-resume per working directory), or one-shot:

```bash
docker run --rm --network host \
  -e BB_AGENT_BASE_URL=... -e BB_AGENT_API_KEY=... -e BB_AGENT_MODEL=... \
  lloydzhou/busyagent busyagent "why did this build fail"
```

The agent plans, calls busybox applets (`sh`, `grep`, `sed`, `awk`, `find`,
`od`, `ps`, ...), feeds results back and iterates until done. Background
tasks push their exit code and output back into the session when they
finish. Sessions and the full event trace live in `/root/.busyagent`
(declared `VOLUME`) — mount it to keep them across containers.

## Environment variables

| Variable | Description |
|---|---|
| `BB_AGENT_BASE_URL` | LLM API endpoint (OpenAI-compatible `/v1`; claude / responses protocols also supported) |
| `BB_AGENT_API_KEY`  | API key |
| `BB_AGENT_MODEL`    | Model name |
| `BB_AGENT_HOME`     | Session/history storage dir (defaults to `/root/.busyagent` in this image) |
| `BB_AGENT_OUTPUT`   | `text` (default) / `json` (stream-json for programmatic use) |

## Image facts

- `FROM scratch`; fully static musl binary, no libc dependency
- ~1.34MB binary, 409 applet links (incl. `busyagent`)
- Full CJK codepoint tables + wide-char widths (REPL takes Chinese input)
- Config: `make defconfig` in the image build plus four pins
  (`CONFIG_STATIC`, `LAST_SUPPORTED_WCHAR=1114111`, `UNICODE_WIDE_WCHARS`,
  `CONFIG_BUSYAGENT`); TC disabled for current alpine headers

## Limitations

- HTTP only for now (TLS via busybox's built-in `tls.c` is planned); put an
  internal gateway in front of public LLM APIs and point the device at it
- Requires an OpenAI-compatible endpoint
