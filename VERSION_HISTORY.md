# Version History

This file records product and implementation iterations for the Cartoon World iOS app.

## 0.1.0 - 2026-06-13

### Scope

Initial playable SwiftUI prototype for a cartoon 3D world map app, starting from Shanghai.

### Added

- Created `CartoonWorld.xcodeproj` as the iOS app project.
- Added SwiftUI app entry and tab shell:
  - World map
  - Media upload
  - Digital person profile
- Built a Shanghai seed world using real coordinates:
  - The Bund
  - Lianhua Road life circle
  - Lujiazui
  - Xujiahui
  - People's Square
  - Century Park
- Added MapKit-based world map with realistic elevation style.
- Added cartoon 3D overlay with isometric ground tiles and stylized building clusters.
- Added place pins, place carousel, selected-place camera focus, and cartoon layer toggle.
- Added digital person model:
  - Random guest profile when unregistered
  - Editable registered profile
  - Avatar mood and energy state
  - Daily actions per place
- Added photo/video upload flow using `PhotosPicker`.
- Added local contribution pipeline:
  - Select media
  - Assign to a Shanghai place
  - Generate local thumbnail and color palette
  - Simulate queued, stylizing, and integrated states
- Added local persistence for profile and contributions through `UserDefaults`.
- Added README with project purpose, current features, build command, and next architecture steps.

### Verification

- Swift syntax parse passed for all app source files using `swiftc -parse`.
- Xcode project plist validation passed with `plutil`.
- Asset catalog JSON validation passed with `python3 -m json.tool`.

### Known Limitations

- Full iOS build and simulator launch were not run because the current machine only has Command Line Tools selected and no full Xcode/iOS SDK available.
- Cartoonization is currently a local simulated pipeline, not an AI/backend generation service.
- Media is stored locally in lightweight form; production storage should move to object storage or a database-backed asset service.
- The 3D city layer is SwiftUI-rendered; RealityKit/SceneKit city exploration is a future expansion.

### Next Candidates

- Add real backend account registration and sync.
- Add server-side cartoonization job API.
- Add persistent map asset service with geospatial indexing.
- Add RealityKit place-entry mode for true 3D walking exploration.
- Expand the Shanghai seed map with district-level chunks and POI categories.

## 0.1.1 - 2026-06-13

### Scope

Xcode verification and local developer workflow hardening.

### Changed

- Added an explicit shared Xcode scheme for `CartoonWorld`.
- Added explicit iOS/iOS Simulator supported platform settings to the Xcode project.
- Fixed the thumbnail border drawing call in `WorldModel`.
- Removed unnecessary `await` usage in local contribution status advancement.
- Added `scripts/build_ios.sh` for repeatable simulator builds.
- Added `scripts/run_ios_sim.sh` to build, create or reuse a simulator, install, and launch the app when an iOS Simulator runtime is available.
- Updated README build/run commands to use the scripts.
- Set Debug `ONLY_ACTIVE_ARCH` to `NO` so target-based simulator builds do not emit active-architecture warnings.

### Verification

- `xcodebuild -project CartoonWorld.xcodeproj -target CartoonWorld -configuration Debug -sdk iphonesimulator build CODE_SIGNING_ALLOWED=NO` succeeded.
- Generated app path: `build/Debug-iphonesimulator/CartoonWorld.app`.

### Known Limitations

- Simulator launch could not be completed because no available iOS Simulator runtime is currently installed or registered in CoreSimulator; `xcrun simctl list runtimes available` returned no iOS runtimes.

## 0.1.2 - 2026-06-13

### Scope

Simulator runtime detection and launch workflow repair.

### Changed

- Fixed `scripts/run_ios_sim.sh` runtime parsing for Xcode 26.3 / iOS 26.3 output.
- Fixed booted simulator UDID parsing by stripping parentheses from `simctl` text output.
- Changed the run script to prefer an already booted `CartoonWorld-iPhone`, then any booted simulator, before creating a new simulator.
- Added pre-install cleanup in the run script:
  - Terminate existing `com.codex.CartoonWorld` process.
  - Uninstall existing `com.codex.CartoonWorld` app.
  - Install the freshly built app.
  - Launch the app.

### Verification

- `xcrun simctl list runtimes available` now detects `iOS 26.3`.
- `./scripts/run_ios_sim.sh` succeeded end to end.
- App launched on Simulator with process id `22937`.
- Captured simulator screenshot at `artifacts/cartoonworld-simulator.png` and verified the map, cartoon city overlay, digital avatar panel, and tab bar render correctly.

### Notes

- Earlier install hangs were caused by stale/multiple booted simulator state plus install coordination conflicts. Keeping one booted simulator and uninstalling the existing bundle before install resolved it.

## 0.2.0 - 2026-06-13

### Scope

Reworked the world page from a map-first prototype into a true 3D digital cartoon world.

### Changed

- Replaced the MapKit-first world surface with a SceneKit-powered 3D scene.
- Added `CartoonWorldSceneView` as the primary world renderer.
- Translated real Shanghai coordinate seed data into local 3D world positions.
- Added 3D world geometry:
  - Ground platform
  - River/water band
  - Road network
  - Stylized building clusters
  - Park trees
  - Transit hub geometry
  - Lifestyle district shapes
  - Animated digital avatar
  - Selected-place ring
  - Contribution beacon geometry
  - Ambient and directional lighting
- Enabled camera orbit controls through `SCNView`.
- Removed in-scene text labels after visual QA showed they cluttered and flattened the 3D world.
- Kept place chips and the avatar panel as the 2D control layer over the 3D world.
- Updated README wording to describe the app as a 3D digital cartoon world, not a map overlay.

### Verification

