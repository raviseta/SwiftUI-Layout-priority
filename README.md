# Layout Lab

A small, interactive SwiftUI project

## Video

https://github.com/user-attachments/assets/4f3bc3ae-7ac7-412f-934c-f0f59ddd8d9c

## Run

Open `Layout-priority.xcodeproj` in Xcode 27.2 or later, select the **Layout-priority** scheme and an iOS 27.2 simulator, and press Run. No packages, network access, or account setup are required by the app.

## Explore

- **Stacks:** pick A, B, or C, change its priority, and drag the available-width slider. Each block displays its actual measured width.
- **Layers:** change the text priority. Compare the solid ZStack boundary with the dashed outer frame and the measured size below.
- **Custom:** move the selected block by priority while preserving equal cell widths. Equal-priority blocks retain their original order.

Compare `0`, `1`, `100`, and `−1`. The code drawer follows the current experiment. VoiceOver labels include block priorities and measured widths. Animations respect Reduce Motion.

The examples deliberately use flexible shapes. Text, fixed-size content, and other containers can respond differently; these examples are not a universal sizing rule.
