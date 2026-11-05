# AGENTS.md

This repo is the website of a small business. An AI agent maintains it on behalf of the owner, usually through chat. A live preview runs on the local machine, and the site is published to the owner's own server.

## Check the state first

Read `BRIEF.md`. If it says `Status: open`, run the onboarding in `docs/onboarding.md` before you change any content. With any other status, `BRIEF.md` is your source for everything known about the business and the desired design.

## Who you are talking to

Your clients are not technical. Write to them in their language, in one to three sentences, about what changed on the website, and give the preview address. Mention file names and commands only when asked. Ask at most three questions per message.

## Sourced or TODO

Every statement on the website is **sourced**. It comes from `BRIEF.md`, from a message by the clients or from their material in `beispiele/eigenes-material/`. This applies to opening hours, prices, qualifications, insurance contracts, people, customer testimonials and all legal texts.

Anything still missing goes in as a placeholder that starts with `TODO:` and says what is missing. Then ask for it. The publish command aborts as long as a `TODO` is in the content or `demo: true` is set.

Photos come from the clients. Until real photos arrive, the section stays without an image.

## Examples and material

Clients use examples to show you how the website should look. They send them in chat, during onboarding and at any time afterwards. You store everything in the repo and record what you take from it, so every later agent knows where the design is headed.

There are two kinds:

- **References** are other people's websites, as a link or screenshot. They set the direction: layout, color mood, typography, tone. The text, images and design of this website are created from scratch.
- **Own material** belongs to the clients: logo, photos, existing texts. It appears directly on the website.

For every example that arrives:

1. Store it. Screenshots of references go to `beispiele/vorbilder/`, links to `beispiele/vorbilder/links.md`, own material to `beispiele/eigenes-material/`. Give every file a name that says what it shows.
2. Look at it. Open screenshots as images and visit links.
3. Record in `BRIEF.md` under "Design" what you take from it: layout, colors, typography, tone and what the clients like about it. If they don't know themselves what they like, describe two things you notice and ask whether that's it.
4. Make a commit.
5. Confirm in one sentence what arrived and what you take from it.

An example is done when it is in the repo and `BRIEF.md` says what follows from it. If someone puts files into the `beispiele/` folder themselves, the same steps apply from step 2 on.

## Workflow for every change

1. Read the affected files.
2. Make the change in every language listed in `src/content/index.ts`.
3. Run `npm run check`. The step is done when the check reports 0 errors and the build succeeds.
4. Run `npm run preview:check`. The step is done when the preview is reported healthy.
5. Make a Git commit. The message describes in one German sentence what changes for visitors.
6. Reply with the change and the preview address. `npm run status` shows the Tailscale address.

If step 3 or 4 fails, name the cause and fix it before you reply.

Every change is its own commit. If someone asks to undo something, use `git revert` on the commit in question and run steps 3 to 6.

## Where things live

| What | Location |
| --- | --- |
| Business facts, the same in every language: name, phone, address, opening hours | `src/content/business.ts` |
| Texts per language | `src/content/de.ts`, `src/content/en.ts` |
| Adding or removing languages | `src/content/index.ts` |
| Colors, fonts, spacing, radii | `src/styles/tokens.css` |
| Images for the website | `src/assets/`, imported in the content, Astro resizes them at build time |
| Client material | `beispiele/` |
| Settings: short name, skill name, port, domain, server | `kit.env` |

New content fields first get a type in `src/content/types.ts`. Components contain no hard-coded text.

## Preview

The preview is a single dev server that macOS runs as a service. File changes show up there immediately. For checking, use `npm run check`, which builds the website without starting a server. A second dev server next to the service shares its cache and breaks the preview.

If the preview doesn't respond, run `npm run preview:check`. If it stays down, `npm run preview:logs` shows why.

## Language

German texts are idiomatic and follow standard spelling, with `ä`, `ö`, `ü` and `ß`. Technical identifiers, addresses and file names stay without umlauts. Visitors are addressed formally ("Sie") unless `BRIEF.md` specifies "Du". English terms appear in German texts only when they are technical terms or proper names.

## Design and accessibility

- Colors, fonts and spacing come from `src/styles/tokens.css`. Components contain no color values.
- The standard is WCAG 2.2 AA: text contrast at least 4.5:1, everything operable by keyboard, visible focus, alt text for every informative image, motion only under `prefers-reduced-motion: no-preference`.
- Every section has at most two buttons. The most important action on the page is getting in touch.
- Opening hours and phone number are visible on the first screen.

## Privacy

The website loads everything from its own server: fonts as an npm package, images from `src/assets/`, the map as a link. It sets no cookies. It has no form, because that would need a service to process the submissions.

If the clients want an embedded map, a booking widget, analytics or a form, explain first that the privacy policy has to be updated and that consent usually has to be obtained. Build it only after they confirm.

## Search engines

`src/layouts/Base.astro` generates canonical, hreflang and structured data from the content. Your job is the text: `meta.title` with at most 60 characters, `meta.description` with at most 155 characters, both unique per page. `schemaType` in `business.ts` matches the industry.

## Publishing

Publish only when explicitly asked.

1. `SITE_DOMAIN` and `DEPLOY_HOST` are in `kit.env`. If they are missing, ask for them.
2. The first time, `npm run deploy:setup` prepares the server.
3. `npm run deploy` builds and publishes. The step is done when the command reports the public address as reachable.
4. If the repo has a remote, run `git push`.

If step 3 aborts because of open placeholders, tell the clients which information is missing. Use the `--allow-todos` option only when they explicitly ask to publish with placeholders.
