# approach-tree

A keyboard-driven desktop reference for algorithmic problem solving. Describe your situation
("leaderboard", "depends on", "shortest", "stuck") and it points you to the right approach,
with a short card: when to use it, how it works, its cost at your input size, a Python
sketch, traps, and what to use instead.

The content covers every topic in Antti Laaksonen's *Competitive Programmer's Handbook*,
organized by part and chapter, plus a toolkit with a problem-solving pipeline and an input
size table.

## Run

```
flutter run -d windows
```

Build a release: `flutter build windows --release` (output in `build/windows/x64/runner/Release`).

## Keys

| key | does |
| --- | --- |
| `/` | search by situation |
| `↑` `↓` | move (between matches while searching) |
| `→` / `Enter` | open a folder |
| `←` | close a folder, or go up |
| `p` | stuck? run the pipeline |
| `esc` | clear the search |

## Content

Topics live in `assets/topics/*.yaml`, one file per group of chapters. Editing an approach
means editing YAML, not Dart. The field list is in `CLAUDE.md`.

## Checks

```
flutter analyze
flutter test
```

`test/content_test.dart` validates every topic file: unique ids, working links, sections,
and that every time complexity parses.
