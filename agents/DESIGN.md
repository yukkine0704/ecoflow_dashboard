# Design System Document: Kinetic Laboratory

## 1. Overview & Creative North Star
### Creative North Star: "The Human Observatory"
This design system moves away from the sterile, industrial aesthetic common in IoT and towards a "Kinetic Laboratory"—a space where precision meets warmth. It is a premium, editorial-inspired experience that treats data not just as numbers, but as a living environment. 

We break the "template" look by using intentional asymmetry, organic overlapping of elements, and a high-contrast typography scale that feels curated rather than generated. The interface should feel like a sophisticated physical dashboard: tactile, deeply layered, and vibrantly alive.

---

## 2. Colors
Our palette is a sophisticated mix of "Warm Laboratory" pastels and a "Deep Charcoal" dark mode. 

### Core Palette (Dark Mode Optimized)
- **Background (`#0d0f0f`):** A deep charcoal that provides the ultimate canvas for neon data.
- **Primary (`#ffaa85` - Apricot):** Used for main CTAs and active states.
- **Secondary (`#87d5bd` - Mint):** Used for "Healthy" status and positive data trends.
- **Tertiary (`#ffe9b0` - Pale Yellow):** Used for warnings or secondary highlights.

### The "No-Line" Rule
**Strict Mandate:** Designers are prohibited from using 1px solid borders for sectioning. 
Structure is achieved through:
- **Tonal Shifts:** Placing a `surface_container_low` card on a `surface` background.
- **Negative Space:** Using a generous spacing scale (32px+) to separate distinct functional groups.

### Surface Hierarchy & Nesting
Treat the UI as a series of physical layers. Use the following tiers to define depth:
1. **Base Layer:** `surface` (`#0d0f0f`)
2. **De-emphasized Content:** `surface_container_low` (`#111414`)
3. **Standard Cards:** `surface_container` (`#171a1a`)
4. **Interactive/Prominent Elements:** `surface_container_highest` (`#232626`)

### The "Glass & Gradient" Rule
To elevate the experience, floating elements (e.g., Modals, Navigation Bars) must utilize **Glassmorphism**. Apply a semi-transparent `surface_bright` with a `backdrop-filter: blur(20px)`. Main CTAs should use a subtle linear gradient from `primary` to `primary_container` to give them a "glowing" physical presence.

---

## 3. Typography
The system uses a high-contrast pairing to balance scientific precision with human readability.

- **Headings (Space Grotesk):** A quirky, wide-proportioned sans-serif that conveys a technical, "laboratory" feel. It is used for Display and Headline roles to command attention.
- **Body (Manrope):** A modern, geometric sans-serif optimized for legibility. It provides the "warmth" in the Kinetic Laboratory, making complex IoT data feel approachable.

### Typography Roles
- **Display-LG (3.5rem):** Use for hero metrics (e.g., Temperature, Energy Usage).
- **Headline-MD (1.75rem):** Use for primary section titles.
- **Title-SM (1rem):** Use for card headers and important labels.
- **Body-MD (0.875rem):** Default for all descriptive text.
- **Label-SM (0.6875rem):** Used for micro-data and metadata tags.

---

## 4. Elevation & Depth
Hierarchy is conveyed through **Tonal Layering** rather than structural lines.

- **The Layering Principle:** Stack `surface_container` tiers to create natural lift. For example, a `surface_container_highest` button sits atop a `surface_container` card.
- **Ambient Shadows:** When an element must "float" (e.g., a critical alert), use a shadow with a blur radius of `48px` at `6%` opacity. The shadow color should be tinted with the `primary` token (`#ffaa85`) to mimic a soft light source.
- **The "Ghost Border" Fallback:** If containment is strictly required for accessibility, use the `outline_variant` token at **15% opacity**. Never use 100% opaque borders.
- **Soft Roundness:** Apply `round-3xl` (3rem) to large containers and `round-full` (9999px) to buttons and chips to maintain the organic, premium feel.

---

## 5. Components

### Buttons
- **Primary:** Gradient fill (`primary` to `primary_dim`), `round-full`, Manrope Bold.
- **Secondary:** `surface_container_highest` fill, `on_surface` text, no border.
- **Tertiary:** Transparent fill, `primary` text, `round-full`.

### Kinetic Cards
- No dividers. 
- Use a `surface_container` background with `round-3xl`.
- **Interactivity:** On hover, the card should shift to `surface_container_high` and scale by 1.02x for a "kinetic" feel.

### Status Chips
- Use the pastel palette (`primary`, `secondary`, `tertiary`) at 20% opacity for the background and 100% opacity for the text. Roundness: `round-full`.

### Tablet Landscape (Multi-Column)
For Tablet Landscape, implement a **3-Column Editorial Grid**:
- **Column 1 (25%):** Navigation & Environment selection.
- **Column 2 (50%):** Primary Data Visualization (Kinetic charts).
- **Column 3 (25%):** Secondary stats & Activity log using `surface_container_low` for depth differentiation.

---

## 6. Do's and Don'ts

### Do
- **Do** use `round-full` for all buttons to emphasize the "soft laboratory" look.
- **Do** use overlapping elements (e.g., an icon slightly bleeding out of a card corner) to create a custom, high-end feel.
- **Do** leverage the neon accents (`secondary_fixed`) for critical real-time data points in Dark Mode.
- **Do** allow for generous white space; let the typography breathe.

### Don't
- **Don't** use black (`#000000`) for backgrounds; always use the charcoal `surface` token for better depth.
- **Don't** use standard "drop shadows" with 0 blur. Shadows must be ambient and diffused.
- **Don't** use dividers or 1px lines to separate content; use background color shifts or 32px-48px spacing.
- **Don't** use Space Grotesk for body text; it is reserved strictly for headings to maintain an editorial hierarchy.