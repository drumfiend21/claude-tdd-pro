# TUI visualization layer

Per architecture §16 X-5: charm.sh-style interactive views for the
text-heavy commands. Default output remains markdown; `--tui` opts into
the interactive surface.

## Frameworks

- [bubbletea](https://github.com/charmbracelet/bubbletea) — the Elm-style
  TUI runtime under the charm.sh umbrella; powers all interactive views.
- [huh](https://github.com/charmbracelet/huh) — form/list/select primitives
  for operator confirmation prompts inside TUI views.
- [lipgloss](https://github.com/charmbracelet/lipgloss) — styling.

## Surfaces

| Command | TUI invocation |
|---|---|
| `/space-report` | `space-report --tui` |
| `/coverage` | `coverage --tui` |
| `/audit-pack` | `audit-pack --tui` |

## Graceful degradation

In non-TTY environments (CI, redirected stdout) the `--tui` flag is
honored as a request and falls back to markdown automatically; the
command emits `tty_unavailable fallback=markdown` to stderr so the
caller can detect and adapt.

## Keys

Standard convention: `q` exits cleanly, `?` shows help, `enter` selects.
