# Pastry launch video: script and storyboard

**Runtime:** 52 s · **Format:** 1920x1080, 30fps · **Style:** Apple keynote product reel

## Global style

- **Type:** SF Pro Display Bold, tight tracking (-2%). One line per frame, max three words. Words rise on a spring (overshoot 6%), then blur out before the next cut.
- **Color:** deep indigo `#1B0F3A` to vivid pink `#FF4F9A` gradients behind all scenes. Glass is white at 12–18% opacity, 1 px inner highlight, 40 px background blur.
- **Motion:** springs only (stiffness ~260, damping ~22). No linear easing. Nothing slower than 600 ms.
- **Cuts:** every scene boundary lands on the beat grid (0.5 s). Hard cut by default; glass scenes use a liquid morph wipe.

## Music and tempo

- No copyrighted tracks. Use an original or royalty-free-licensed piece, or a custom composition.
- **120 BPM** (0.5 s per beat, 2 s per bar). Build from a single pad on scene 1 and add a pulse bass at scene 3.
- Downbeat hits on each scene's first frame. The big kick hits on the "⇧⌘V" key press (7.0 s) and the final logo reveal (45.0 s).

---

## Scene 1: Cold open (0.0–2.5 s)

- **On-screen:** "Copied."
- **UI:** None. A single pink dot pulses in the center, then expands into the word.
- **Animation:** Dot scales from 0 to 1 on a spring. The word emerges from a 12 px blur over 400 ms.
- **Transition:** Blur dissolve into scene 2.

## Scene 2: Everything you copy (2.5–6.5 s)

- **On-screen:** "Everything you copy."
- **UI:** Four glass cards fly in from off-screen edges: a text snippet, a link, an image thumbnail, and a file icon. Each card carries a soft tint of its source app (blue, orange, green, yellow).
- **Animation:** Cards enter one by one at 80 ms intervals with a 6% overshoot, then gather into a stack at center.
- **Transition:** Stack collapses to a single point, then hard cut.

## Scene 3: The shortcut (6.5–10.0 s)

- **On-screen:** "⇧⌘V"
- **UI:** Three large keycaps on a dark desk-plane. The keys press down in sequence.
- **Animation:** Each keycap clicks down with a short spring (120 ms). On the last key, a glass shelf rises from the bottom edge like liquid pulled upward.
- **Transition:** Shelf fills the frame, then the camera pulls back to show the full width.
- **Audio:** Kick on the final keypress.

## Scene 4: One shelf, every format (10.0–14.5 s)

- **On-screen:** "One shelf."
- **UI:** Bottom-edge Liquid Glass shelf full width. Horizontal history cards: text, link preview, image thumbnail, file icons. Each card is tinted by its source app.
- **Animation:** Camera tracks a horizontal swipe with momentum. Cards slide and settle with a small bounce at each stop.
- **Transition:** Liquid morph wipe to scene 5.

## Scene 5: Find it. Pin it. (14.5–19.0 s)

- **On-screen:** "Find it. Pin it."
- **UI:** A search field at the top of the shelf. The user types "invoice". Non-matching cards fade and compress, leaving one.
- **Animation:** Matching card springs to the front. Cmd-P pulses on it, then the card lifts and docks into a Pinned row. Tab toggles the Pinned view on screen.
- **Transition:** Hard cut on the Pinned row landing.

## Scene 6: Nine keys, instant paste (19.0–22.5 s)

- **On-screen:** "⌘1–9. Paste now."
- **UI:** Number badges (1–9) appear on the cards at once, each with a small spring.
- **Animation:** ⌘3 presses. The third card flashes, its content flies into a text field in a document window, and the field types it in.
- **Transition:** Card flies out of frame to the right, hard cut.

## Scene 7: It knows where you are (22.5–28.5 s)

- **On-screen:** "It knows where you are."
- **UI:** A Mail window with an open email. The shelf rises, and three glass tiles spring in from the right edge with "Picked for Mail": a reply paragraph, a sentence, an address. Then the frame cuts to an Xcode window with a Swift file open. The shelf rises again, with three code tiles: a function, an initializer, an import block. Caption changes to "Picked for Xcode."
- **Animation:** Tiles spring in with stagger overshoot. Caption fades in on a 300 ms dissolve.
- **Transition:** Mail-to-Xcode switch uses a window-slide, not a cut, to imply the app changed.
- **Note:** Use placeholder copy in both apps. Do not show real personal emails.

## Scene 8: Your call (28.5–32.5 s)

- **On-screen:** "Your call."
- **UI:** The sparkles button sits at the shelf's top-right corner as a glass blob.
- **Animation:** Tap. The three tiles drain back into the blob like water into a drop. Second tap. The blob stretches and the tiles spring out again. The sparkles glyph animates from outline to filled.
- **Transition:** Blob shrinks to a point, then hard cut.

## Scene 9: On your Mac. Private. (32.5–37.0 s)

- **On-screen:** "On your Mac." then "Private."
- **UI:** A stylized Mac silhouette in glass. A shield icon sits over the screen. A faint network line stops at the edge of the frame, and the shelf stays inside it.
- **Animation:** Shield draws in with a stroke animation. The network line dims and breaks off on a spring. Two words stack, one per beat.
- **Transition:** Blur dissolve.

## Scene 10: Make it yours (37.0–41.0 s)

- **On-screen:** "Make it yours."
- **UI:** The Settings window in glass. The shortcut recorder shows ⇧⌘V. The history retention picker is set to "1 week" and changes to "1 month".
- **Animation:** The recorder field records a new combo and snaps closed with a small wobble. The retention segment slides under the cursor.
- **Transition:** Settings window lifts up and out of frame.

## Scene 11: Tagline (41.0–45.0 s)

- **On-screen:** "Your clipboard, remembered."
- **UI:** None. Full-frame gradient.
- **Animation:** Words resolve line by line on the bar cadence: "Your clipboard," then "remembered." The second line is pink.
- **Transition:** Hard cut on the downbeat at 45.0 s.

## Scene 12: End card (45.0–52.0 s)

- **Icon:** Pastry app icon at center. A glass clipboard with a pink donut clipped to it. The icon scales in from 0.9 to 1.0 on a spring.
- **On-screen, in order:**
  1. "Pastry" (appears at 45.5 s)
  2. "Your clipboard, remembered." (46.5 s)
  3. "Download for macOS" as a pill button (48.0 s), with a single soft pulse at 49.0 s
- **Animation:** Background gradient slowly shifts from indigo to pink over the full scene. The final frame holds for 2 s.
- **Audio:** Final kick and a held chord on 52.0 s.
