# busyagent image — packaging for the busyagent BusyBox applet

This repository builds the Docker image for
[busyagent](https://github.com/lloydzhou/busyagent): a BusyBox build with a
full LLM agent applet, shipped as a `FROM scratch` single-binary image.

The BusyBox + busyagent source tree is pinned by the `busybox` Git submodule.
Updating that pointer releases a new source revision without fetching a remote
tarball during the image build.

## Build / push (multi-arch)

```bash
git submodule update --init
docker buildx build --platform linux/amd64,linux/arm64 \
  -t lloydzhou/busyagent:latest -t lloydzhou/busybox:latest --push .
```

## Quick start

```bash
docker run --rm --network host \
  -v busyagent-data:/root/.busyagent \
  -e BA_BASE_URL=https://api.example.com/v1 \
  -e BA_API_KEY=sk-xxx \
  -e BA_MODEL=your-model \
  -it lloydzhou/busyagent
```

Interactive REPL (BusyBox lineedit: UTF-8 input, history, sessions
auto-resume per working directory), or one-shot:

```bash
docker run --rm --network host \
  -e BA_BASE_URL=... -e BA_API_KEY=... -e BA_MODEL=... \
  lloydzhou/busyagent busyagent "why did this build fail"
```

The agent plans, calls BusyBox applets (`sh`, `grep`, `sed`, `awk`, `find`,
`od`, `ps`, ...), feeds results back and iterates until done. Background
tasks push their exit code and output back into the session when they
finish. Sessions and the full event trace live in `/root/.busyagent`
(declared `VOLUME`) — mount it to keep them across containers.

## Environment variables

| Variable | Description |
|---|---|
| `BA_BASE_URL` | LLM API endpoint using `http://` or `https://` |
| `BA_API_KEY` | API key |
| `BA_MODEL` | Model name |
| `BA_PROVIDER` | API protocol: `openai` (default), `claude`, or `responses` |
| `BA_HOME` | Session/history storage directory (defaults to `/root/.busyagent` in this image) |
| `BA_OUTPUT` | Output format: `text` (default) or `json` (stream JSON for programmatic use) |
| `BA_EFFORT` | Thinking effort: `minimal`, `low`, `medium`, `high`, `xhigh`, or `max` |

Command-line flags override the corresponding environment variables; run
`busyagent --help` for details.

## Image facts

- `FROM scratch`; fully static musl binary, no libc dependency
- Single BusyBox binary with the `busyagent` applet and standard applet links
- Full CJK codepoint tables + wide-character widths (REPL accepts Chinese input)
- Supports plain HTTP and built-in TLS transport for HTTPS endpoints
- Config: `make defconfig` in the image build plus four pins
  (`CONFIG_STATIC`, `LAST_SUPPORTED_WCHAR=1114111`, `UNICODE_WIDE_WCHARS`,
  `CONFIG_BUSYAGENT`); TC disabled for current Alpine headers

## Security limitations

The built-in TLS client encrypts HTTPS transport but does **not** verify the
server certificate chain, certificate validity period, hostname, handshake
signature, Finished message, or record integrity. `busyagent` prints a warning
when HTTPS is used. A network attacker may therefore impersonate the endpoint.
Use HTTPS only on a trusted network, or connect through a trusted TLS-terminating
gateway that performs full server authentication.
