# Design System Philosophy: The Tactile Hearth

## 1. Overview & Creative North Star
The creative North Star for this design system is **"The Tactile Hearth."** 

We are moving away from the cold, clinical aesthetic typical of IoT and into a space that feels editorial, warm, and hyper-intentional. The goal is to make smart home management feel like flipping through a high-end architectural magazine. By utilizing a foundation of warm creams (`#fef9ef`) paired with high-character geometry (Space Grotesk), we create a "Humanistic Tech" experience.

This system breaks the "bootstrap template" look through **intentional asymmetry** and **tonal depth**. We do not rely on boxes; we rely on composition. Expect generous white space (breathing room), overlapping glass layers, and a hierarchy that favors large, expressive typography over cluttered dashboards.

---

2. Colors: A Sun-Drenched Palette

The palette is rooted in Earth tones—burnt oranges, mossy greens, and ochre yellows—all tuned to vibrate harmoniously against the warm cream background.

### The "No-Line" Rule
**Explicit Instruction:** Designers are prohibited from using 1px solid borders to define sections. Boundaries must be established exclusively through:
*   **Tonal Shifts:** Placing a `surface-container-low` component against a `surface` background.
*   **Negative Space:** Using the spacing scale to create groupings.
*   **Shadow Depth:** Using ambient, tinted glows to lift elements.

### Surface Hierarchy & Nesting
Treat the UI as a series of physical layers, like stacked sheets of fine vellum paper.
*   **Base:** `surface` (#fef9ef) – The foundation.
*   **Level 1:** `surface-container-low` (#f8f3e8) – Subtle grouping.
*   **Level 2:** `surface-container` (#f3eee1) – Primary interactive zones.
*   **Level 3:** `surface-container-high` (#ede8da) – Prominent cards and modals.

### The "Glass & Gradient" Rule
To add "soul," use **Glassmorphism** for floating elements (e.g., navigation bars or quick-action overlays). Use `surface` colors at 70% opacity with a `24px` backdrop-blur. 
*   **Signature Texture:** Apply subtle linear gradients to primary CTAs, transitioning from `primary` (#974a00) to `primary-container` (#ffaf78) at a 135-degree angle. This prevents the "flat-web" look.

---

## 3. Typography: Editorial Authority

We use a dual-font strategy to balance technical precision with approachable warmth.

*   **Display & Headlines (Space Grotesk):** This is our "Tech Soul." Its geometric quirks should be celebrated. Use `display-lg` (3.5rem) for hero states (e.g., "Good Morning, Alex") to create an authoritative, editorial feel.
*   **Body & Titles (Manrope):** This is our "Human Voice." Manrope provides superior legibility for data and long-form text, grounding the more aggressive Space Grotesk.

**Hierarchy as Identity:** 
High contrast in sizing is mandatory. A `headline-lg` should feel significantly more "important" than the `body-lg` text below it. Use `on-surface-variant` (#625f53) for secondary information to ensure the eye hits the primary Space Grotesk headers first.

---

## 4. Elevation & Depth

Standard drop shadows are strictly forbidden. We use **Ambient Tonal Layering**.

*   **The Layering Principle:** Depth is achieved by "stacking." A `surface-container-lowest` (#ffffff) card placed on a `surface-container-low` (#f8f3e8) background creates a natural, soft lift without a single pixel of shadow.
*   **Ambient Shadows:** For floating elements (Modals/Poppers), use a multi-layered shadow:
    *   `box-shadow: 0 20px 40px rgba(53, 51, 40, 0.04), 0 8px 16px rgba(53, 51, 40, 0.02);`
    *   *Note:* The shadow color is a tinted version of `on-surface`, never pure black.
*   **The "Ghost Border" Fallback:** If a divider is required for accessibility, use `outline-variant` (#b6b2a3) at **15% opacity**.

---

## 5. Components: IoT Refined

### Buttons
*   **Primary:** Rounded `xl` (3rem), utilizing the Primary-to-Container gradient. No border. Text in `on-primary`.
*   **Tertiary:** Space Grotesk `label-md`, all caps, with a 2px letter spacing. Interaction is indicated by a subtle `surface-container` background shift on hover.

### Cards & Control Tiles
*   **Constraint:** Zero dividers. Use vertical white space to separate the device name from the status.
*   **State Change:** When an IoT device is "On," the card should transition from `surface-container` to the corresponding accent color at 10% opacity (e.g., `secondary` for a light, `primary` for a heater).

### Input Fields
*   **Style:** Minimalist. No bottom line. Use a `surface-container-low` background with a `md` (1.5rem) corner radius.
*   **Focus:** Transition the background to `surface-container-highest` and add a "Ghost Border" of `primary`.

### Specialized IoT Components
*   **The "Glass Gauge":** For temperature or energy tracking, use semi-transparent arcs with `backdrop-blur`.
*   **Status Chips:** Use `secondary-container` with `on-secondary-container` text. The shape must be `full` (pill-shaped) to contrast with the `xl` rounded corners of the parent cards.

---

## 6. Do's and Don'ts

### Do
*   **Do** use asymmetrical layouts for dashboards (e.g., one large card on the left, two smaller stacked on the right).
*   **Do** lean into the "Warmth." Use the `#fef9ef` background to make the UI feel like a home, not a computer.
*   **Do** use `xl` (3rem) corner radius for main containers to emphasize the friendly, modern IoT aesthetic.

### Don't
*   **Don't** use pure black (#000000) for text. Use `on-background` (#353328) to maintain the organic feel.
*   **Don't** use 1px dividers between list items. Use 12px-16px of vertical gap.
*   **Don't** use standard Material shadows. They are too "heavy" for this sun-drenched palette.