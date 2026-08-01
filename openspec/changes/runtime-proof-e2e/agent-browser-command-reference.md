# agent-browser Command Reference (verified)

Generated from `agent-browser <cmd> --help` on agent-browser@agent-browser 0.32.2.

This is the AUTHORITATIVE syntax source for this change. The version-matched
core guide (`agent-browser skills get core --full`) is NOT exhaustive — it omits
`diff`, among others. Verify against this file.

---

## `agent-browser open`

```
agent-browser open - Launch the browser, optionally navigate

Usage: agent-browser open [url]

Without a URL, launches the browser but stays on about:blank. This lets
you stage state (network routes, cookies, init scripts) before the first
real navigation — useful for SSR debug, auth setup, and capturing fresh
`react suspense` / `vitals` state without noise from a prior page.

With a URL, launches and navigates. If no protocol is provided, https://
is automatically prepended.

The `goto` and `navigate` aliases still require a URL.

Global Options:
  --json               Output as JSON
  --session <name>     Use specific session
  --headers <json>     Set HTTP headers (scoped to this origin)
  --headed             Show browser window
  --enable react-devtools   Inject the React DevTools hook before any page JS
  --init-script <path>      Register a page init script (repeatable)

Examples:
  agent-browser open                     # Launch, no nav
  agent-browser open example.com
  agent-browser open https://github.com
  agent-browser open localhost:3000
  agent-browser open api.example.com --headers '{"Authorization": "Bearer token"}'
    # ^ Headers only sent to api.example.com, not other domains

  # Pre-navigation setup in one turn:
  agent-browser batch \
    '["open"]' \
    '["network","route","*","--abort","--resource-type","script"]' \
    '["navigate","http://localhost:3000/target"]'
```

---

## `agent-browser wait`

```
agent-browser wait - Wait for condition

Usage: agent-browser wait <selector|ms|option>

Waits for an element to appear, a timeout, or other conditions.

Modes:
  <selector>           Wait for element to appear
  <ms>                 Wait for specified milliseconds
  --url <pattern>      Wait for URL to match pattern
  --load <state>       Wait for load state (load, domcontentloaded, networkidle)
  --fn <expression>    Wait for JavaScript expression to be truthy
  --text <text>        Wait for text to appear on page (substring match)
  --download [path]    Wait for a download to complete (optionally save to path)

Download Options (with --download):
  --timeout <ms>       Timeout in milliseconds for download to start

Wait for text to disappear:
  Use --fn or --state hidden to wait for text or elements to go away:
  wait --fn "!document.body.innerText.includes('Loading...')"
  wait "#spinner" --state hidden
  wait @e5 --state detached

Global Options:
  --json               Output as JSON
  --session <name>     Use specific session

Examples:
  agent-browser wait "#loading-spinner"
  agent-browser wait 2000
  agent-browser wait --url "**/dashboard"
  agent-browser wait --load networkidle
  agent-browser wait --fn "window.appReady === true"
  agent-browser wait --text "Welcome back"
  agent-browser wait --download ./file.pdf
  agent-browser wait --download ./report.xlsx --timeout 30000
  agent-browser wait --fn "!document.body.innerText.includes('Loading...')"
```

---

## `agent-browser click`

```
agent-browser click - Click an element

Usage: agent-browser click <selector> [--new-tab]

Clicks on the specified element. The selector can be a CSS selector,
XPath, or an element reference from snapshot (e.g., @e1).

If another element covers the click point, agent-browser reports the
covering element instead of dispatching a click to the wrong target.

Options:
  --new-tab            Open link in a new tab instead of navigating current tab
                       (only works on elements with href attribute)

Global Options:
  --json               Output as JSON
  --session <name>     Use specific session

Examples:
  agent-browser click "#submit-button"
  agent-browser click @e1
  agent-browser click "button.primary"
  agent-browser click "//button[@type='submit']"
  agent-browser click @e3 --new-tab
```

---

## `agent-browser fill`

```
agent-browser fill - Clear and fill an input field

Usage: agent-browser fill <selector> <text>

Clears the input field and fills it with the specified text.
This replaces any existing content in the field.

Global Options:
  --json               Output as JSON
  --session <name>     Use specific session

Examples:
  agent-browser fill "#email" "user@example.com"
  agent-browser fill @e3 "Hello World"
  agent-browser fill "input[name='search']" "query"
```

