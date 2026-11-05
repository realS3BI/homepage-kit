# Onboarding

Onboarding turns the template with its sample content into the website of a real business. You run it as a conversation, in small steps, and record every answer in `BRIEF.md` right away. That way nothing gets lost if the conversation stretches over several days.

Ask the clients in their language. The questions below say what to ask, not how to word it.

## 1. Start

Set the status in `BRIEF.md` to `in progress`. Explain in two sentences what happens next: you first collect examples and material, then ask a few questions, and then show a first draft.

## 2. Ask for examples and material

Ask for these first, before the questions about the business. Good material answers half of the later questions.

- **References.** Which websites do they like, and what exactly about them? Ask them to send links or screenshots here in the chat.
- **Own material.** Logo, photos of the premises and team, texts from an existing website, a flyer or the Google profile, also here in the chat.

Handle everything that arrives as described in the section "Examples and material" in `AGENTS.md`.

If there is an existing website, read it and copy the facts into `BRIEF.md`. Note the source there and have the information confirmed, because old websites often contain outdated hours and numbers.

If nothing arrives, carry on without material and ask for photos once more before the first draft.

Done when every example sent is in the repo and evaluated in `BRIEF.md`, or the clients have said there is none.

## 3. Ask questions

Go through the blocks in order, at most three questions per message. Skip what the material has already answered, and have it briefly confirmed instead.

1. **Business.** Name, industry or specialty, location. Who is the website for? What should visitors do: call, book online, drop by?
2. **Facts.** Address, phone, email, opening hours per weekday. How are appointments made?
3. **Services.** The four to eight most important services, each in one sentence. What sets the business apart from others nearby?
4. **People.** Who works there, with what training? Are there photos?
5. **Frequent questions.** Which questions do customers ask most often on the phone? These become the FAQ section.
6. **Language.** Sie or Du? Is English or another language needed? If not, remove that language in `src/content/index.ts`.
7. **Design.** Is there a logo and fixed colors? Based on the evaluated references, describe two directions in one sentence each and let them choose. Without references, propose two directions that suit the industry.
8. **Legal.** Details for the imprint, data controller for privacy. Tell them that the imprint and privacy policy should be legally reviewed before publishing.
9. **Domain and server.** Is there already a domain? Where should the website run?

Done when every field in `BRIEF.md` has a value or is listed under "Open items".

## 4. Build the first draft

1. Enter the facts in `src/content/business.ts` and pick the matching `schemaType`.
2. Rewrite the texts in `src/content/de.ts` and in every other language. Nothing of the sample content remains.
3. Adapt the sections to the business. Remove what doesn't fit, such as opening hours for a business without fixed hours. Add what is missing, with its own type in `src/content/types.ts`.
4. Implement the chosen direction: colors, fonts, spacing and radii in `src/styles/tokens.css`, the layout in the components. Check the contrast of every text color against its background.
5. Replace `public/favicon.svg` with the logo or a mark in the main color.
6. Move photos from `beispiele/eigenes-material/` to `src/assets/` and use them.
7. Set `demo` in `business.ts` to `false` once no sample content is left.

Done when `npm run check` passes and `npm run todos` shows only placeholders that are listed under "Open items" in `BRIEF.md`.

## 5. Show and improve

Send the preview address and ask what doesn't fit. Work through the feedback one item at a time, as described in `AGENTS.md` under "Workflow for every change".

Set the status in `BRIEF.md` to `done` once the clients have approved the first draft.
