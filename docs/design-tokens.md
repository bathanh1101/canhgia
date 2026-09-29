# CanhGia design tokens

Source: `docs/figma/README.md` (sampled from screenshots, matches Tailwind scale). Mobile: `AppColors.<token>`; web/extension: CSS var `--color-<token>`.

| Token | Hex | Use |
|---|---|---|
| primary | #059669 | buttons, links, cashback amounts |
| primary-dark | #047857 | gradient end, pressed |
| primary-tint | #ecfdf5 | tinted surface |
| primary-tint-strong | #d1fae5 | chips, badges |
| bg | #f4f6f5 | screen background |
| surface | #ffffff | cards, sheets |
| border | #e5e7eb | dividers, outlines |
| text | #1e293b | primary text |
| text-2 | #334155 | body text |
| text-muted | #64748b | captions, hints |
| warning-tint | #fffbeb | pending background |
| warning | #f59e0b | pending / hold |
| info-tint | #eff6ff | info background |

## Status colors
| Status | Foreground | Background |
|---|---|---|
| pending / hold | warning #f59e0b | warning-tint |
| approved / paid | primary #059669 | primary-tint |
| rejected / error | #dc2626 (red-600, not in Figma; INFERRED) | #fef2f2 |
| info | #2563eb (blue-600, INFERRED) | info-tint |

Typography and spacing: follow the Figma frames; no i18n, Vietnamese strings only.
