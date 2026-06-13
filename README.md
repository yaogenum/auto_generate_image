# Cartoon World

An iOS SwiftUI prototype for a playful 3D digital cartoon world. The first playable slice starts in Shanghai and lets a digital person live inside a stylized city scene, upload real photos/videos, and turn those uploads into world assets.

## Current Features

- Real Shanghai seed data built from coordinates, translated into a stylized 3D world space.
- SceneKit-powered 3D cartoon city with ground, water, roads, building clusters, trees, selected-place rings, contribution beacons, lighting, and camera orbit controls.
- Digital person profile:
  - Random guest identity when the user has not registered.
  - Editable registered identity, home district, motto, and avatar state.
- Local life simulation:
  - Move between Shanghai places.
  - Perform daily actions that affect avatar energy.
- Photo/video import:
  - Uses PhotosPicker.
  - Assigns uploads to a map place.
  - Creates a local thumbnail/palette and simulates queued, stylizing, and integrated states.
- Local persistence through UserDefaults for the profile and contribution queue.

## Project

Open `CartoonWorld.xcodeproj` in Xcode.

Iteration history is tracked in `VERSION_HISTORY.md`.

Minimum target:

- iOS 17.0
- SwiftUI, SceneKit, CoreLocation, PhotosUI

Build from terminal after installing full Xcode and selecting it:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
./scripts/build_ios.sh
```

Run on Simulator after installing an iOS Simulator runtime in Xcode:

```bash
./scripts/run_ios_sim.sh
```

## Next Architecture Steps

The app is currently structured so the local prototype can evolve into the larger product:

- Replace `WorldModel.addContribution` simulated cartoonization with a backend job API.
- Store media assets in object storage instead of UserDefaults.
- Add vector-tile or 3D-tile city chunk loading for real-world-scale expansion beyond Shanghai.
- Add RealityKit city entities for deeper avatar walking, collisions, and place-entry interactions.
- Add account auth and sync once the registration model is connected to a server.
# auto_generate_image
