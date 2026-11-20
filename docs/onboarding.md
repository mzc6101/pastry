# Pastry first-launch onboarding

Six screens, about 90 seconds. One glass window; the shelf is the thing it hands off to. Shortcut labels are read from the user's current setting, never hard-coded.

Principles
- Every screen ends with something the user did, not something they read.
- Motion is physical: springs with a little overshoot, no linear easing, nothing over ~600 ms.
- Every screen has a visible Skip. Accessibility can be skipped, with a plain note about what waits.

Flow: Welcome, then Copy, then Shelf, then Suggestions, then Access, then Finish.

---

## 1. Welcome

**Title:** Your clipboard, remembered

**Subtitle:** Everything you copy, one shortcut away. Pastry keeps the history so you never lose a link again.

**Interaction:** Click "Get started." No input yet; this screen is about the promise.

**Animation:** A glass blob the size of the app icon melts into a long glass bar along the bottom edge. Four placeholder cards spring up out of it one by one, 80 ms apart, with a 6% overshoot.

**Success:** The bar and cards fold back into the blob, which morphs into the window's first card and carries the user to screen 2.

---

## 2. Copy something now

**Title:** Copy something now

**Subtitle:** Select the sentence below and press ⌘C. Pastry catches it the moment it lands.

**Interaction:** A highlighted sentence, a link and a small image sit in the window. The user selects the sentence and presses ⌘C (or copies the link). Capture is real: the running app's clipboard watcher records it, nothing is faked.

**Animation:** On the real capture event, the copied item lifts off the page as a glass card, arcs in a physics curve to a mini shelf at the bottom, and lands with a squash-and-stretch. A soft tint of the source app blooms behind it. A counter badge bumps from 0 to 1.

**Success:** Badge reads "1 copied," a check ring fills, and "Next" activates. After 20 seconds with no copy, a hint fades in: "Select the text, then press ⌘C."

---

## 3. Press ⇧⌘V

**Title:** Press ⇧⌘V

**Subtitle:** That's the shelf. Return pastes, Tab flips to Pinned, and Esc gets you out.

**Interaction:** "Press ⇧⌘V now." The real global hotkey is used, and the label shows the user's chosen shortcut if they changed it. The onboarding listens for the shelf-opened event. Then the user presses Esc to close it.

**Animation:** The three keycaps press down with a click-spring. The shelf rises from the bottom edge like liquid pulled upward, and cards cascade in from the left, with the card copied on screen 2 landing first with a small bounce.

**Success:** When the shelf opens, the caption changes to "Got it," and the onboarding window slides aside. After 30 seconds with no shelf, a button appears: "Open the shelf for me."

---

## 4. Smart suggestions

**Title:** Pastry anticipates your paste

**Subtitle:** Open the shelf in any app. Three suggestions appear on the right, picked for where you are.

**Shortcut hint:** A neutral "⇧ →" keycap pair reads "Press ⇧→ to jump to suggestions". Pressing ⇧→ in the window slides the selection ring from the first history card to the first suggestion tile (⇧← slides it back). If the user does nothing, it demos once after about 4 seconds.

**Interaction:** The user switches to another app (Notes or Safari), presses ⇧⌘V, and sees three suggestion tiles. They tap the sparkles button to turn suggestions off, then on again.

**Animation:** Three glass tiles spring in from the right edge with staggered overshoot. The sparkles button is a small glass blob that stretches toward the tiles when toggled; turning suggestions off drains the tiles back into it like water into a drop.

**Success:** Tiles are visible with the caption "Picked for Notes" (the real frontmost app's name). The sparkles glyph animates between filled and outline, and the user has seen both states. If the on-device model is unavailable, the screen says: "Suggestions need Apple Intelligence on this Mac. Everything else still works."

---

## 5. Allow pasting

**Title:** One permission, then paste

**Subtitle:** Pastry needs Accessibility to paste into other apps for you. Grant it once; you can revoke it anytime.

**Interaction:** The button "Open System Settings" deep-links to Privacy & Security > Accessibility. The user turns Pastry on, or adds /Applications/Pastry.app with the + button. No "I did it" button: the onboarding polls the trust state about once a second and updates itself. A text link, "Skip for now," says browsing and copying still work and pasting waits.

**Animation:** A padlock sits in a glass well. A slow pulse ring breathes every 2 seconds while waiting so the screen never looks frozen. On grant, the shackle springs open, liquid fills the well, and the glass splits into a checkmark.

**Success:** The state flips to "Granted" within about a second of the toggle, with no reload. If the grant exists but this process predates it, the button becomes "Relaunch Pastry" (matching the app's existing behavior). Relaunch resumes onboarding at this screen.

---

## 6. Finish

**Title:** Start using Pastry

**Subtitle:** Pastry lives quietly in the background. Turn on launch at login so it's ready after every restart.

**Interaction:** A "Launch Pastry at login" toggle, off by default, with the note "Change anytime in Settings > General." Then the user clicks "Start using Pastry."

**Animation:** The toggle knob drags like liquid and snaps with a small wobble. On "Start," the window dissolves into a glass drop that falls and docks along the bottom edge, then the shelf rises once to say hello.

**Success:** The onboarding closes, the shelf opens once with the screen-2 card still in it, and a completion flag is saved so onboarding never reruns. Reopening Pastry shows the shelf, not onboarding.

---

## Open questions

- Suggestion fallback copy on Macs without the on-device model is a placeholder; confirm the availability check and the wording.
- Confirm the onboarding-complete flag lives in the same UserDefaults domain as the other preferences (`com.manavchordia.pastry`).
- Confirm that relaunching during screen 5 resumes at that screen rather than restarting from Welcome.