---

## `agent-browser find`

```
agent-browser find - Find and interact with elements by locator

Usage: agent-browser find <locator> <value> [action] [text]

Finds elements using semantic locators and optionally performs an action.

Locators:
  role <role>              Find by ARIA role (--name <n>, --exact)
  text <text>              Find by text content (--exact)
  label <label>            Find by associated label (--exact)
  placeholder <text>       Find by placeholder text (--exact)
  alt <text>               Find by alt text (--exact)
  title <text>             Find by title attribute (--exact)
  testid <id>              Find by data-testid attribute
  first <selector>         First matching element
  last <selector>          Last matching element
  nth <index> <selector>   Nth matching element (0-based)

Actions (default: click):
  click, fill, type, hover, focus, check, uncheck

Options:
  --name <name>        Filter role by accessible name
  --exact              Require exact text match

Global Options:
  --json               Output as JSON
  --session <name>     Use specific session

Examples:
  agent-browser find role button click --name Submit
  agent-browser find text "Sign In" click
  agent-browser find label "Email" fill "user@example.com"
  agent-browser find placeholder "Search..." type "query"
  agent-browser find testid "login-form" click
  agent-browser find first "li.item" click
  agent-browser find nth 2 ".card" hover
```

---

## `agent-browser get`

```
agent-browser get - Retrieve information from elements or page

Usage: agent-browser get <subcommand> [args]

Retrieves various types of information from elements or the page.

Subcommands:
  text <selector>            Get text content of element
  html <selector>            Get inner HTML of element
  value <selector>           Get value of input element
  attr <selector> <name>     Get attribute value
  title                      Get page title
  url                        Get current URL
  count <selector>           Count matching elements
  box <selector>             Get bounding box (x, y, width, height)
  styles <selector>          Get computed styles of elements
  cdp-url                    Get Chrome DevTools Protocol WebSocket URL

Global Options:
  --json               Output as JSON
  --session <name>     Use specific session

Examples:
  agent-browser get text @e1
  agent-browser get html "#content"
  agent-browser get value "#email-input"
  agent-browser get attr "#link" href
  agent-browser get title
  agent-browser get url
  agent-browser get count "li.item"
  agent-browser get box "#header"
  agent-browser get styles "button"
  agent-browser get styles @e1
```

---

## `agent-browser is`

```
agent-browser is - Check element state

Usage: agent-browser is <subcommand> <selector>

Checks the state of an element and returns true/false.

Subcommands:
  visible <selector>   Check if element is visible
  enabled <selector>   Check if element is enabled (not disabled)
  checked <selector>   Check if checkbox/radio is checked

Global Options:
  --json               Output as JSON
  --session <name>     Use specific session

Examples:
  agent-browser is visible "#modal"
  agent-browser is enabled "#submit-btn"
  agent-browser is checked "#agree-checkbox"
```

---

## `agent-browser snapshot`

```
agent-browser snapshot - Get accessibility tree snapshot

Usage: agent-browser snapshot [options]

Returns an accessibility tree representation of the page with element
references (like @e1, @e2) that can be used in subsequent commands.
Designed for AI agents to understand page structure.

Options:
  -i, --interactive    Only include interactive elements
  -u, --urls           Include href URLs for link elements
  -c, --compact        Remove empty structural elements
  -d, --depth <n>      Limit tree depth
  -s, --selector <sel> Scope snapshot to CSS selector

Global Options:
  --json               Output as JSON
  --session <name>     Use specific session

Examples:
  agent-browser snapshot
  agent-browser snapshot -i
  agent-browser snapshot -i --urls
  agent-browser snapshot --compact --depth 5
  agent-browser snapshot -s "#main-content"
```

---

## `agent-browser screenshot`

