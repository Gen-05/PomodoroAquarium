# Start title logo: q tail and bubble dot

- `start_title_logo_original.png`: unchanged 1440×3120 original, backed up outside Assets.
- `q_tail_mask.png`: only the tail end of adopted reference A (source crop x=300, y=337, 61×44). White ink was separated using the same luminance threshold as the supplied render.swift; the rest of the reference logo is not used.
- `update_logo.swift`: repeatable local composition. It edits the q descender in x=440…513, y=1667…1722 and clears the old i dot in x=795…872, y=1508…1557. It preserves original canvas, sRGB, straight alpha and all decoded RGBA pixels outside those regions. Run from the repository root with `swift Design/StartTitleLogo/update_logo.swift`.

The reference stem (24px) is mapped to the existing q stem (27px), leaving the bowl and other glyphs untouched. The forked tail remains above the unchanged Japanese name.

The independent circular i dot is centered at original PNG (815,1537), radius 14px. These coordinates and the mirrored fish mouth are mapped by StartSurfaceLayout; neither the fish nor the logo is repositioned.

Bubble motion follows the supplied render.swift: three emissions at 0.45/0.69/0.93s, 2.65s travel, dot forms from 3.08s over 0.48s. After the last bubble arrives at approximately 3.58s, the completed round dot is held indefinitely. There is no fade-out or repeat; background resume retains progress/completion, and a newly opened Preview gets a new clock. Radii and arc amplitude are adapted to the existing i stem size. Rendering shares the water MTKView's existing 30fps update, without another timer, image sequence or video.

Imagegen was used for a candidate shape study, with the existing q as edit target and adopted A as shape reference. That candidate is not bundled; the final glyph uses only the adopted A tail mask so all other pixels stay exact. Prompt: “Modify ONLY the bottom tip of the q descender into a small, rounded two-lobed fish tail like reference A. Keep the q bowl, counter, upright stroke width, position and proportions exactly. White monochrome, transparent background; no other text, shadows or decorations.”
