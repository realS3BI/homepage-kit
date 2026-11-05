# homepage-kit

A template for a small business website that you maintain through chat. You message your OpenClaw on Telegram with what should change. The agent edits the website on your Mac, you see the result right away in a private preview, and when you say so it publishes the site to your server.

The template isn't tied to any industry. It shows placeholder text for a made-up business, and in the first conversation the agent replaces the content and design with your own.

## How it fits together

```
Telegram ──> OpenClaw ──> this repo on the Mac
                              │
                              ├─ Preview: service on the Mac, reachable from phone and laptop via Tailscale
                              │
                              └─ "Publish" ──> VPS with your own domain and HTTPS
```

- **Preview.** macOS starts a dev server at boot and restarts it after every crash. Tailscale makes it reachable at an HTTPS address that only your own devices can open.
- **Watchdog.** OpenClaw checks the preview every five minutes and restarts it if needed.
- **Skill.** OpenClaw gets a skill for this website. You choose its name and the keywords that trigger it.
- **Website.** Static pages built with Astro, in one language or several, with imprint and privacy policy. The template ships with German and English sample content; in onboarding you choose the default language and any translations. No cookies, no third-party services.

## Requirements

A Mac that stays on, for example a Mac mini, with:

- [Homebrew](https://brew.sh) and Node.js 22.23 or later: `brew install node git`
- [Tailscale](https://tailscale.com/download), signed in. In the admin console under DNS, MagicDNS and HTTPS certificates must be enabled.
- OpenClaw, set up with Telegram

Tailscale and OpenClaw are both optional. Without Tailscale the preview only runs on the Mac; without OpenClaw you work with Claude Code or Codex directly in the repo. The rules for all agents are in `AGENTS.md`.

## Setup

1. Open [realS3BI/homepage-kit](https://github.com/realS3BI/homepage-kit), click **Use this template** and create your own private repo.
2. Clone it into `~/Developer`. iCloud syncs the Documents and Desktop folders, and the preview will fail there sooner or later.

   ```sh
   mkdir -p ~/Developer && cd ~/Developer
   git clone https://github.com/realS3BI/homepage-kit.git
   cd homepage-kit
   ```

   If you created your own repo in step 1, clone its address instead.

3. Run the setup:

   ```sh
   npm run setup
   ```

The setup asks four questions and writes the answers to `kit.env`:

| Question | Meaning |
| --- | --- |
| Short name of the website | Used in the names of the macOS services and the watchdog, for example `homepage` |
| Skill name | What you call the agent with in chat. `website` becomes `/website` |
| Keywords | Words that trigger the skill even without the slash command, for example "company website, our homepage" |
| Preview port | Every website on the same Mac needs its own |

It then installs the dependencies, sets up the preview service, shares it via Tailscale and installs the skill and watchdog in OpenClaw. At the end it shows the preview address.

You can run the setup again at any time, including to change the skill name, keywords or port. It cleans up whatever ran under the old names first.

You can also leave this to OpenClaw. An agent passes the answers as options:

> Clone https://github.com/realS3BI/homepage-kit into ~/Developer and run `npm run setup -- --slug homepage --skill website --triggers "company website, our homepage"` in the repo. Then send me the preview address.

## Getting started

Message your OpenClaw, here with the skill name `website`:

> /website Let's get started

The agent first asks for examples and material, then asks questions about the business, only a few at a time. Write in whatever language you like; the agent answers in the same language. It records the answers in `BRIEF.md`. Then it builds the first draft and sends you the preview address.

### Examples and material

Show the agent how the website should look. Send it in the chat:

- Links and screenshots of websites you like
- Logo, photos and existing texts

The agent stores everything in the `examples/` folder, looks at it and notes in `BRIEF.md` what it takes from it for layout, colors, typography and tone. From other people's websites it takes the direction; it doesn't copy them. Your own material it uses directly.

This works at any time, not just at the start. A screenshot with "this is how the header should look" is enough.

### Day to day

> /website From now on we're open until 2 pm on Fridays
>
> /website We're closed for holidays from 3 to 14 August
>
> /website Here is our new team photo
>
> /website Undo the last change

Every change becomes its own Git commit, so each one can be undone on its own.

## Publishing

As long as sample content or `TODO` placeholders are on the website, the command refuses to publish. This mostly concerns the imprint and privacy policy. Have both legally reviewed before publishing for the first time.

### On a small VPS

You need a server running Ubuntu or Debian that you can log into with an SSH key, and a domain whose A record points to the server's IP. The smallest size from any provider is enough, because the server only serves finished files.

1. Enter the domain and server in `kit.env`:

   ```sh
   SITE_DOMAIN=musterbetrieb.at
   DOMAIN_ALIASES=www.musterbetrieb.at
   DEPLOY_HOST=root@203.0.113.10
   ```

2. Prepare the server once. The command installs Docker and creates the target folder.

   ```sh
   npm run deploy:setup
   ```

3. Publish:

   ```sh
   npm run deploy
   ```

The command builds the website on the Mac, copies the files to the server and starts Caddy there. Caddy obtains and renews the HTTPS certificate itself. Later, `/website Publish` in the chat is enough.

### With Coolify or another platform

The `Dockerfile` builds an image that serves the website on port 80. Connect the repo to the platform, choose Dockerfile as the build method and enter the domain there. `SITE_DOMAIN` in `kit.env` still has to be correct, because the addresses for search engines are generated from it.

## Commands

| Command | Effect |
| --- | --- |
| `npm run setup` | Asks for names and port, sets up preview, Tailscale sharing, skill and watchdog |
| `npm run status` | Shows the state of every part and the open placeholders |
| `npm run check` | Checks types, builds the website and lists placeholders |
| `npm run preview:check` | Checks the preview and restarts it if needed |
| `npm run preview:logs` | Shows the last lines of the preview log |
| `npm run share` | Shares the preview via Tailscale |
| `npm run deploy:setup` | Prepares the server once |
| `npm run deploy` | Builds and publishes the website |
| `npm run uninstall` | Removes services, sharing, skill and watchdog from the Mac |

## Several websites on one Mac

Create a separate repo from the template for each website and give each one its own short name, skill name and port during setup. Services, skills and watchdogs carry these names and don't get in each other's way.

## Troubleshooting

**The preview doesn't load.** `npm run status` shows which part is missing. `npm run preview:check` restarts the service, `npm run preview:logs` shows why.

**The agent doesn't reply on Telegram.** `openclaw channels status --deep` shows the state of the channel. If it says "stopped", run `openclaw gateway restart`.

**The Tailscale address doesn't open.** The device you're using must be signed in to the same tailnet. If `npm run share` reports an error, MagicDNS or HTTPS certificates are missing in the Tailscale admin console.

**Port in use.** Run `npm run setup` again and choose a different port.

**The preview doesn't start after a Node update.** Run `npm run setup` again so the service points to the current Node.

**Error -11 or "Resource deadlock avoided".** The repo is in an iCloud folder. Move it to `~/Developer` and run `npm run setup` again.

**Alerts on failure.** Enter the recipient in `kit.local.env`, for example `WATCHDOG_ALERT_TO=telegram:123456789`, and run `npm run setup` again. After two failures in a row, OpenClaw sends a message.

## Repo layout

| Location | Contents |
| --- | --- |
| `AGENTS.md` | Rules and workflow for every AI agent |
| `BRIEF.md` | What is known about the business, maintained by the agent |
| `examples/` | References and own material |
| `docs/onboarding.md` | How the first conversation goes |
| `kit.env` | Settings: short name, skill name, keywords, port, domain, server |
| `src/content/` | All texts and facts of the website |
| `src/styles/tokens.css` | Colors, fonts, spacing |
| `scripts/` | Setup, preview, OpenClaw, publishing |
| `openclaw/` | OpenClaw skill template |
| `deploy/`, `Dockerfile` | Server configuration |