```
agent-browser screenshot - Take a screenshot

Usage: agent-browser screenshot [selector] [path]

Captures a screenshot of the current page. If no path is provided,
saves to a temporary directory with a generated filename.
Headless Chromium screenshots hide native scrollbars for consistent image output.
Pass --hide-scrollbars false when launching to keep native scrollbars visible.

Options:
  --full, -f           Capture full page (not just viewport)
  --annotate           Overlay numbered labels on interactive elements.
                       Each label [N] corresponds to ref @eN from snapshot.
                       Prints a legend mapping labels to element roles/names.
                       With --json, annotations are included in the response.
                       Supported on Chromium and Lightpanda.
  --screenshot-dir <path>  Default output directory for screenshots
                       (or AGENT_BROWSER_SCREENSHOT_DIR env)
  --screenshot-quality <0-100>  JPEG quality (0-100, only applies to jpeg format)
                       (or AGENT_BROWSER_SCREENSHOT_QUALITY env)
  --screenshot-format <fmt>  Image format: png (default) or jpeg
                       (or AGENT_BROWSER_SCREENSHOT_FORMAT env)

Global Options:
  --json               Output as JSON
  --session <name>     Use specific session

Examples:
  agent-browser screenshot
  agent-browser screenshot ./screenshot.png
  agent-browser screenshot --full ./full-page.png
  agent-browser screenshot --annotate              # Labeled screenshot + legend
  agent-browser screenshot --annotate ./page.png   # Save annotated screenshot
  agent-browser screenshot --annotate --json       # JSON output with annotations
  agent-browser screenshot --screenshot-dir ./shots # Save to custom directory
  agent-browser screenshot --screenshot-format jpeg --screenshot-quality 80
```

---

## `agent-browser eval`

```
agent-browser eval - Execute JavaScript

Usage: agent-browser eval [options] <script>

Executes JavaScript code in the browser context and returns the result.

Options:
  -b, --base64         Decode script from base64 (avoids shell escaping issues)
  --stdin              Read script from stdin (useful for heredocs/multiline)

Global Options:
  --json               Output as JSON
  --session <name>     Use specific session

Examples:
  agent-browser eval "document.title"
  agent-browser eval "window.location.href"
  agent-browser eval "document.querySelectorAll('a').length"
  agent-browser eval -b "ZG9jdW1lbnQudGl0bGU="

  # Read from stdin with heredoc
  cat <<'EOF' | agent-browser eval --stdin
  const links = document.querySelectorAll('a');
  links.length;
  EOF
```

---

## `agent-browser network`

```
agent-browser network - Network interception and monitoring

Usage: agent-browser network <subcommand> [args]

Intercept, mock, or monitor network requests.

Subcommands:
  route <url> [options]      Intercept requests matching URL pattern
    --abort                  Abort matching requests
    --body <json>            Respond with custom body
  unroute [url]              Remove route (all if no URL)
  requests [options]         List captured requests
    --clear                  Clear request log
    --filter <pattern>       Filter by URL pattern
    --type <types>           Filter by resource type (comma-separated: xhr,fetch,document)
    --method <method>        Filter by HTTP method (GET, POST, etc.)
    --status <code>          Filter by status (200, 2xx, 400-499)
  request <requestId>        View full request/response detail (including body)
  har <start|stop> [path]    Record and export a HAR file

Global Options:
  --json               Output as JSON
  --session <name>     Use specific session

Examples:
  agent-browser network route "**/api/*" --abort
  agent-browser network route "**/data.json" --body '{"mock": true}'
  agent-browser network unroute
  agent-browser network requests
  agent-browser network requests --filter "api"
  agent-browser network requests --type xhr,fetch
  agent-browser network requests --method POST --status 2xx
  agent-browser network requests --clear
  agent-browser network request 1234.5
  agent-browser network har start
  agent-browser network har stop ./capture.har
```

---

## `agent-browser scroll`

```
agent-browser scroll - Scroll the page

Usage: agent-browser scroll [direction] [amount] [options]

Scrolls the page or a specific element in the specified direction.

Arguments:
  direction            up, down, left, right (default: down)
  amount               Pixels to scroll (default: 300)

Options:
  -s, --selector <sel> CSS selector for a scrollable container

Global Options:
  --json               Output as JSON
  --session <name>     Use specific session

Examples:
  agent-browser scroll
  agent-browser scroll down 500
  agent-browser scroll up 200
  agent-browser scroll left 100
  agent-browser scroll down 500 --selector "div.scroll-container"
```

---

## `agent-browser set`

