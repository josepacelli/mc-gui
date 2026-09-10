# Internationalization (i18n) Specification

## Problem Statement

mc-gui's entire UI is hardcoded in English. The user needs the app usable in Brazilian
Portuguese, European Portuguese, English, and Spanish, matching whatever language the
user already runs macOS in, with no extra setup.

## Goals

- [ ] Every user-facing string in the app renders in the user's macOS System Language when
      that language is Portuguese (Brazil), Portuguese (Portugal), English, or Spanish.
- [ ] Portuguese (Brazil) and Portuguese (Portugal) are genuinely distinct translations,
      not the same text reused twice.
- [ ] A system language outside the 4 supported ones (or a missing individual
      translation) falls back to English, never to a blank/raw key/crash.
- [ ] The installed `.app` (from `packaging/build-macos.sh`'s DMG) carries all 4
      languages' resources - not only the local `swift build` output.

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature                                                             | Reason                                                                                    |
| -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| In-app language picker / Preferences screen                          | User decision: follow macOS System Language only, no override UI (smaller scope).         |
| Translating user-authored content (Bookmarks names, User Menu labels/commands) | User data, not app UI - translating it would corrupt the user's own input.        |
| Translating file/folder names or file content shown in Viewer/Editor | Not app UI - it's the content the user is browsing.                                       |
| Translating `SyntaxHighlighter`'s language keyword set (func/class/if/...) | Those are literal source-code tokens of the file being viewed, not UI text.          |
| Live re-render when macOS System Language changes while the app is already running | Standard macOS behavior is next-launch, not live; live re-render is a much larger technical lift nothing here requires. |
| Any language beyond pt-BR, pt-PT, en, es                             | Not requested.                                                                             |
| RTL layout support                                                   | None of the 4 supported languages are RTL.                                                |
| Localizing `.specs/` docs, code comments, commit messages, or the DMG's own Finder window | Internal/development-facing or outside app control, not runtime app UI.       |

---

## Assumptions & Open Questions

Every ambiguity is resolved or recorded here - nothing is left silently unclear.

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Language selection mechanism | Follow macOS System Language automatically, no in-app picker | User confirmed via AskUserQuestion | y |
| Fallback language (system language outside the 4 supported) | English | User confirmed via AskUserQuestion | y |
| Translation scope | Whole app, including F1 Help's full static reference content | User confirmed via AskUserQuestion | y |
| PT-BR vs PT-PT | Genuinely distinct translations (correct PT-PT vocabulary: ficheiro/rato/etc., not a PT-BR copy) | User confirmed via AskUserQuestion | y |
| Spanish variant | One neutral/international Spanish translation, not region-specific (es-ES vs es-MX, etc.) | User said "Espanhol" with no region; a single neutral translation is standard practice absent a stated region | n |
| Localization mechanism | Apple's standard String Catalog (`.xcstrings`) + `String(localized:)`, resolved through each SPM target's own `Bundle.module` | Platform-native mechanism; gets language negotiation (including pt-BR vs pt-PT as distinct region variants) and the English-fallback behavior for free instead of reinventing it | n |
| Locale-aware number/date/byte formatting | Yes - `ByteCountFormatter`/`DateFormatter` etc. already respect the resolved `Locale`; no extra translation work needed beyond setting the app's effective locale correctly | Matches the spirit of "internationalization," and Foundation gives it for free | n |
| App/product name "Midnight Commander" | Never translated (stays literal in the window title and About-equivalent text) | Standard practice: product/brand names aren't localized | n |
| System-language change while the app is running | Applies on next launch only, not live | See Out of Scope row above | n |
| Existing tests asserting literal English UI strings | Updated case-by-case as each string becomes a localized lookup; test host locale pinned to English (`en`) so existing assertions keep passing without themselves needing translation | Testing-infrastructure detail, not a product behavior decision - detailed further at Design | n |

**Open questions:** none - all resolved or logged above.

---

## User Stories

### P1: Full app in the user's language ⭐ MVP

**User Story**: As a user whose macOS System Language is Portuguese (Brazil), Portuguese
(Portugal), English, or Spanish, I want the entire mc-gui UI in that language
automatically, so I can use the app in my own language with no extra configuration.

**Why P1**: This is the entire feature - without it, nothing about "internationalization"
is delivered.

**Acceptance Criteria**:

1. WHEN the app launches AND the user's macOS System Language is Portuguese (Brazil) THEN the system SHALL render every UI string (native menu bar, in-window TopBar/ButtonBar, panel headers/footers, Copy/Move/Mkdir/Delete/Conflict/Save-changes dialogs, the Progress dialog, error/alert messages, Viewer/Editor window chrome, Bookmarks UI, User Menu's own built-in UI, and the F1 Help window's static reference content) in Brazilian Portuguese.
2. WHEN the app launches AND the user's macOS System Language is Portuguese (Portugal) THEN the system SHALL render the same set of UI strings in European Portuguese, using PT-PT vocabulary where it diverges from PT-BR (e.g. "ficheiro" not "arquivo", "rato" not "mouse", "predefinições" not "padrões").
3. WHEN the app launches AND the user's macOS System Language is English THEN the system SHALL render the same set of UI strings in English.
4. WHEN the app launches AND the user's macOS System Language is Spanish THEN the system SHALL render the same set of UI strings in Spanish.
5. IF the user's macOS System Language is none of Portuguese (Brazil), Portuguese (Portugal), English, or Spanish THEN the system SHALL render the UI in English.
6. IF a specific UI string has no translation entry for the resolved language THEN the system SHALL render the English text for that string rather than a blank, a raw key name, or a crash.
7. The system SHALL apply locale-aware formatting (byte sizes, dates, decimal separators) to any UI text produced by a Foundation formatter, consistent with the resolved language.
8. The system SHALL include every supported language's string resources in the `.app` bundle produced by `packaging/build-macos.sh`, not only in the local `swift build`/`swift run` output.

**Independent Test**: For each of the 4 languages, set it as the macOS System Language (System Settings > General > Language & Region), relaunch the installed `.app`, and visually confirm every screen (main window, F1 Help, F2 User Menu, F5/F6 Copy/Move dialog + Progress dialog, F7 Mkdir, F8 Delete confirmation, the rename-conflict dialog, the Bookmarks popover) renders in that language, with no leftover English strings and no raw keys.

---

### P2: Missing translations are discoverable, not silent

**User Story**: As the developer maintaining mc-gui, I want every translatable string
centralized in one place per target, so a newly added string that ships without a
translation is visible by inspection instead of requiring a manual click-through of the
whole app in 4 languages.

**Why P2**: Important for keeping the 4 languages from drifting out of sync as the app
grows, but the app already functions correctly (via the English fallback, I18N-06)
without this - it's a maintainability guarantee, not user-visible runtime behavior.

**Acceptance Criteria**:

1. The system SHALL source every user-facing string in `MCGuiUI`, `MCGuiApp`, and `MCGuiMacOS` from a String Catalog (or equivalent centralized table) rather than an inline string literal, so a missing translation is discoverable by inspecting the catalog.
2. WHEN a new UI string is added to the codebase without a translation entry for one of the 4 languages THEN the build SHALL still succeed (a missing translation is a content gap, not a build error), and SHALL remain visible in the String Catalog as untranslated for that language.

---

## Edge Cases

- IF the macOS System Language changes while mc-gui is already running THEN the system SHALL keep displaying the language that was active at launch, unchanged, until the app is relaunched (no live re-render, no crash, no mixed-language UI).
- WHEN a translated string is longer than its English source (common for Portuguese/Spanish) THEN the affected label/button SHALL wrap or truncate via standard SwiftUI text-sizing modifiers rather than being clipped mid-character or breaking the dialog's layout.
- IF a string belongs to user-authored content (a Bookmark's name, a User Menu item's label/command) THEN the system SHALL display it verbatim, never translated or altered.
- IF a string is one of `SyntaxHighlighter`'s language keywords (`func`, `class`, `if`, `for`, ...) THEN the system SHALL NOT translate it - those are literal tokens of the source file being viewed, not app UI.

---

## Requirement Traceability

| Requirement ID | Story                            | Phase  | Status  |
| --------------- | --------------------------------- | ------ | ------- |
| I18N-01         | P1: Full app in the user's language | Design | Pending |
| I18N-02         | P1: Full app in the user's language | Design | Pending |
| I18N-03         | P1: Full app in the user's language | Design | Pending |
| I18N-04         | P1: Full app in the user's language | Design | Pending |
| I18N-05         | P1: Full app in the user's language | Design | Pending |
| I18N-06         | P1: Full app in the user's language | Design | Pending |
| I18N-07         | P1: Full app in the user's language | Design | Pending |
| I18N-08         | P1: Full app in the user's language | Tasks | Implementing |
| I18N-09         | P2: Missing translations are discoverable | Tasks | Implementing |
| I18N-10         | Edge case: system language change while running | Design | Pending |
| I18N-11         | Edge case: translated text length variance | Design | Pending |
| I18N-12         | Edge case: user-authored content never translated | Design | Pending |
| I18N-13         | Edge case: syntax highlighter keywords never translated | Design | Pending |

**ID format:** `I18N-[NUMBER]`

**Status values:** Pending → In Design → In Tasks → Implementing → Verified

**Coverage:** 13 total, 0 mapped to tasks, 13 unmapped ⚠️ (tasks.md not yet written)

---

## Success Criteria

- [ ] Setting macOS System Language to each of pt-BR, pt-PT, en, es and relaunching the installed `.app` shows every screen listed in P1's Independent Test fully in that language.
- [ ] Setting macOS System Language to an unsupported language (e.g. French) shows the full app in English, with no blank/raw-key strings anywhere.
- [ ] `packaging/build-macos.sh`'s DMG, installed on a machine with no Xcode/SPM cache, still shows all 4 languages correctly (proves resources are actually bundled, not just present in the dev build).
- [ ] `swift build && swift test` passes with the existing test suite updated for any string-literal assertions affected by the localization change.
