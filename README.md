# Wig Try-On iOS 🎭📱

Native iOS app for real-time virtual wig try-on using ARKit Face Tracking.

## Features

- **ARKit Face Tracking** — Apple's high-accuracy face mesh (1220 vertices)
- **TrueDepth Camera** — Real depth data for accurate 3D positioning
- **3D Wig Models** — SceneKit rendering with realistic lighting
- **Real-time Preview** — 60 FPS smooth experience
- **Photo Capture** — Save try-on photos to Camera Roll

## Requirements

- **iPhone X or later** (requires TrueDepth camera)
- **iOS 15.0+**
- **Xcode 15.0+**

## Setup

1. Open `WigTryOn.xcodeproj` in Xcode
2. Select your development team in Signing & Capabilities
3. Connect your iPhone
4. Build and run (⌘R)

## Project Structure

```
WigTryOn/
├── WigTryOnApp.swift           # App entry point
├── ContentView.swift           # Main SwiftUI view
├── Views/
│   ├── ARViewContainer.swift   # ARKit view wrapper
│   ├── WigSelectorView.swift   # Wig selection UI
│   └── ControlsView.swift      # Adjustment controls
├── Models/
│   ├── Wig.swift               # Wig data model
│   └── WigManager.swift        # Wig loading/management
├── Services/
│   ├── ARFaceTracker.swift     # ARKit face tracking
│   └── WigRenderer.swift       # 3D wig rendering
├── Resources/
│   └── Wigs/                   # 3D wig models (.usdz, .scn)
└── Info.plist
```

## How It Works

```
TrueDepth Camera
       ↓
ARKit Face Tracking
       ↓
┌─────────────────────┐
│ Face Mesh (1220 pts)│
│ + Blend Shapes (52) │
│ + Head Transform    │
└──────────┬──────────┘
           ↓
   3D Wig Positioning
           ↓
   SceneKit Rendering
           ↓
      AR Preview
```

## Adding Wigs

Place 3D models in `Resources/Wigs/`:
- **Supported formats:** `.usdz`, `.scn`, `.dae`
- **Orientation:** Y-up, facing -Z
- **Scale:** Normalized to ~20cm head size

### Convert from .glb/.obj:

```bash
# Using Reality Converter (free from Apple)
# Or programmatically with Model I/O
```

## ARKit Face Tracking

The app uses ARKit's face tracking which provides:

| Feature | Description |
|---------|-------------|
| **Face Mesh** | 1220 vertices, real-time deformation |
| **Blend Shapes** | 52 facial expressions |
| **Head Pose** | Position + rotation in 3D space |
| **Eye Tracking** | Gaze direction |
| **Depth Map** | Per-pixel depth from TrueDepth |

## Controls

| Gesture | Action |
|---------|--------|
| Swipe Left/Right | Change wig |
| Pinch | Scale wig |
| Two-finger drag | Adjust position |
| Tap | Take photo |
| Long press | Reset |

## Privacy

- Camera access required (face tracking)
- Photo library access for saving (optional)
- No data leaves the device

## License

MIT License