```
agent-browser set - Configure browser settings

Usage: agent-browser set <setting> [args]

Configures various browser settings and emulation options.

Settings:
  viewport <w> <h> [scale]   Set viewport size (scale = deviceScaleFactor, e.g. 2 for retina)
  device <name>              Emulate device (e.g., "iPhone 12")
  geo <lat> <lng>            Set geolocation
  offline [on|off]           Toggle offline mode
  headers <json>             Set extra HTTP headers
  credentials <user> <pass>  Set HTTP authentication
  media [dark|light]         Set color scheme preference
        [reduced-motion]     Enable reduced motion

Global Options:
  --json               Output as JSON
  --session <name>     Use specific session

Examples:
  agent-browser set viewport 1920 1080
  agent-browser set viewport 1920 1080 2    # 2x retina
  agent-browser set device "iPhone 12"
  agent-browser set geo 37.7749 -122.4194
  agent-browser set offline on
  agent-browser set headers '{"X-Custom": "value"}'
  agent-browser set credentials admin secret123
  agent-browser set media dark
  agent-browser set media light reduced-motion
```

---

## `agent-browser cookies`

```
agent-browser cookies - Manage browser cookies

Usage: agent-browser cookies [operation] [args]

Manage browser cookies for the current context.

Operations:
  get                                Get all cookies (default)
  set <name> <value> [options]       Set a cookie with optional properties
  clear                              Clear all cookies

Cookie Set Options:
  --url <url>                        URL for the cookie (allows setting before page load)
  --domain <domain>                  Cookie domain (e.g., ".example.com")
  --path <path>                      Cookie path (e.g., "/api")
  --httpOnly                         Set HttpOnly flag (prevents JavaScript access)
  --secure                           Set Secure flag (HTTPS only)
  --sameSite <Strict|Lax|None>       SameSite policy
  --expires <timestamp>              Expiration time (Unix timestamp in seconds)

Note: If --url, --domain, and --path are all omitted, the cookie will be set
for the current page URL.

Global Options:
  --json               Output as JSON
  --session <name>     Use specific session

Examples:
  # Simple cookie for current page
  agent-browser cookies set session_id "abc123"

  # Set cookie for a URL before loading it (useful for authentication)
  agent-browser cookies set session_id "abc123" --url https://app.example.com

  # Set secure, httpOnly cookie with domain and path
  agent-browser cookies set auth_token "xyz789" --domain example.com --path /api --httpOnly --secure

  # Set cookie with SameSite policy
  agent-browser cookies set tracking_consent "yes" --sameSite Strict

  # Set cookie with expiration (Unix timestamp)
  agent-browser cookies set temp_token "temp123" --expires 1735689600

  # Get all cookies
  agent-browser cookies
```

---

## `agent-browser storage`

```
agent-browser storage - Manage web storage

Usage: agent-browser storage <type> [operation] [key] [value]

Manage localStorage and sessionStorage.

Types:
  local                localStorage
  session              sessionStorage

Operations:
  get [key]            Get all storage or specific key
  set <key> <value>    Set a key-value pair
  clear                Clear all storage

Global Options:
  --json               Output as JSON
  --session <name>     Use specific session

Examples:
  agent-browser storage local
  agent-browser storage local get authToken
  agent-browser storage local set theme "dark"
  agent-browser storage local clear
  agent-browser storage session get userId
```

---

## `agent-browser diff`

```
agent-browser diff - Compare page states

Subcommands:

  diff snapshot                   Compare current snapshot to last snapshot in session
  diff screenshot --baseline <f>  Visual pixel diff against a baseline image
  diff url <url1> <url2>          Compare two pages

Snapshot Diff:

  Usage: agent-browser diff snapshot [options]

  Options:
    -b, --baseline <file>    Compare against a saved snapshot file
    -s, --selector <sel>     Scope snapshot to a CSS selector or @ref
    -c, --compact            Use compact snapshot format
    -d, --depth <n>          Limit snapshot tree depth

  Without --baseline, compares against the last snapshot taken in this session.

Screenshot Diff:

  Usage: agent-browser diff screenshot --baseline <file> [options]

  Options:
    -b, --baseline <file>    Baseline image to compare against (required)
    -o, --output <file>      Path for the diff image (default: temp dir)
    -t, --threshold <0-1>    Color distance threshold (default: 0.1)
    -s, --selector <sel>     Scope screenshot to element
        --full               Full page screenshot

URL Diff:

  Usage: agent-browser diff url <url1> <url2> [options]

  Options:
    --screenshot             Also compare screenshots (default: snapshot only)
    --full                   Full page screenshots
    --wait-until <strategy>  Navigation wait strategy: load, domcontentloaded, networkidle (default: load)
    -s, --selector <sel>     Scope snapshots to a CSS selector or @ref
    -c, --compact            Use compact snapshot format
    -d, --depth <n>          Limit snapshot tree depth

Global Options:
  --json               Output as JSON
```

