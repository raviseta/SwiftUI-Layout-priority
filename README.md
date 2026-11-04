# Layout Lab

A small, interactive SwiftUI project inspired by [Natalia Panferova’s article, “The role of layout priority in SwiftUI containers”](https://nilcoalescing.com/blog/TheRoleOfLayoutPriorityInSwiftUIContainers/).

## Run

Open `Layout-priority.xcodeproj` in Xcode 27.2 or later, select the **Layout-priority** scheme and an iOS 27.2 simulator, and press Run. No packages, network access, or account setup are required by the app.

## Explore

- **Stacks:** pick A, B, or C, change its priority, and drag the available-width slider. Each block displays its actual measured width.
- **Layers:** change the text priority. Compare the solid ZStack boundary with the dashed outer frame and the measured size below.
- **Custom:** move the selected block by priority while preserving equal cell widths. Equal-priority blocks retain their original order.

Compare `0`, `1`, `100`, and `−1`. The code drawer follows the current experiment. VoiceOver labels include block priorities and measured widths. Animations respect Reduce Motion.

The examples deliberately use flexible shapes. Text, fixed-size content, and other containers can respond differently; these examples are not a universal sizing rule.

## Verify

Press **Cmd+U** in Xcode, or run:

```sh
xcodebuild -project Layout-priority.xcodeproj \
  -scheme Layout-priority \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  CODE_SIGNING_ALLOWED=NO test
```

The hosted tests measure real SwiftUI geometry for equal, positive, and negative priorities; ZStack sizing; stable custom ordering; and empty/narrow custom layouts.

## Share

`Share/` contains the demo recording, screenshots, and LinkedIn copy. The video records the running app, with no simulated layout graphics.

For a repeatable 24-second tour, add `--tour` under **Edit Scheme → Run → Arguments**. Remove it for normal interaction. To start on a particular screen, use `--experiment layers --priority 1` (experiments: `stacks`, `layers`, `custom`).

The SwiftUI views, styling, measurement overlays, controls, and recording tour were built for this demo. The original article is credited inside the app and in the LinkedIn post.
