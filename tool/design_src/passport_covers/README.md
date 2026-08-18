# Passport cover masters

Source SVGs for the add menu's passport artwork. **Third-party, CC BY-SA 4.0** —
see `/ATTRIBUTIONS.md` at the repo root for the full credit block.

| File | Commons source | Author |
|---|---|---|
| `indian_passport_regular.svg` | [Indian Passport.svg](https://commons.wikimedia.org/wiki/File:Indian_Passport.svg) | Swapnil1101 |
| `indian_passport_epassport.svg` | [Indian Passport (e-Passport, 2024).svg](https://commons.wikimedia.org/wiki/File:Indian_Passport_(e-Passport,_2024).svg) | FireDragonValo |

Unlike the other files in `tool/design_src/`, these masters are **byte-identical
to what ships** — copied to `assets/wallet/passport/covers/` as-is rather than
rasterized. Two reasons:

1. They are flat two-colour path art (navy `#070930`, gold `#f4ca81`) — 94-98% of
   each file is `<path d="...">` data, with no gradients, filters, masks, text or
   embedded images. That is the case `flutter_svg` renders exactly, and the add
   menu draws them at two different heights, where vector wins.
2. Verbatim redistribution is the simplest CC BY-SA position: no adaptation, so
   the only obligation is attribution.

**Do not edit these files.** Any modification is a derivative work that must be
relicensed CC BY-SA and credited as modified. Compose effects around the widget
instead — `PassportCoverArt` applies shadow and rotation externally.

To refresh from Commons:

```bash
curl -L -o indian_passport_regular.svg \
  https://upload.wikimedia.org/wikipedia/commons/3/30/Indian_Passport.svg
curl -L -o indian_passport_epassport.svg \
  https://upload.wikimedia.org/wikipedia/commons/d/dd/Indian_Passport_%28e-Passport%2C_2024%29.svg
```