---

## `agent-browser console`

```
agent-browser console - View console logs

Usage: agent-browser console [--clear]

View browser console output (log, warn, error, info).

Options:
  --clear              Clear console log buffer

Global Options:
  --json               Output as JSON
  --session <name>     Use specific session

Examples:
  agent-browser console
  agent-browser console --clear
```

---

## `agent-browser errors`

```
agent-browser errors - View page errors

Usage: agent-browser errors [--clear]

View JavaScript errors and uncaught exceptions.

Options:
  --clear              Clear error buffer

Global Options:
  --json               Output as JSON
  --session <name>     Use specific session

Examples:
  agent-browser errors
  agent-browser errors --clear
```

---

## `agent-browser vitals`

```

agent-browser - fast browser automation CLI for AI agents

Usage: agent-browser <command> [args] [options]

Start here (for AI agents):
  agent-browser skills get core --full

  Skills ship with the CLI (always version-matched) and include workflow
  patterns, ref/selector usage, and copy-paste examples. Prefer this over
  guessing commands from flag docs alone. Specialized skills cover Electron
  apps, Slack, exploratory testing, and cloud browser providers.

  skills [list]                List available skills
  skills get core              Core usage guide (overview + common patterns)
  skills get core --full       Include full command reference and templates
  skills get <name>            Load a specialized skill (electron, slack, ...)
  skills path [name]           Print skill directory path

Core Commands:
  open <url>                 Navigate to URL
  read [url]                 Fetch agent-readable text
  click <sel>                Click element (or @ref)
  dblclick <sel>             Double-click element
  type <sel> <text>          Type into element
  fill <sel> <text>          Clear and fill
  press <key>                Press key (Enter, Tab, Control+a)
  keyboard type <text>       Type text with real keystrokes (no selector)
  keyboard inserttext <text> Insert text without key events
  hover <sel>                Hover element
  focus <sel>                Focus element
  check <sel>                Check checkbox
  uncheck <sel>              Uncheck checkbox
  select <sel> <val...>      Select dropdown option
  drag <src> <dst>           Drag and drop
  upload <sel> <files...>    Upload files
  download <sel> <path>      Download file by clicking element
  scroll <dir> [px]          Scroll (up/down/left/right)
  scrollintoview <sel>       Scroll element into view
  wait <sel|ms>              Wait for element or time
  screenshot [path]          Take screenshot
  pdf <path>                 Save as PDF
  snapshot                   Accessibility tree with refs (for AI)
  eval <js>                  Run JavaScript
  connect <port|url>         Connect to browser via CDP
```

---

## `agent-browser record`

```
agent-browser record - Record browser session to video

Usage: agent-browser record start <path.webm> [url]
       agent-browser record stop
       agent-browser record restart <path.webm> [url]

Record the browser to a WebM video file.
Creates a fresh browser context but preserves cookies and localStorage.
If no URL is provided, automatically navigates to your current page.

Operations:
  start <path> [url]     Start recording (defaults to current URL if omitted)
  stop                   Stop recording and save video
  restart <path> [url]   Stop current recording (if any) and start a new one

Global Options:
  --json               Output as JSON
  --session <name>     Use specific session

Examples:
  # Record from current page (preserves login state)
  agent-browser open https://app.example.com/dashboard
  agent-browser snapshot -i            # Explore and plan
  agent-browser record start ./demo.webm
  agent-browser click @e3              # Execute planned actions
  agent-browser record stop

  # Or specify a different URL
  agent-browser record start ./demo.webm https://example.com

  # Restart recording with a new file (stops previous, starts new)
  agent-browser record restart ./take2.webm
```

---

## `agent-browser trace`

```
agent-browser trace - Record execution trace

Usage: agent-browser trace start
       agent-browser trace stop [path]

Record a Chrome DevTools trace for debugging.

Operations:
  start                Start recording trace
  stop [path]          Stop recording and save trace

Global Options:
  --json               Output as JSON
  --session <name>     Use specific session

Examples:
  agent-browser trace start
  agent-browser trace stop
  agent-browser trace stop ./debug-trace.json
```

