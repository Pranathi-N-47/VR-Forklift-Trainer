# VR Forklift Operator Training Simulator
## Team Work Division & Migration Plan — 3 Person Split
### Based on Cloned Repository: `Ozymandias1/Godot-Forklift-Example`

> **Base Repository:** [Ozymandias1/Godot-Forklift-Example](https://github.com/Ozymandias1/Godot-Forklift-Example)  
> **Engine:** Godot 4.x  
> **Renderer:** Forward+  
> **Target Platform:** PC-based First-Person VR Simulator using OpenXR & XR Device Simulator  
> **Primary Asset Format:** GLB / GLTF  
> **Version Control:** Git + GitHub  
> **Main Training Scene:** `Scenes/MainTrainingFacility.tscn`

---

# 1. Project Overview & Architectural Shift

The project converts the third-person desktop forklift example (`Ozymandias1/Godot-Forklift-Example`) into a **First-Person VR Forklift Operator Training Simulator** designed for Godot 4 OpenXR and testable via the Godot XR Device Simulator.

### Core Training Experience Flow:
1. **Pre-Operation Inspection:** Player spawns in first-person outside the forklift, walks around using footstep audio, and inspects 4 mandatory zones (Mast/Forks, Tires/Wheels, Rear Counterweight, Cab).
2. **Mounting the Cab:** Player approaches the cab, triggers entry, and smoothly transitions into the seated first-person VR viewpoint inside the cabin (`FPSCamera` / `SeatMarker3D`).
3. **Control Familiarization:** Player learns fork elevation (raising and lowering forks with hydraulic audio) and driving controls.
4. **Driving Maneuver:** Player drives through marked training lanes delineated with traffic cones.
5. **Pallet Pickup:** Player approaches a loaded pallet, aligns forks, slides underneath, lifts the pallet (locking it to the fork carriage), and maintains a safe transport height.
6. **Transport & Placement:** Player navigates to the drop zone, sets the pallet down precisely within boundaries, and detaches the forks.
7. **Parking & Shutdown:** Player navigates to the marked parking bay, lowers forks flat to the ground, sets neutral/brake, and completes training.
8. **OSHA Evaluation:** Real-time scoring penalizes cone hits, warehouse collisions, speeding, and driving with forks raised too high.

---

# 2. Repository Audit: What to Retain, Remove, and Add

```
Godot-Forklift-Example (Cloned Base)
├── RETAIN: VehicleBody3D physics, forklift.glb, pallet.glb, drum.glb, engine/lift/footstep sounds, textures
├── REMOVE: 3D Godot Robot model, TPS player.tscn, CameraController.gd, TPSCamera node, animation tree
└── ADD:    OpenXR & XR Simulator, XRPlayer (XROrigin3D), Cab Seated Viewpoint, TrainingManager, VR UI, Warehouse
```

### Detailed Asset Breakdown:

| Category | Keep / Retain from Repo | Remove from Repo | Add New for VR Training |
|---|---|---|---|
| **Models (`Model/`)** | • `Model/Forklift/forklift.glb` (complete with chassis, wheels, mast, forks hierarchy)<br>• `Model/Pallet/pallet.glb` (standard wooden pallet)<br>• `Model/Drum/drum.glb` (metal cargo barrel) | • `Model/Character/3DGodotRobot.glb`<br>• `Model/Character/*Palette.png` (third-person robot textures) | • Safety traffic cones (`Model/Props/traffic_cone.glb` or CSG mesh)<br>• Warehouse modular structural pieces / shelving |
| **Scenes (`Scenes/`)** | • `Scenes/Templates/forklift.tscn` (core vehicle base)<br>• `Scenes/Templates/pallet_base.tscn`<br>• `Scenes/Templates/pallet_drum_type0.tscn`<br>• `Scenes/Templates/pallet_drum_type1.tscn` | • `Scenes/Templates/player.tscn` (third-person robot character scene) | • `Scenes/Player/xr_player.tscn` (`XROrigin3D`, `XRCamera3D`, controllers)<br>• `Scenes/Props/traffic_cone.tscn`<br>• `Scenes/UI/training_dashboard_ui.tscn` (cab world-space HUD)<br>• `Scenes/MainTrainingFacility.tscn` |
| **Scripts (`Scripts/`)** | • `Scripts/Forklift.gd` (retain VehicleBody3D driving, wheel physics, mast/fork translation, audio pitch logic) | • `Scripts/Player.gd` (desktop 3rd-person controller)<br>• `Scripts/PlayerAnimationTree.gd`<br>• `Scripts/CameraController.gd` (orbit spring-arm) | • `Scripts/Player/xr_player.gd`<br>• `Scripts/Player/viewpoint_controller.gd`<br>• `Scripts/Training/training_manager.gd`<br>• `Scripts/Training/score_manager.gd`<br>• `Scripts/Props/pallet_pickup_area.gd` |
| **Audio (`Sounds/`)** | • `Sounds/Engine/engine_heavy_loop.mp3` (continuous diesel/electric engine sound with dynamic pitch)<br>• `Sounds/Lift/qubodup-edev.mp3` (hydraulic lift sound)<br>• `Sounds/Footsteps/footstep00-09.ogg` (10 walking footsteps) | *None — all existing sound effects are directly usable!* | • Forklift reverse safety beeper (`Sounds/Forklift/reverse_beeper.wav`)<br>• Forklift horn (`Sounds/Forklift/horn.wav`)<br>• Collision impact thud (`Sounds/FX/impact.wav`) |
| **Addons & Textures** | • `addons/kenney_prototype_textures/` (orange, green, dark grid textures for floors, walls, and zones) | *None* | • Godot XR Tools or built-in OpenXR Device Simulator configuration |

---

# 3. Team Responsibilities (3-Person Split)

```
┌───────────────────────────────────────────────────────────────────────────────────┐
│                                 TEAM DIVISION                                     │
├─────────────────────────┬─────────────────────────┬───────────────────────────────┤
│ DEV A                   │ DEV B                   │ DEV C                         │
│ XR Player, Viewpoint,   │ Forklift Mechanics,     │ Training Logic, VR UI,        │
│ Cones & Pallet Cargo    │ Physics & Audio Systems │ Warehouse & OSHA Scoring      │
├─────────────────────────┼─────────────────────────┼───────────────────────────────┤
│ • Remove 3rd person     │ • Refactor Forklift.gd  │ • Convert TestScene to        │
│   robot & camera scripts│ • Retain VehicleBody3D  │   MainTrainingFacility.tscn   │
│ • Setup OpenXR & XR     │   driving & fork lift   │ • TrainingManager (9 stages)  │
│   Device Simulator      │ • Cab SeatMarker3D anchor│ • ScoreManager (OSHA rules)   │
│ • Build XRPlayer scene  │ • Pallet CarryPoint     │ • 3D World-space VR HUD       │
│ • Walking/Seated state  │   attachment snapping   │ • Inspection checkpoints      │
│   viewpoint controller  │ • Engine & Lift audio   │ • Driving lane markings,      │
│ • Reusable TrafficCone  │ • Add reverse beeper    │   pickup zone, drop zone,     │
│ • Pallet pickup area    │ • Controller input map  │   and parking bay             │
└─────────────────────────┴─────────────────────────┴───────────────────────────────┘
```

---

# 4. Project File Structure

Following migration from the cloned repo, the project will follow this structure:

```text
forklift-vr/
├── addons/
│   └── kenney_prototype_textures/      [RETAINED from repo]
├── Assets/
│   ├── Model/
│   │   ├── Forklift/
│   │   │   └── forklift.glb            [RETAINED from repo]
│   │   ├── Pallet/
│   │   │   └── pallet.glb              [RETAINED from repo]
│   │   ├── Drum/
│   │   │   └── drum.glb                [RETAINED from repo]
│   │   └── Props/
│   │       └── traffic_cone.glb        [NEW / CSG]
│   └── Sounds/
│       ├── Engine/
│       │   └── engine_heavy_loop.mp3   [RETAINED from repo]
│       ├── Lift/
│       │   └── qubodup-edev.mp3        [RETAINED from repo]
│       ├── Footsteps/
│       │   └── footstep00..09.ogg      [RETAINED from repo]
│       └── Forklift/
│           ├── reverse_beeper.wav      [NEW]
│           └── horn.wav                [NEW]
├── Scenes/
│   ├── MainTrainingFacility.tscn       [NEW - Primary Scene]
│   ├── Player/
│   │   └── xr_player.tscn              [NEW - Dev A]
│   ├── Forklift/
│   │   └── forklift.tscn               [REFACTORED from Scenes/Templates/forklift.tscn - Dev B]
│   ├── Props/
│   │   ├── traffic_cone.tscn           [NEW - Dev A]
│   │   ├── pallet_base.tscn            [REFACTORED from repo - Dev A]
│   │   ├── pallet_drum_type0.tscn      [RETAINED from repo - Dev A]
│   │   └── pallet_drum_type1.tscn      [RETAINED from repo - Dev A]
│   └── UI/
│       ├── training_dashboard_ui.tscn  [NEW - Dev C]
│       └── results_screen.tscn         [NEW - Dev C]
└── Scripts/
    ├── Player/
    │   ├── xr_player.gd                [NEW - Dev A]
    │   └── viewpoint_controller.gd     [NEW - Dev A]
    ├── Forklift/
    │   └── forklift_controller.gd      [REFACTORED from Scripts/Forklift.gd - Dev B]
    ├── Training/
    │   ├── training_manager.gd         [NEW - Dev C]
    │   ├── score_manager.gd            [NEW - Dev C]
    │   └── inspection_checkpoint.gd    [NEW - Dev C]
    └── Props/
        ├── pallet_cargo.gd             [NEW - Dev A]
        └── traffic_cone.gd             [NEW - Dev A]
```

---

# 5. Detailed Developer Breakdown

---

## 5.1 DEV A — XR Player, Viewpoint Controller, Cones & Pallets

### Primary Responsibility:
Dev A manages everything related to the player's presence in first-person VR, transitions between walking and driving, and physical training props (traffic cones and cargo pallets).

### Tasks:

#### A1. Repo Cleanup & Deprecation
- Delete `Scenes/Templates/player.tscn`.
- Delete `Scripts/Player.gd`, `Scripts/PlayerAnimationTree.gd`, and `Scripts/CameraController.gd`.
- Remove `Model/Character/` folder (`3DGodotRobot.glb` and palette PNGs).

#### A2. OpenXR & Simulator Setup
- Enable OpenXR in Godot Project Settings (`xr/openxr/enabled = true`).
- Configure Godot XR Device Simulator for development and testing without physical VR hardware.
- Add desktop fallback controls (WASD walking, mouse look) to test seamlessly inside the editor.

#### A3. First-Person VR Player (`Scenes/Player/xr_player.tscn` & `Scripts/Player/xr_player.gd`)
- Node hierarchy:
  ```text
  XRPlayer (CharacterBody3D)
  ├── CollisionShape3D (CapsuleShape3D, height ~1.75m)
  └── XROrigin3D
      ├── XRCamera3D (current = true, near = 0.05, far = 150.0)
      ├── LeftHand (XRController3D, tracker = "left_hand")
      └── RightHand (XRController3D, tracker = "right_hand")
  ```
- Implement smooth joystick locomotion and snap-turning for the walking phase.
- Hook into `Sounds/Footsteps/footstep00..09.ogg` to play periodic footstep sounds while walking.

#### A4. Seated Viewpoint & Cab Transition (`Scripts/Player/viewpoint_controller.gd`)
- Connect the player's mounting logic with the forklift's `SeatMarker3D`.
- When entering the forklift:
  1. Disable player's floor collision and character locomotion.
  2. Reparent or align `XROrigin3D` to the forklift's `SeatMarker3D` so the camera sits realistically inside the cab.
  3. Route controller joystick inputs directly to Dev B's forklift throttle and steering.
  4. Emit `seated_state_changed(true)`.
- When exiting the forklift:
  1. Restore player world collision at `ExitMarker3D` on the left side of the forklift.
  2. Restore roomscale/joystick walking locomotion.
  3. Emit `seated_state_changed(false)`.

#### A5. Reusable Traffic Cone (`Scenes/Props/traffic_cone.tscn`)
- Standard training cone with high-visibility orange/white material.
- `RigidBody3D` or `Area3D` detection to detect forklift impacts.
- Adds itself to the `traffic_cones` group.
- Emits signal `cone_knocked(cone_instance)` when collided with, forwarding to Dev C's `ScoreManager`.

#### A6. Pallets & Cargo (`Scenes/Props/pallet_base.tscn`)
- Retain `Model/Pallet/pallet.glb` and `Model/Drum/drum.glb` from cloned repo.
- Ensure pallet has proper collision channels so forks can slide into the fork pockets.
- Add an `Area3D` (`PickupArea`) centered between the stringers to detect when Dev B's forks are properly inserted.
- Expose helper functions:
  ```gdscript
  func get_cargo_weight() -> float
  func is_aligned_with_forks(fork_transform: Transform3D) -> bool
  func reset_position()
  ```

---

## 5.2 DEV B — Forklift Mechanics, Physics & Audio

### Primary Responsibility:
Dev B owns the forklift vehicle, adapting the cloned `VehicleBody3D` setup for first-person VR driving, mast/fork operations, audio systems, and pallet attachment mechanics.

### Tasks:

#### B1. Refactor `Scenes/Templates/forklift.tscn`
- Node hierarchy:
  ```text
  Forklift (VehicleBody3D)
  ├── CollisionShape3D (Chassis body collision)
  ├── Wheel_FL (VehicleWheel3D)
  ├── Wheel_FR (VehicleWheel3D)
  ├── Wheel_RL (VehicleWheel3D) [Steered / Rear-wheel drive]
  ├── Wheel_RR (VehicleWheel3D) [Steered / Rear-wheel drive]
  ├── Mast (Node3D)
  │   └── Forks (AnimatableBody3D / Node3D)
  │       ├── VisualForks (MeshInstance3D)
  │       ├── ForkCollision (CollisionShape3D)
  │       └── CarryPoint (Marker3D + Area3D)
  ├── SeatMarker3D (Marker3D - Head position inside cab for VR Camera)
  ├── ExitMarker3D (Marker3D - Ground spawn on driver's left side)
  ├── EnterCabArea (Area3D - Interaction trigger zone outside cab door)
  ├── Audio
  │   ├── EngineAudioPlayer (AudioStreamPlayer3D - looping engine sound)
  │   ├── LiftAudioPlayer (AudioStreamPlayer3D - hydraulic fork sound)
  │   ├── ReverseBeeperAudioPlayer (AudioStreamPlayer3D - pulsing beep)
  │   └── HornAudioPlayer (AudioStreamPlayer3D - horn blast)
  └── DashboardAnchor (Marker3D - Mounting point for Dev C's 3D VR HUD)
  ```
- **Remove:** `$TPSCamera` node and camera-switch logic.
- Retain `$FPSCamera` or replace with `SeatMarker3D` for VR player positioning.

#### B2. Forklift Vehicle Driving Physics (`Scripts/Forklift/forklift_controller.gd`)
- Retain Godot `VehicleBody3D` simulation:
  - Real forklift physics: **Rear-wheel steering** (Forklifts pivot around front wheels; turning while reversing swings the counterweight outward).
  - Acceleration, braking force, and engine torque curves tuned for training speeds (max speed ~12 km/h).
  - Dead zone handling on VR controller thumbsticks.
  - Expose API:
    ```gdscript
    func set_drive_input(throttle: float, steering: float, brake: float)
    func set_gear(forward: bool, reverse: bool, neutral: bool)
    ```

#### B3. Mast & Fork Vertical Movement
- Retain the vertical lerp/translation logic from cloned `Forklift.gd`:
  - Configurable limits: `min_fork_height = 0.05m`, `max_fork_height = 2.2m`, `travel_height = 0.2m`.
  - Fork raise/lower speed smoothly controlled via controller secondary thumbstick or trigger buttons.
  - While forks are moving, automatically trigger `LiftAudioPlayer.play()` and stop when idle.
  - Expose API:
    ```gdscript
    func set_fork_input(direction: float) # +1.0 raise, -1.0 lower
    func get_fork_height() -> float
    func is_fork_at_travel_height() -> bool
    ```

#### B4. Audio Systems Integration
- **Engine Sound:** Retain `Sounds/Engine/engine_heavy_loop.mp3`. Dynamically modulate `pitch_scale` based on forklift RPM and speed (idle pitch 0.8, full throttle pitch 1.4).
- **Hydraulic Lift Sound:** Retain `Sounds/Lift/qubodup-edev.mp3`. Loop smoothly during fork elevation changes.
- **Reverse Beeper:** Activate rhythmic pulsing beeper (`Sounds/Forklift/reverse_beeper.wav`) whenever vehicle throttle is in reverse.
- **Horn:** Trigger horn sound on designated VR controller button.

#### B5. Pallet Attachment & Carry Locking (`CarryPoint`)
- Lifting a physics `RigidBody3D` with dynamic contacts in VR often causes jitter.
- Implement magnetic/physical attachment:
  - When forks enter Dev A's `PickupArea` and lift above 0.15m:
    1. Lock pallet transform relative to `Forks/CarryPoint`.
    2. Set pallet to kinematic/frozen mode.
    3. Emit `pallet_picked_up(pallet_node)`.
  - When forks are lowered to floor level (<0.08m) in a drop zone:
    1. Unparent/detach pallet, restoring full RigidBody3D physics.
    2. Emit `pallet_released(pallet_node)`.

#### B6. Collision Reporting
- Forklift chassis collision emits `forklift_collided(collision_object, severity)` for Dev C's scoring manager.

---

## 5.3 DEV C — Training Progression, VR 3D UI, Environment & OSHA Scoring

### Primary Responsibility:
Dev C designs the training curriculum, creates the warehouse environment with OSHA signage and floor lanes, implements the step-by-step `TrainingManager` state machine, tracks penalties via `ScoreManager`, and delivers the in-cab world-space 3D UI.

### Tasks:

#### C1. Warehouse Environment (`Scenes/MainTrainingFacility.tscn`)
- Replace the simple test plane with a structured indoor warehouse environment using `kenney_prototype_textures`:
  - **Instructor Spawn / Briefing Area:** Where player spawns at session start.
  - **Forklift Bay:** Where the forklift is parked with 4 inspection zones.
  - **Training Course:** Marked yellow boundary lines and cone slalom.
  - **Pallet Staging Area (Pickup Zone):** Dedicated floor markings where initial cargo sits.
  - **Drop Zone:** Target placement zone with alignment box.
  - **Parking Bay:** Designated final parking spot with stop line.
  - OSHA safety posters and speed limit signs (5 km/h) placed along walls.

#### C2. Training State Machine (`Scripts/Training/training_manager.gd`)
- State machine managing the 9 sequential training phases:
  ```gdscript
  enum TrainingStage {
      STAGE_1_INSPECTION,     # Walk around & inspect 4 checkpoints
      STAGE_2_ENTER_CAB,       # Mount forklift and take seat
      STAGE_3_CONTROLS_CHECK,  # Raise and lower forks once
      STAGE_4_DRIVE_TO_PICKUP, # Drive through marked lane to pickup zone
      STAGE_5_PICKUP_PALLET,   # Align forks and pick up pallet safely
      STAGE_6_TRANSPORT_LOAD,  # Drive to drop zone keeping forks low
      STAGE_7_PLACE_PALLET,    # Lower and cleanly place pallet in target zone
      STAGE_8_PARK_FORKLIFT,   # Drive to parking bay, neutralize gear, drop forks
      STAGE_9_COMPLETED        # Display final OSHA scorecard & summary
  }
  ```
- Subscribes to signals from Dev A (`seated_state_changed`) and Dev B (`pallet_picked_up`, `pallet_released`, `fork_height_changed`).

#### C3. Inspection Checkpoint System (`Scripts/Training/inspection_checkpoint.gd`)
- 4 interactive triggers placed around the forklift during Stage 1:
  1. `Inspection_Front`: Verify mast, lift chains, and forks condition.
  2. `Inspection_LeftTires`: Verify front and rear tire wear and lug nuts.
  3. `Inspection_Rear`: Check counterweight and radiator/engine clearance.
  4. `Inspection_Cab`: Check seatbelt, controls, and overhead guard.
- Provides visual highlight (outline or 3D marker) when active, checks off when player steps inside and looks at component.

#### C4. OSHA Compliance & Scoring (`Scripts/Training/score_manager.gd`)
- Starting score: **100 Points**.
- Deductions:
  - Cone collision: `-5 points` per occurrence.
  - Structural/wall collision: `-10 points`.
  - Driving with forks above safe transport height (>0.3m): `-5 points` per warning.
  - Speeding in warehouse (>10 km/h): `-3 points`.
  - Pallet misplacement in drop zone: `-5 to -15 points` depending on offset.
- Time tracking: Records total duration from inspection to final parking.

#### C5. World-Space 3D VR Dashboard UI (`Scenes/UI/training_dashboard_ui.tscn`)
- Diegetic VR UI anchored to the forklift dashboard (`DashboardAnchor`) and floating clipboard:
  - Large, high-contrast readable typography optimized for VR headset resolutions.
  - Displays:
    - **Current Objective:** e.g., *"Drive to Pallet Pickup Area"*.
    - **Instructions:** e.g., *"Align forks squarely with pallet pockets. Keep forks 10-15cm above floor."*
    - **Current Score:** e.g., *"Score: 95 / 100"*.
    - **Active Warning Banner:** Flashing alert if driving with forks elevated or speeding.
- Final completion summary screen showing total score, penalties, time, and **PASS / FAIL** certification grade.

---

# 6. Step-by-Step Implementation Roadmap

```text
STAGE 1: Repo Cloning, Cleanup & OpenXR Setup
    ├── Clone Ozymandias1/Godot-Forklift-Example
    ├── Dev A: Delete 3rd-person robot, setup OpenXR + XR Device Simulator
    ├── Dev B: Clean Forklift.gd, remove TPSCamera, preserve VehicleBody3D & sounds
    └── Dev C: Set up MainTrainingFacility.tscn base layout

STAGE 2: First-Person VR Locomotion & Cab Viewpoint Transition
    ├── Dev A: Build XRPlayer (XROrigin3D), walking footstep audio
    ├── Dev B: Establish SeatMarker3D & cab collision hierarchy
    └── Dev A+B: Integrate viewpoint_controller.gd (Enter/Exit cab flow)

STAGE 3: Forklift Vehicle Driving & Fork Operation
    ├── Dev B: Map XR controller joysticks to VehicleBody3D drive & steering
    ├── Dev B: Map secondary controls to mast raise/lower with hydraulic audio
    ├── Dev B: Wire up dynamic engine pitch & reverse beeper
    └── Dev A: Build reusable TrafficCone.tscn and Pallet.tscn with collision

STAGE 4: Material Handling Loop (Pickup, Carry, Placement)
    ├── Dev A: Pallet PickupArea detection
    ├── Dev B: Fork CarryPoint attachment lock & release
    └── Dev B+A: Tuning physical stability while driving with pallet

STAGE 5: Pre-Op Inspection & Training State Machine
    ├── Dev C: Implement TrainingManager 9-stage state machine
    ├── Dev C: Place 4 inspection triggers around forklift
    └── Dev C: Wire stage transitions from Dev A & Dev B events

STAGE 6: Warehouse Training Course & Scoring
    ├── Dev C: Build cone slalom course, pickup zone, drop zone, parking bay
    ├── Dev C: Implement ScoreManager (OSHA compliance & penalties)
    └── Dev A: Connect cone collision signals to ScoreManager

STAGE 7: Diegetic VR UI & Feedback
    ├── Dev C: Mount 3D VR Dashboard UI into forklift cab
    ├── Dev C: Real-time objective, instruction, score, and warning prompts
    └── Dev C: Final performance evaluation screen

STAGE 8: Polish, Balance & XR Device Simulator Playtesting
    ├── Full team: Playtest end-to-end training loop using XR Device Simulator
    ├── Tune steering responsiveness, fork speeds, and collision boundaries
    └── Ensure audio balance: engine, lift, reverse beeper, footsteps
```

---

# 7. Controls & Input Mapping

The simulator supports both OpenXR VR Controllers (XR Device Simulator / VR Headsets) and keyboard fallback for rapid desktop testing:

| Action | VR Left Controller | VR Right Controller | Desktop Testing Fallback |
|---|---|---|---|
| **Walking Move** | Thumbstick (Axes 0, 1) | — | W / A / S / D |
| **Walking Turn** | — | Thumbstick X (Snap/Smooth) | Mouse / Q, E |
| **Enter / Exit Cab** | Grip / Trigger near door | Grip / Trigger near door | E or Space |
| **Forklift Throttle / Reverse** | — | Thumbstick Y (Up/Down) | W (Forward) / S (Reverse) |
| **Forklift Steering** | Thumbstick X (Left/Right) | — | A (Left) / D (Right) |
| **Fork Raise / Lower** | — | Trigger (Raise) / Grip (Lower) | R (Raise) / F (Lower) |
| **Forklift Horn** | Primary Button (X/A) | Primary Button (A) | H |
| **Brake** | Thumbstick Down / Grip | Thumbstick Down / Grip | Spacebar |

---

# 8. Git Branching & Collaboration Guidelines

### Branch Structure:
```text
main
├── dev/xr-player-props       (Dev A)
├── dev/forklift-mechanics    (Dev B)
└── dev/training-ui-warehouse (Dev C)
```

### Critical Collaboration Rules:
1. **Never commit directly to `main`:** All work must be completed on feature branches and merged via pull request after verification.
2. **Scene Isolation:** Developers must avoid simultaneously editing the same `.tscn` file.
   - Dev A owns `Scenes/Player/*` and `Scenes/Props/*`.
   - Dev B owns `Scenes/Forklift/*`.
   - Dev C owns `Scenes/MainTrainingFacility.tscn` and `Scenes/UI/*`.
3. **Signal-Based Communication:** Systems must remain decoupled through Godot signals. For example, `Forklift.gd` emits `pallet_picked_up`, which `TrainingManager.gd` connects to—neither script directly accesses internal member variables of the other.
4. **Preserve Cloned Audio & Meshes:** Do not re-encode or relocate audio files in `Sounds/` or models in `Model/Forklift/` to prevent broken `.import` dependencies.

---

# 9. Definition of Done (Final Deliverable)

The project is complete when an operator, running the simulator through Godot OpenXR / XR Device Simulator, can independently complete the following sequence:

```text
[1. Spawn outside forklift] 
      ↓
[2. Walk around and clear all 4 inspection zones with footstep audio]
      ↓
[3. Mount cab → Camera snaps smoothly to seated 1st-person VR viewpoint]
      ↓
[4. Test fork controls → Forks raise/lower with hydraulic audio]
      ↓
[5. Drive through marked cone course → Rear-wheel steering & engine audio response]
      ↓
[6. Enter pickup area → Align forks → Pick up loaded pallet]
      ↓
[7. Transport pallet to drop zone → Warning triggers if forks exceed safe height]
      ↓
[8. Lower forks and place pallet neatly inside drop zone box]
      ↓
[9. Reverse to parking bay with audible reverse beeper → Lower forks flat]
      ↓
[10. Complete session → View OSHA score, penalties, time, and pass/fail summary]
```
