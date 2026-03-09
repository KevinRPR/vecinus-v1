# UI Motion Spec (Web + Mobile)

## Principles
- Motion guides attention, never distracts.
- Feedback inmediato en taps, clicks y estados.
- Animaciones cortas y coherentes en toda la app.

## Motion tokens
- fast: 120ms (micro feedback)
- base: 180ms (state changes)
- slow: 240ms (content reveal)
- modal: 320ms (sheets, dialogs)
- page: 280ms (page transition)

## Easing
- Standard: easeOutCubic (Flutter) / cubic-bezier(0.22, 1, 0.36, 1) (Web)
- Emphasize: easeInOutCubic (Flutter) / cubic-bezier(0.65, 0, 0.35, 1)

## Patterns
- Page enter: fade + slide up (6-12px), 280ms.
- List items: stagger 20-30ms, fade + rise 8px, 180ms.
- Buttons: scale to 0.98 on press, 120ms; haptic on success (mobile).
- Forms: inline validation with 180ms fade-in; no sudden jumps.
- Loaders: use skeletons after 300ms; avoid spinners > 800ms.
- Success: short check animation + message; auto-dismiss after 2s.
- Errors: shake 4-6px + red outline, 120ms; show actionable copy.

## Web-specific
- Hover states for cards and buttons (shadow + lift 2px, 120ms).
- Focus rings visible (accessibility).

## Mobile-specific
- Haptics for confirm, error, and critical actions.
- Respect reduce motion preference: disable stagger and reduce travel to 0-4px.