---

## `agent-browser session`

```
agent-browser session - Manage sessions

Usage: agent-browser session [operation]

Manage isolated browser sessions. Each session has its own browser
instance with separate cookies, storage, and state.

Operations:
  (none)               Show current session name
  id                   Generate stable session id (--scope worktree|cwd|git-root, --prefix)
  info                 Show daemon, launch, and restore diagnostics
  list                 List all active sessions

Environment:
  AGENT_BROWSER_SESSION    Default session name
  AGENT_BROWSER_NAMESPACE  Namespace for daemon sockets and restore state

Global Options:
  --json               Output as JSON
  --session <name>     Use specific session
  --namespace <name>   Use specific namespace

Examples:
  agent-browser session
  agent-browser session id --scope worktree --prefix next-dev-loop
  agent-browser session info --json
  agent-browser session list
  agent-browser --session test open example.com
```

---

## `agent-browser doctor`

```
agent-browser doctor - Diagnose and repair your install

Usage: agent-browser doctor [options]

Runs a battery of checks across environment, Chrome install, daemon state,
config files, encryption key, providers, network reachability, and a live
headless browser launch test.

Auto-cleans stale daemon socket/pid/version sidecar files. Destructive
repairs (reinstalling Chrome, purging old state files, generating a missing
encryption key) are gated behind --fix.

Options:
  --offline            Skip network probes
  --quick              Skip the live headless launch test
  --webgpu             Also run a live WebGPU render probe (renders via a real
                       WebGPU pass and pixel-checks both an in-page readback
                       and a decoded screenshot; launches a second Chrome)
  --headed             Run the WebGPU probe headed to validate the capture
                       path (auto-Xvfb on displayless Linux)
  --debug              Verbose diagnostics from the probes' scratch daemons
  --fix                Also run destructive repairs
  --json               JSON output

Exit codes:
  0  All checks pass (warnings OK)
  1  At least one check failed

Examples:
  agent-browser doctor
  agent-browser doctor --offline --quick
  agent-browser doctor --webgpu
  agent-browser doctor --webgpu --headed
  agent-browser doctor --fix
  agent-browser doctor --json
```

---

## `agent-browser read`

```
agent-browser read - Fetch a URL as agent-readable text

Usage: agent-browser read [url] [--raw] [--require-md] [--llms <index|full>] [--outline] [--filter <text>] [--timeout <ms>]

Fetches a URL as agent-readable text. Omit the URL to read the rendered DOM of
the active tab in the current browser session. Explicit URL reads prefer
markdown with Accept: text/markdown, try the same URL with .md appended when
the first response is not markdown, walk ancestor paths toward / to find the
nearest llms.txt for a matching docs link, fall back to plain text or readable
text extracted from HTML, and print only the document content by default.
Use --outline for a compact heading outline of a single page. Use --llms index
or --llms full for nearest-ancestor llms files; with no URL, --llms and
--require-md use the active tab URL because they depend on HTTP resources.

Options:
  --raw                Print the response body without HTML extraction
  --require-md         Fail unless the response is Content-Type: text/markdown
  --llms <index|full>  Print nearest llms.txt links or llms-full.txt
  --outline            Print a heading outline for the selected page
  --filter <text>      Filter page sections, --llms links/sections, or --outline headings
  --timeout <ms>       Request timeout in milliseconds (default: 10000)

Global Options:
  --json               Output metadata and content as JSON
  --headers <json>     Additional HTTP headers, such as Authorization
  --allowed-domains <list>  Restrict read fetches and redirects to allowed domains
  --content-boundaries Wrap read output in boundary markers
  --max-output <chars> Truncate read output to N chars

Examples:
  agent-browser read
  agent-browser read https://docs.example.com/guide
  agent-browser read https://docs.example.com/guide --filter auth
  agent-browser read https://docs.example.com/guide --outline
  agent-browser read https://docs.example.com --llms index --filter auth
  agent-browser read https://docs.example.com --llms full --filter auth
  agent-browser read docs.example.com/guide --require-md
  agent-browser read https://api.example.com/docs --headers '{"Authorization":"Bearer token"}'
```

---

