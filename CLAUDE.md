# approach-tree

A keyboard-driven desktop reference for algorithmic problem solving, built in Flutter.
You open it next to your editor while building something, describe your situation
("leaderboard", "depends on", "shortest", "stuck"), and it points you to the right
approach with a short, practical card. Placeholder name; rename freely.

## Purpose

- A reference to use while building, not a practice or memorization tool.
- It narrows the options; it doesn't hand you answers. You still verify and adapt.
- Built around confidence and a repeatable process for hard problems, not job interviews.
- Also intended as a tool for the WeDev club.

## Content scope

Every topic from Antti Laaksonen's *Competitive Programmer's Handbook*, organized by
the book's structure (Part → Chapter → topic), so it doubles as a map while reading.

- Part I, Basic techniques: ch. 1–10 (intro, time complexity, sorting, data structures,
  complete search, greedy, DP, amortized analysis, range queries, bit manipulation)
- Part II, Graph algorithms: ch. 11–20 (basics, traversal, shortest paths, tree algorithms,
  spanning trees, directed graphs, strong connectivity, tree queries, paths and circuits,
  flows and cuts)
- Part III, Advanced topics: ch. 21–30 (number theory, combinatorics, matrices, probability,
  game theory, strings, square root algorithms, segment trees revisited, geometry, sweep line)

Leaves are finer than book sections when a section has several distinct techniques
(e.g. §9.1 becomes prefix sums and sparse table). Each leaf cites its section (e.g. "CPH §9.2").

A separate `toolkit/` folder holds:
- **stuck? run the pipeline**: restate, small examples, brute force, find the waste, refine,
  state complexity
- **what fits my input size?**: n ≤ 10 → O(n!), ≤ 20 → O(2ⁿ), ≤ 500 → O(n³),
  ≤ 5000 → O(n²), ≤ 10⁶ → O(n log n) or O(n), larger → O(log n) or O(1)

## UI (see `tree-mockup.png`)

Dark, terminal-like look, inspired by broot/ranger.

- **Search bar** at top (`/` to focus). It matches labels, approach names, tags and aliases,
  case-insensitive, with all words required. It shows the match count.
- **Tree pane** on the left: `~/root/` → parts → chapters → leaves. Each leaf reads
  `situation label ···· approach name`. While searching, chapters with matches expand,
  matches are highlighted (with the matched `#tag` shown), and everything else dims but
  stays visible. Draw the guide lines with CustomPaint at fixed indents, not box-drawing
  characters, so alignment doesn't depend on the font.
- **Card pane** on the right for the selected leaf:
  - breadcrumb, title and alias chip, one-line lead
  - WHEN (bullets), HOW (short paragraph)
  - COST: time and space chips
  - YOUR SIZE: an input per variable in the complexity (n, m, k, q…). It estimates the
    steps and gives a verdict: fits (≤ 10⁸), tight (≤ 10⁹), too slow (more)
  - SKETCH: short Python code block with simple syntax highlighting
  - TRAPS (bullets), INSTEAD, IF… (bullets that link to other leaves)
- **Status bar** with keys: `↑↓` move, `→` open/expand, `←` back/collapse, `/` search,
  `p` pipeline, `esc` clear.

Colors: background #10151B, bars #0C1015, lines #1F2731, text #D3DAE3, dim #56616D,
folders #7AA2F7, approaches #9ECE6A, accent #FF9E64, selection #1A2430.
Fonts: system monospace (Cascadia Mono → Consolas → monospace) for the tree and code,
system sans for the card prose. No bundled or downloaded fonts.

## Data

- Content lives in YAML files under `assets/topics/`, one per part or chapter group, kept
  separate from UI code. Adding or editing an approach means editing YAML, not Dart.
- Discover the files with `AssetManifest`, sorted by file name.
- Each leaf has these fields: `id`, `section`, `label`, `name`, `alias?`, `lead`, `when[]`,
  `how`, `time`, `space`, `vars?`, `sketch?`, `traps[]`, `instead[] {if, target}`, `tags[]`.
- Each file names its top-level folder under `part: {id, prefix, title}` and lists
  `chapters: [{id, prefix, title, section, leaves}]` and/or `leaves:`. Files naming the same
  part merge in file-name order. Toolkit leaves may also use `steps[] {title, detail}` and
  `table[] {size, fits, examples}`.
- `time` must be parseable by the size calculator: `+`, `*`/`·`, `^`, `log`, `sqrt`, `!`,
  parentheses, and variables. It is the cost of the whole job (e.g. `O((n + q) log n)`), may
  carry a note after the `O(...)` ("average"), and `vars` gives a default for every variable.
- `test/content_test.dart` checks every topic file: ids, links, sections, parseable `time`.
- Accuracy matters more than volume. Complexities and claims must be correct.

## Tech

- Flutter 3.47 / Dart 3.13 (installed at `C:\Users\naksh\flutter\flutter`).
- Primary target is Windows desktop. Web is fine for quick previews.
- Dependencies: `yaml` only (already in the pub cache). Keep it minimal.
- Suggested layout: `lib/main.dart`, `lib/models/`, `lib/data/` (loading, search, complexity
  parser), `lib/ui/` (tree, card, search bar, status bar, theme).
- Run `flutter analyze` with no warnings. Unit-test the search matcher and the complexity parser.

## Working agreements

- Don't start building, publishing or generating artifacts until asked. Discuss first when
  the user is still talking.
- Keep the UI straightforward and very easy to use. Don't add features beyond this spec
  without asking.
