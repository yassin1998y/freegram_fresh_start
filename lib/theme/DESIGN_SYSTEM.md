# Freegram Design System (FDS)

This document serves as the single source of truth for the Freegram Application Design System. It outlines the spacing, typography, colors, and components used throughout the application to ensure consistency and maintainability.

## 1. Principles

1.  **Consistency**: Use defined tokens for ALL layout and styling. Avoid hardcoded values (magic numbers).
2.  **Clarity**: Layouts should be spacious and clean. Content comes first.
3.  **Efficiency**: Use semantic tokens to make code readable and easier to modify globally.
4.  **Reusability**: Build reusable widgets rather than duplicating UI code.

## 2. Design Tokens (`DesignTokens`)

All tokens are defined in `lib/theme/design_tokens.dart`.

### 2.1 Spacing Scale (8px Grid)

Base Unit: **4px**

| Token | Value | Usage |
| :--- | :--- | :--- |
| `spaceXS` | 4.0 | Small gaps, tight grouping |
| `spaceSM` | 8.0 | Related items, internal padding |
| `spaceMD` | 16.0 | Standard padding, list items |
| `spaceLG` | 24.0 | Section separation |
| `spaceXL` | 32.0 | Major whitespace |
| `spaceXXL` | 48.0 | Large breaks |
| `spaceXXXL` | 64.0 | Huge breaks (e.g., onboarding) |

### 2.2 Semantic Spacing (Preferred)

Use these semantic tokens to describe *intent* rather than just value.

| Token | Value | Usage |
| :--- | :--- | :--- |
| `screenPadding` | 16.0 | Standard screen edge padding |
| `cardPadding` | 16.0 | Internal padding for cards |
| `listItemPadding` | 16.0 | Padding for list tiles |
| `listItemSpacing` | 8.0 | Vertical space between list items |
| `sectionSpacing` | 24.0 | Space between major content sections |
| `inputPadding` | 16.0 | internal padding for text fields |

### 2.3 Border Radius

| Token | Value | Usage |
| :--- | :--- | :--- |
| `radiusXS` | 4.0 | Small badges, indicators |
| `radiusSM` | 8.0 | Buttons, chips, small cards |
| `radiusMD` | 12.0 | **Standard** cards, dialogs, inputs |
| `radiusLG` | 16.0 | Large cards, bottom sheets |
| `radiusXL` | 20.0 | Modal containers |
| `radiusXXL` | 24.0 | Large modals |

### 2.4 Border Widths

| Token | Value | Type | Usage |
| :--- | :--- | :--- | :--- |
| `borderWidthHairline` | 0.5 | Hairline | Subtle dividers, widely used in lists |
| `borderWidthThin` | 1.0 | Thin | Standard borders, unselected inputs |
| `borderWidthThick` | 2.0 | Thick | Active states, selected inputs |

### 2.5 Icon Sizes

| Token | Value | Usage |
| :--- | :--- | :--- |
| `iconXS` | 12.0 | Tiny indicators |
| `iconSM` | 16.0 | Small inline icons (e.g. metadata) |
| `iconMD` | 20.0 | Standard UI icons |
| `iconLG` | 24.0 | Primary actions, navigation |
| `iconXL` | 32.0 | Large feature icons |
| `iconXXL` | 40.0 | Hero icons |

### 2.6 Typography

We use **OpenSans** as the primary font family. Layout text styles are accessed via `Theme.of(context).textTheme`.

| Style | Size | Weight | Usage |
| :--- | :--- | :--- | :--- |
| `displayLarge` | 32.0 | Bold | Hero headers, onboarding |
| `headlineSmall` | 24.0 | Bold | Section headers |
| `titleLarge` | 20.0 | Medium | App bar titles |
| `titleMedium` | 16.0 | Medium | Card titles |
| `bodyLarge` | 16.0 | Regular | Primary content |
| `bodyMedium` | 14.0 | Regular | Secondary content |
| `bodySmall` | 12.0 | Regular | Captions, metadata |
| `labelSmall` | 10.0 | Check | Tiny labels |

## 3. Semantic Colors (`SemanticColors`)

Use `SemanticColors` for theme-aware, consistent coloring.

| Token | Color (Light/Dark) | Usage |
| :--- | :--- | :--- |
| `success` | Green | Success states, validations |
| `error` | Red | Errors, destructive actions |
| `warning` | Orange | Warnings, alerts |
| `info` | Blue | Information, links |
| `textPrimary` | Black / White | Main text |
| `textSecondary` | Gray 600 / 400 | Secondary text |

## 4. Components & Widgets

### Buttons
- Height: `DesignTokens.buttonHeight` (48.0)
- Small Button Height: `DesignTokens.buttonHeightSmall` (36.0)
- Radius: `DesignTokens.radiusSM` (8.0)

### Inputs
- Height: `DesignTokens.inputHeight` (48.0)
- Radius: `DesignTokens.inputBorderRadius` (12.0)
- Padding: `DesignTokens.inputPadding` (16.0)

### Avatars
- **Small (List)**: `DesignTokens.avatarSizeSmall` (32.0)
- **Medium (Post)**: `DesignTokens.avatarSizeMedium` (48.0)
- **Large (Profile)**: `DesignTokens.avatarSizeXL` (96.0)

## 5. DOs and DON'Ts

### ✅ DO
- Use `DesignTokens.spaceMD` for standard padding.
- Use `SemanticColors.textSecondary(context)` for gray text.
- Use `Theme.of(context).textTheme` for text styles.
- Extract repeated UI patterns into widgets.

### ❌ DON'T
- Hardcode values like `Padding(all: 16.0)`.
- Use `Colors.grey` directly for text (ignores theme).
- Create custom styles unless absolutely necessary.
- Mix different spacing scales (e.g. 10.0, 15.0).