## `agent-browser close`

```
agent-browser close - Close the browser

Usage: agent-browser close [options]

Closes the browser instance for the current session.

Aliases: quit, exit

Options:
  --all                Close all active sessions

Global Options:
  --json               Output as JSON
  --session <name>     Use specific session

Examples:
  agent-browser close
  agent-browser close --session mysession
  agent-browser close --all
```


---

## Global flags (precede the subcommand)

Verified via `agent-browser --help`. These are GLOBAL — they go BEFORE the subcommand:
`agent-browser --session "$S" --restore open <url>`

```
  install                    Install browser binaries
  install --with-deps        Also install system dependencies (Linux)
  upgrade                    Upgrade to the latest version
  doctor [--fix]             Diagnose install; auto-clean stale files
  dashboard start            Start the observability dashboard
  profiles                   List available Chrome profiles

Snapshot Options:
  -i, --interactive          Only interactive elements
  -c, --compact              Remove empty structural elements
  -d, --depth <n>            Limit tree depth
  -s, --selector <sel>       Scope to CSS selector

Authentication:
  --profile <name|path>      Chrome profile name (e.g., Default) to reuse login state,
                             or a directory path for a persistent custom profile
                             (or AGENT_BROWSER_PROFILE env)
  --restore [name]           Auto-save/restore cookies and localStorage.
                             Without a name, uses --session as the restore key
                             (or AGENT_BROWSER_RESTORE env)
  --restore-save <policy>    Restore auto-save policy: auto, always, never (default: auto)
  --restore-check-url <glob> Validate restored state against current URL pattern
  --restore-check-text <txt> Validate restored state against visible page text
  --restore-check-fn <js>    Validate restored state against a truthy JS expression
  --session-name <name>      Legacy alias for restore persistence key
                             (or AGENT_BROWSER_SESSION_NAME env)
  --state <path>             Load saved auth state (cookies + storage) from JSON file
                             (or AGENT_BROWSER_STATE env)
  --auto-connect             Connect to a running Chrome to reuse its auth state
                             Tip: agent-browser --auto-connect state save ./auth.json
  --headers <json>           HTTP headers scoped to URL's origin (e.g., Authorization bearer token)

Options:
  --session <name>           Isolated session (or AGENT_BROWSER_SESSION env)
  --namespace <name>         Isolate daemon sockets and restore-state directories
                             (or AGENT_BROWSER_NAMESPACE env)
  --executable-path <path>   Custom browser executable (or AGENT_BROWSER_EXECUTABLE_PATH)
  --extension <path>         Load browser extensions (repeatable)
  --init-script <path>       Register a page init script before the first navigation (repeatable)
                             (or AGENT_BROWSER_INIT_SCRIPTS env, comma-separated)
  --enable <feature>         Built-in init scripts: react-devtools (repeatable or comma-separated)
                             (or AGENT_BROWSER_ENABLE env)
  --args <args>              Browser launch args, comma or newline separated (or AGENT_BROWSER_ARGS)
                             e.g., --args "--no-sandbox,--disable-blink-features=AutomationControlled"
  --user-agent <ua>          Custom User-Agent (or AGENT_BROWSER_USER_AGENT)
  --proxy <server>           Proxy server URL (or AGENT_BROWSER_PROXY, HTTP_PROXY, HTTPS_PROXY, ALL_PROXY)
```

---

## Commands WITHOUT a dedicated --help page

These fall through to top-level help. Their verified syntax comes from the
top-level help sections, NOT from `<cmd> --help`:

```
Streaming:
  stream enable [--port <n>] Start runtime WebSocket streaming for this session
  stream disable             Stop runtime WebSocket streaming
  stream status              Show streaming status and active port
--
Performance:
  vitals [url] [--json]      Core Web Vitals (LCP/CLS/TTFB/FCP/INP) +
                             React hydration summary; --json returns full data

SPA:
  pushstate <url>            SPA client-side nav. Auto-detects window.next.router.push
                             (triggers RSC fetch on Next.js); falls back to
                             history.pushState + popstate/navigate events for other frameworks
```

- `agent-browser --version` -> `agent-browser 0.32.2` (verified)
- `agent-browser install [--with-deps]` -> downloads browser binaries (verified via `install --help`)
- `back` / `forward` / `reload` -> verified, no arguments