- `./scripts/run_ios_sim.sh` built, installed, and launched successfully.
- App launched successfully through `./scripts/run_ios_sim.sh`.
- Captured `artifacts/cartoonworld-3d-world-v2-wait.png`.
- Visual QA confirmed the world tab now shows a rendered 3D cartoon city scene rather than a 2D map background.

## 0.2.1 - 2026-06-13

### Scope

Redrew the 3D world after visual QA feedback that the first SceneKit version was too plain and unattractive.

### Changed

- Reworked the world art direction toward a stylized anime open-world diorama reference:
  - Larger floating island
  - Broad ocean backdrop
  - Mountain range
  - River and harbor zones
  - Warm paths and crosswalk highlights
  - Brighter clouds and glowing contribution beacons
- Replaced generic square place bases with octagonal place platforms.
- Added place-specific landmarks:
  - Bund fantasy street block
  - Lujiazui fantasy skyline with pearl tower silhouette
  - People's Square transit hub
  - Century Park pond and denser trees
- Added layered fantasy roofs, warmer lit windows, lanterns, piers, boats, and more varied city silhouettes.
- Adjusted camera orthographic scale and Shanghai coordinate scale so the world reads as one cohesive 3D cartoon scene on mobile.
- Expanded the ocean plane so its edge no longer appears as a large blue diamond in the camera view.

### Verification

- `./scripts/build_ios.sh` succeeded.
- `./scripts/run_ios_sim.sh` built, installed, and launched successfully.
- Captured `artifacts/cartoonworld-3d-genshin-inspired-v2.png`.
- Visual QA confirmed the world is now a 3D floating cartoon city scene with terrain, harbor, mountain, landmark, avatar, and interaction overlays.

## 0.2.2 - 2026-06-13

### Scope

Shifted the world experience toward a stronger open-world interaction model and added a real 3D map fallback after the cartoon art direction still failed visual expectations.

### Changed

- Added `WorldCity` and expanded `WorldPlace` with explicit city ownership.
- Replaced the Shanghai-only seed with `WorldSeed`:
  - Shanghai expanded from 6 to 15 places.
  - Tokyo added with 12 initial places.
  - Total city nodes now cover landmarks, transport hubs, parks, neighborhoods, and lifestyle zones.
- Added world mode switching on the world screen:
  - `真实3D` uses MapKit hybrid realistic elevation.
  - `卡通沙盘` keeps the SceneKit fantasy cartoon world.
- Added city switching between Shanghai and Tokyo.
- Added open-world-inspired interaction structure:
  - Exploration progress
  - Current tracked objective
  - Place discovery chips
  - Tap-to-track map annotations
  - Quick action button for the selected place
- Updated profile stats from Shanghai-only wording to dual-city wording.

### Verification

- `./scripts/build_ios.sh` succeeded after the data model, MapKit, and UI changes.
- Simulator install/launch verification was attempted but blocked by CoreSimulator install service instability:
  - `simctl install` returned an InstallCoordination promise error on one booted device.
  - A second device attempt hung during install and was terminated.
  - The generated screenshot `artifacts/cartoonworld-real3d-shanghai.png` showed the Simulator home screen, not the app, so it is not accepted as visual QA evidence.

### Notes

- The code build is valid, but current local Simulator installation state needs cleanup before visual QA. Recommended cleanup path: quit Simulator, run `xcrun simctl shutdown all`, erase the target simulator from Simulator.app or `xcrun simctl erase <UDID>`, then retry `./scripts/run_ios_sim.sh`.

## 0.2.3 - 2026-06-13

### Scope

Made the world overlay collapsible after visual QA showed the expanded exploration controls blocked too much of the 3D map.

### Changed

- Added an expandable/collapsible bottom exploration panel on the world screen.
- Expanded mode keeps the full controls:
  - City switch
  - Display mode switch
  - Stats
  - World header
  - Quest tracker
  - Place carousel
  - Avatar panel
- Collapsed mode now shows only a compact status strip:
  - Current city
  - Selected place
  - Display mode
  - Exploration percentage
- Added a clear `展开` / `收起` button with chevron icon.
- Added animated bottom transition so the map becomes usable immediately after collapse.

### Verification

- `./scripts/build_ios.sh` succeeded.

## 0.2.4 - 2026-06-13

### Scope

Added Hong Kong as the third supported city and continued UI cleanup before another simulator run.

### Changed

- Added `香港` to `WorldCity`.
- Expanded `WorldSeed` with 12 Hong Kong places:
  - Central
  - Victoria Harbour
  - Victoria Peak
  - Tsim Sha Tsui
  - Mong Kok
  - Causeway Bay
  - Wan Chai
  - Hong Kong International Airport
  - Hong Kong Station
  - Lantau Island
  - West Kowloon Cultural District
  - Sha Tin
- Total seeded city nodes increased from 27 to 39.
- Changed the world exploration panel to default collapsed so the map is visible on first launch.
- Changed the world screen default city to Hong Kong for immediate verification of the new city.
- Added Hong Kong-specific real 3D map camera distance and heading.
- Updated upload copy and place menu labels to include city names.
- Updated profile stats from dual-city wording to three-city wording.
- Tightened the collapsed world panel height and hid the world navigation bar so the 3D map gets the full first screen.
- Hardened `scripts/run_ios_sim.sh` with timeout-protected `simctl` operations so simulator hangs do not block indefinitely.

### Verification

- `./scripts/build_ios.sh` succeeded.
- `SIMCTL_TIMEOUT=20 ./scripts/run_ios_sim.sh` succeeded and launched the app in the booted iPhone 16e Simulator.
- Captured visual QA screenshot: `artifacts/cartoonworld-hongkong-open-v3.png`.
