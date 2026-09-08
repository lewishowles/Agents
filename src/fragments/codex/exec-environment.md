## Codex exec environment

The `exec` tool runs each command through a small JavaScript wrapper. Knowing what that context does and does not provide avoids a class of retry loops.

- The wrapper's JavaScript context is minimal Node: there is no `btoa`, `atob`, `TextEncoder`, `TextDecoder`, `fetch`, or DOM global. For base64 and other encoding, run the shell tool (`base64`, `openssl`, `xxd`) rather than reaching for a browser API; if you stay in JavaScript, `Buffer.from(text).toString("base64")` is the Node equivalent.
- Keep the `cmd` string simple. For any command containing quotes, `$(...)`, backticks, or `!`, write the command to a script file with a heredoc and run that file, rather than escaping it inside the JavaScript string literal.
