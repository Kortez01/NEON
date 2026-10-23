extends Node3D

# NEON REVENANT — native Godot 4.6 prototype (Windows desktop)
# All gameplay, geometry and VFX are generated procedurally. No HTML/browser runtime.

const WORLD_SIZE := 230.0
const PLAYER_WALK_SPEED := 7.8
const PLAYER_SPRINT_SPEED := 11.5
const PLAYER_DASH_SPEED := 25.0
const PLAYER_JUMP_SPEED := 9.0
const GRAVITY := 24.0

var rng := RandomNumberGenerator.new()
var elapsed := 0.0
var yaw := 0.0
var pitch := -0.10
var dash_direction := Vector3.FORWARD
var dash_left := 0.0
var dash_cooldown := 0.0
var shot_cooldown := 0.0
var pulse_cooldown := 0.0
var player_health := 100.0
var player_energy := 100.0
var score := 0
var drones_destroyed := 0

var player: CharacterBody3D
var camera: Camera3D
var rain: GPUParticles3D
var hud_stats: Label
var hud_message: Label
var hud_controls: Label
var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var pulse_rings: Array[Dictionary] = []
var trails: Array[Dictionary] = []

var building_mats: Array[StandardMaterial3D] = []
var window_mats: Array[StandardMaterial3D] = []
var window_transforms: Array = [[], [], [], []]
var neon_cyan: StandardMaterial3D
var neon_pink: StandardMaterial3D
var neon_red: StandardMaterial3D
var player_dark: StandardMaterial3D
var ground_mat: StandardMaterial3D
var road_mat: StandardMaterial3D
var puddle_mat: StandardMaterial3D
var shot_mat: StandardMaterial3D
var enemy_shot_mat: StandardMaterial3D


func _ready() -> void:
    rng.randomize()
    _make_material_library()
    _build_environment()
    _build_ground_and_roads()
    _build_city()
    _build_street_lights()
    _build_player()
    _build_drones()
    _build_rain()
    _build_hud()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    _update_camera(1.0)
    _refresh_hud()


func _make_material_library() -> void:
    ground_mat = _make_mat(Color(0.035, 0.038, 0.065), Color.BLACK, 0.0, 0.18, 0.68)
    road_mat = _make_mat(Color(0.018, 0.021, 0.038), Color.BLACK, 0.0, 0.32, 0.26)
    puddle_mat = _make_mat(Color(0.025, 0.065, 0.11, 0.88), Color(0.015, 0.13, 0.24), 0.30, 0.72, 0.12, true)
    neon_cyan = _make_mat(Color(0.10, 0.82, 1.0), Color(0.035, 0.72, 1.0), 4.2, 0.05, 0.22)
    neon_pink = _make_mat(Color(1.0, 0.12, 0.55), Color(1.0, 0.025, 0.24), 3.2, 0.05, 0.22)
    neon_red = _make_mat(Color(1.0, 0.08, 0.14), Color(1.0, 0.015, 0.035), 3.8, 0.08, 0.2)
    player_dark = _make_mat(Color(0.018, 0.025, 0.045), Color(0.01, 0.08, 0.11), 0.28, 0.32, 0.48)
    shot_mat = _make_mat(Color(0.35, 0.95, 1.0), Color(0.05, 0.85, 1.0), 5.5, 0.02, 0.18)
    enemy_shot_mat = _make_mat(Color(1.0, 0.12, 0.20), Color(1.0, 0.02, 0.06), 4.8, 0.0, 0.18)

    building_mats.append(_make_mat(Color(0.025, 0.032, 0.06), Color(0.005, 0.01, 0.03), 0.12, 0.42, 0.58))
    building_mats.append(_make_mat(Color(0.055, 0.045, 0.085), Color(0.015, 0.005, 0.04), 0.14, 0.5, 0.53))
    building_mats.append(_make_mat(Color(0.035, 0.06, 0.082), Color(0.0, 0.012, 0.025), 0.12, 0.55, 0.42))
    building_mats.append(_make_mat(Color(0.075, 0.06, 0.09), Color(0.02, 0.008, 0.025), 0.1, 0.4, 0.56))
    window_mats.append(_make_mat(Color(0.1, 0.8, 1.0), Color(0.06, 0.65, 1.0), 1.5, 0.0, 0.35))
    window_mats.append(_make_mat(Color(1.0, 0.22, 0.58), Color(0.95, 0.035, 0.25), 1.25, 0.0, 0.35))
    window_mats.append(_make_mat(Color(0.95, 0.58, 0.22), Color(0.95, 0.22, 0.035), 0.9, 0.0, 0.4))
    window_mats.append(_make_mat(Color(0.16, 0.24, 0.4), Color(0.04, 0.08, 0.16), 0.25, 0.0, 0.45))


func _make_mat(albedo: Color, emission: Color = Color(0, 0, 0), energy: float = 0.0, metal: float = 0.0, rough: float = 0.5, alpha_enabled: bool = false) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = albedo
    mat.metallic = metal
    mat.roughness = rough
    if energy > 0.0:
        mat.emission_enabled = true
        mat.emission = emission
        mat.emission_energy_multiplier = energy
    if alpha_enabled:
        mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    return mat


func _build_environment() -> void:
    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color(0.003, 0.005, 0.02)
    sky_material.sky_horizon_color = Color(0.055, 0.028, 0.10)
    sky_material.ground_bottom_color = Color(0.004, 0.006, 0.016)
    sky_material.ground_horizon_color = Color(0.025, 0.015, 0.045)
    sky_material.sun_angle_max = 10.0
    var sky := Sky.new()
    sky.sky_material = sky_material

    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.17, 0.20, 0.34)
    env.ambient_light_energy = 0.42
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.tonemap_exposure = 1.05
    env.glow_enabled = true
    env.glow_intensity = 1.25
    env.glow_strength = 1.35
    env.glow_bloom = 0.18
    env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
    env.ssao_enabled = true
    env.ssao_radius = 1.5
    env.ssao_intensity = 2.0
    env.ssil_enabled = true
    env.ssil_radius = 4.0
    env.ssil_intensity = 0.65
    env.ssr_enabled = true
    env.ssr_max_steps = 64
    env.ssr_fade_in = 0.15
    env.ssr_fade_out = 2.5
    env.fog_enabled = true
    env.fog_light_color = Color(0.06, 0.07, 0.15)
    env.fog_density = 0.008
    env.fog_sky_affect = 0.35
    env.volumetric_fog_enabled = true
    env.volumetric_fog_density = 0.018
    env.volumetric_fog_albedo = Color(0.22, 0.24, 0.40)
    env.volumetric_fog_emission = Color(0.012, 0.006, 0.035)
    env.volumetric_fog_length = 90.0
    env.volumetric_fog_detail_spread = 2.0

    var world := WorldEnvironment.new()
    world.environment = env
    add_child(world)

    var moonlight := DirectionalLight3D.new()
    moonlight.name = "Cool_Moonlight"
    moonlight.rotation_degrees = Vector3(-51.0, 32.0, 0.0)
    moonlight.light_color = Color(0.21, 0.25, 0.62)
    moonlight.light_energy = 0.32
    moonlight.shadow_enabled = true
    add_child(moonlight)


func _build_ground_and_roads() -> void:
    var ground_body := StaticBody3D.new()
    ground_body.name = "Ground_Collision"
    ground_body.position.y = -0.52
    add_child(ground_body)
    var ground_mesh := MeshInstance3D.new()
    var ground_shape_mesh := BoxMesh.new()
    ground_shape_mesh.size = Vector3(WORLD_SIZE, 1.0, WORLD_SIZE)
    ground_mesh.mesh = ground_shape_mesh
    ground_mesh.material_override = ground_mat
    ground_body.add_child(ground_mesh)
    var ground_collision := CollisionShape3D.new()
    var ground_shape := BoxShape3D.new()
    ground_shape.size = Vector3(WORLD_SIZE, 1.0, WORLD_SIZE)
    ground_collision.shape = ground_shape
    ground_body.add_child(ground_collision)

    _add_box(self, "Main_Avenue", Vector3(0, 0.015, 0), Vector3(15.0, 0.045, 205.0), road_mat)
    _add_box(self, "Cross_Avenue", Vector3(0, 0.018, 0), Vector3(205.0, 0.05, 15.0), road_mat)
    _add_box(self, "Avenue_Neon_Left", Vector3(-6.9, 0.06, 0), Vector3(0.045, 0.02, 205), neon_cyan)
    _add_box(self, "Avenue_Neon_Right", Vector3(6.9, 0.06, 0), Vector3(0.045, 0.02, 205), neon_pink)
    _add_box(self, "Cross_Line_1", Vector3(0, 0.06, -6.8), Vector3(205, 0.02, 0.045), neon_cyan)
    _add_box(self, "Cross_Line_2", Vector3(0, 0.06, 6.8), Vector3(205, 0.02, 0.045), neon_pink)

    for z in range(-96, 101, 12):
        _add_box(self, "Lane_Mark", Vector3(0, 0.065, float(z)), Vector3(0.12, 0.025, 3.2), neon_cyan)

    # Rain-dark puddles: low, glossy procedural patches on the street.
    for i in range(48):
        var p := Vector3(rng.randf_range(-6.1, 6.1), 0.058, rng.randf_range(-98, 98))
        var dims := Vector3(rng.randf_range(0.3, 2.2), 0.018, rng.randf_range(0.6, 3.0))
        var patch := _add_box(self, "Reflective_Puddle", p, dims, puddle_mat)
        patch.rotation.y = rng.randf_range(-0.5, 0.5)


func _build_city() -> void:
    for gx in range(-5, 6):
        for gz in range(-5, 6):
            # Leave a main avenue down the centre and a wider plaza at the intersection.
            if gx == 0:
                continue
            if gz == 0 and abs(gx) <= 1:
                continue
            var x := float(gx) * 16.0
            var z := float(gz) * 16.0
            var width := rng.randf_range(9.2, 11.8)
            var depth := rng.randf_range(9.4, 12.0)
            var height := rng.randf_range(16.0, 47.0)
            var building := StaticBody3D.new()
            building.name = "Tower_%d_%d" % [gx, gz]
            building.position = Vector3(x, height * 0.5, z)
            add_child(building)

            var shell := MeshInstance3D.new()
            var shell_mesh := BoxMesh.new()
            shell_mesh.size = Vector3(width, height, depth)
            shell.mesh = shell_mesh
            shell.material_override = building_mats[rng.randi_range(0, building_mats.size() - 1)]
            building.add_child(shell)

            var collider := CollisionShape3D.new()
            var box_shape := BoxShape3D.new()
            box_shape.size = Vector3(width, height, depth)
            collider.shape = box_shape
            building.add_child(collider)

            # Windows on the side facing the avenue. They share a small material palette.
            var face_x := x + (1.0 if x < 0.0 else -1.0) * (width * 0.5 + 0.035)
            var floor_y := 2.1
            while floor_y < height - 1.7:
                var window_z := z - depth * 0.5 + 1.05
                while window_z < z + depth * 0.5 - 0.5:
                    if rng.randf() > 0.18:
                        var wm_index := rng.randi_range(0, window_mats.size() - 1)
                        var window_size := Vector3(0.065, rng.randf_range(0.7, 1.25), rng.randf_range(0.48, 0.95))
                        var window_basis := Basis().scaled(window_size)
                        window_transforms[wm_index].append(Transform3D(window_basis, Vector3(face_x, floor_y, window_z)))
                    window_z += 1.95
                floor_y += 2.85

            # Sparse luminous facade bands and a rooftop crown.
            var band_mat: StandardMaterial3D = neon_cyan if rng.randf() > 0.5 else neon_pink
            if rng.randf() > 0.42:
                _add_box(self, "Facade_Light_Band", Vector3(face_x, height * 0.68, z), Vector3(0.09, 0.11, depth * 0.82), band_mat)
            if rng.randf() > 0.5:
                _add_box(self, "Rooftop_Sign", Vector3(x, height + 0.35, z), Vector3(width * 0.72, 0.18, 0.32), band_mat)

            # Dim service lights at each base help frame the street-level silhouette.
            if rng.randf() > 0.55:
                var base_glow := OmniLight3D.new()
                base_glow.position = Vector3(face_x * 0.995, 2.1, z)
                base_glow.light_color = Color(0.04, 0.45, 0.95) if x < 0 else Color(0.95, 0.05, 0.24)
                base_glow.light_energy = 0.65
                base_glow.omni_range = 5.0
                add_child(base_glow)

    _build_window_batches()


func _build_window_batches() -> void:
    # Batch thousands of lit windows into four MultiMeshes to avoid thousands of draw calls.
    for material_index in range(window_transforms.size()):
        var transforms: Array = window_transforms[material_index]
        if transforms.is_empty():
            continue
        var window_mesh := BoxMesh.new()
        window_mesh.size = Vector3.ONE
        var multimesh := MultiMesh.new()
        multimesh.transform_format = MultiMesh.TRANSFORM_3D
        multimesh.mesh = window_mesh
        multimesh.instance_count = transforms.size()
        for i in range(transforms.size()):
            multimesh.set_instance_transform(i, transforms[i])
        var batch := MultiMeshInstance3D.new()
        batch.name = "Window_Batch_%02d" % material_index
        batch.multimesh = multimesh
        batch.material_override = window_mats[material_index]
        add_child(batch)


func _build_street_lights() -> void:
    var pole_mat := _make_mat(Color(0.025, 0.032, 0.055), Color.BLACK, 0.0, 0.55, 0.5)
    for z in range(-90, 96, 18):
        for side_value in [-1.0, 1.0]:
            var side: float = float(side_value)
            var x: float = side * 7.8
            _add_cylinder(self, "Streetlight_Pole", Vector3(x, 2.15, float(z)), 4.3, 0.075, pole_mat)
            _add_box(self, "Lamp_Arm", Vector3(x - side * 0.38, 4.15, float(z)), Vector3(0.82, 0.07, 0.08), pole_mat)
            var light_color := Color(0.04, 0.72, 1.0) if side < 0.0 else Color(1.0, 0.04, 0.28)
            var lamp_mat := neon_cyan if side < 0.0 else neon_pink
            _add_box(self, "Lamp_Tube", Vector3(x - side * 0.72, 4.12, float(z)), Vector3(0.38, 0.10, 0.16), lamp_mat)
            var lamp := OmniLight3D.new()
            lamp.position = Vector3(x - side * 0.65, 3.95, float(z))
            lamp.light_color = light_color
            lamp.light_energy = 1.8
            lamp.omni_range = 10.5
            lamp.shadow_enabled = false
            add_child(lamp)


func _build_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Runner"
    player.position = Vector3(0, 0.08, 8.5)
    player.floor_snap_length = 0.35
    player.floor_max_angle = deg_to_rad(48.0)
    add_child(player)

    var collider := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.42
    capsule.height = 1.82
    collider.shape = capsule
    collider.position.y = 0.93
    player.add_child(collider)

    # Original placeholder character assembled from 3D parts; no copyrighted game assets.
    _add_box(player, "Runner_Jacket", Vector3(0, 1.23, 0), Vector3(0.62, 0.80, 0.36), player_dark)
    _add_box(player, "Runner_Hood_Back", Vector3(0, 1.64, 0.11), Vector3(0.50, 0.32, 0.28), player_dark)
    _add_sphere(player, "Runner_Head", Vector3(0, 1.79, -0.015), 0.22, player_dark)
    _add_box(player, "Energy_Seam", Vector3(0, 1.34, -0.188), Vector3(0.09, 0.59, 0.035), neon_cyan)
    _add_box(player, "Chest_Plate", Vector3(0, 1.28, -0.20), Vector3(0.34, 0.12, 0.035), neon_pink)
    _add_box(player, "Runner_Left_Arm", Vector3(-0.42, 1.25, 0), Vector3(0.19, 0.68, 0.22), player_dark)
    _add_box(player, "Runner_Right_Arm", Vector3(0.42, 1.25, 0), Vector3(0.19, 0.68, 0.22), player_dark)
    _add_box(player, "Left_Glove", Vector3(-0.43, 0.91, -0.015), Vector3(0.20, 0.15, 0.22), neon_cyan)
    _add_box(player, "Right_Glove", Vector3(0.43, 0.91, -0.015), Vector3(0.20, 0.15, 0.22), neon_pink)
    _add_box(player, "Runner_Left_Leg", Vector3(-0.17, 0.43, 0), Vector3(0.22, 0.72, 0.25), player_dark)
    _add_box(player, "Runner_Right_Leg", Vector3(0.17, 0.43, 0), Vector3(0.22, 0.72, 0.25), player_dark)
    _add_box(player, "Left_Boot", Vector3(-0.17, 0.095, -0.06), Vector3(0.25, 0.16, 0.40), player_dark)
    _add_box(player, "Right_Boot", Vector3(0.17, 0.095, -0.06), Vector3(0.25, 0.16, 0.40), player_dark)

    camera = Camera3D.new()
    camera.name = "ThirdPersonCamera"
    camera.fov = 76.0
    camera.near = 0.08
    camera.far = 235.0
    camera.current = true
    add_child(camera)


func _build_drones() -> void:
    var spawn_points: Array[Vector3] = [
        Vector3(-4.6, 6.2, -24.0),
        Vector3(4.8, 7.5, -43.0),
        Vector3(-3.8, 5.4, -59.0),
        Vector3(4.0, 8.0, -76.0),
        Vector3(-4.2, 6.5, -91.0),
        Vector3(3.5, 5.6, 24.0)
    ]
    for i in range(spawn_points.size()):
        var drone := Node3D.new()
        drone.name = "Security_Drone_%02d" % (i + 1)
        drone.position = spawn_points[i]
        add_child(drone)
        _add_sphere(drone, "Drone_Core", Vector3.ZERO, 0.42, neon_red)
        _add_box(drone, "Drone_Wing_Left", Vector3(-0.58, 0, 0), Vector3(0.65, 0.09, 0.18), player_dark)
        _add_box(drone, "Drone_Wing_Right", Vector3(0.58, 0, 0), Vector3(0.65, 0.09, 0.18), player_dark)
        _add_box(drone, "Drone_Front_Laser", Vector3(0, -0.02, -0.38), Vector3(0.28, 0.10, 0.12), neon_pink)
        _add_box(drone, "Drone_Rotor_Left", Vector3(-0.88, 0.10, 0), Vector3(0.35, 0.035, 0.32), neon_red)
        _add_box(drone, "Drone_Rotor_Right", Vector3(0.88, 0.10, 0), Vector3(0.35, 0.035, 0.32), neon_red)
        var glow := OmniLight3D.new()
        glow.position = Vector3(0, -0.05, 0)
        glow.light_color = Color(1.0, 0.025, 0.08)
        glow.light_energy = 1.4
        glow.omni_range = 7.0
        drone.add_child(glow)
        enemies.append({
            "node": drone,
            "hp": 100.0,
            "fire": rng.randf_range(1.4, 3.2),
            "phase": rng.randf_range(0.0, TAU),
            "base": spawn_points[i]
        })


func _build_rain() -> void:
    rain = GPUParticles3D.new()
    rain.name = "Rain_Field"
    rain.amount = 1450
    rain.lifetime = 1.35
    rain.preprocess = 0.65
    rain.speed_scale = 1.15
    rain.local_coords = false
    rain.visibility_aabb = AABB(Vector3(-75, -35, -75), Vector3(150, 75, 150))

    var process := ParticleProcessMaterial.new()
    process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    process.emission_box_extents = Vector3(42, 18, 42)
    process.direction = Vector3(0.015, -1.0, -0.08)
    process.spread = 3.5
    process.initial_velocity_min = 22.0
    process.initial_velocity_max = 31.0
    process.gravity = Vector3(0, -2.0, 0)
    rain.process_material = process

    var rain_mesh := BoxMesh.new()
    rain_mesh.size = Vector3(0.012, 0.52, 0.012)
    var rain_mat := _make_mat(Color(0.35, 0.66, 0.9, 0.65), Color(0.06, 0.16, 0.3), 0.22, 0.0, 0.35, true)
    rain_mesh.material = rain_mat
    rain.draw_pass_1 = rain_mesh
    rain.position = Vector3(0, 15, 0)
    add_child(rain)


func _build_hud() -> void:
    var canvas := CanvasLayer.new()
    canvas.name = "HUD"
    add_child(canvas)

    var title := Label.new()
    title.text = "N E O N   R E V E N A N T   //   SECTOR 07"
    title.position = Vector2(26, 20)
    title.size = Vector2(680, 36)
    title.add_theme_font_size_override("font_size", 23)
    title.add_theme_color_override("font_color", Color(0.25, 0.90, 1.0))
    title.add_theme_color_override("font_shadow_color", Color(0.0, 0.35, 0.65, 0.7))
    title.add_theme_constant_override("shadow_offset_x", 1)
    title.add_theme_constant_override("shadow_offset_y", 2)
    canvas.add_child(title)

    hud_stats = Label.new()
    hud_stats.position = Vector2(28, 62)
    hud_stats.size = Vector2(500, 120)
    hud_stats.add_theme_font_size_override("font_size", 17)
    hud_stats.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0))
    canvas.add_child(hud_stats)

    var mission := Label.new()
    mission.text = "OBJECTIVE  /  DISABLE THE SECURITY DRONES"
    mission.anchor_left = 0.5
    mission.anchor_right = 0.5
    mission.offset_left = -300
    mission.offset_right = 300
    mission.offset_top = 22
    mission.offset_bottom = 54
    mission.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    mission.add_theme_font_size_override("font_size", 17)
    mission.add_theme_color_override("font_color", Color(1.0, 0.28, 0.62))
    canvas.add_child(mission)

    var crosshair := Label.new()
    crosshair.text = "+"
    crosshair.anchor_left = 0.5
    crosshair.anchor_right = 0.5
    crosshair.anchor_top = 0.5
    crosshair.anchor_bottom = 0.5
    crosshair.offset_left = -14
    crosshair.offset_right = 14
    crosshair.offset_top = -20
    crosshair.offset_bottom = 20
    crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    crosshair.add_theme_font_size_override("font_size", 35)
    crosshair.add_theme_color_override("font_color", Color(0.45, 0.94, 1.0, 0.96))
    canvas.add_child(crosshair)

    hud_message = Label.new()
    hud_message.anchor_left = 0.5
    hud_message.anchor_right = 0.5
    hud_message.offset_left = -300
    hud_message.offset_right = 300
    hud_message.anchor_top = 0.5
    hud_message.anchor_bottom = 0.5
    hud_message.offset_top = 50
    hud_message.offset_bottom = 82
    hud_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hud_message.add_theme_font_size_override("font_size", 17)
    hud_message.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
    canvas.add_child(hud_message)

    hud_controls = Label.new()
    hud_controls.text = "WASD MOVE    C SPRINT    MOUSE AIM    LMB FIRE    SHIFT DASH    SPACE JUMP    Q / RMB PULSE    ESC FREE MOUSE"
    hud_controls.anchor_left = 0.0
    hud_controls.anchor_right = 1.0
    hud_controls.anchor_top = 1.0
    hud_controls.anchor_bottom = 1.0
    hud_controls.offset_left = 26
    hud_controls.offset_right = -26
    hud_controls.offset_top = -50
    hud_controls.offset_bottom = -18
    hud_controls.add_theme_font_size_override("font_size", 14)
    hud_controls.add_theme_color_override("font_color", Color(0.62, 0.75, 0.91))
    canvas.add_child(hud_controls)


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        yaw -= event.relative.x * 0.0024
        pitch = clampf(pitch + event.relative.y * 0.0018, -0.48, 0.42)
    elif event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
                Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
                if hud_message:
                    hud_message.text = "MOUSE RELEASED  —  click the game to resume aiming"
            else:
                Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
                if hud_message:
                    hud_message.text = ""
        elif event.keycode == KEY_Q:
            _pulse_blast()
        elif event.keycode == KEY_R:
            _reset_player()
    elif event is InputEventMouseButton and event.pressed:
        if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
            if hud_message:
                hud_message.text = ""
            return
        if event.button_index == MOUSE_BUTTON_LEFT:
            _shoot()
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            _pulse_blast()


func _physics_process(delta: float) -> void:
    elapsed += delta
    if player == null:
        return
    _update_timers(delta)
    if player_health > 0.0:
        _move_player(delta)
        _update_enemies(delta)
        _update_projectiles(delta)
    _update_pulse_rings(delta)
    _update_trails(delta)
    _update_camera(delta)
    _refresh_hud()
    if rain and player:
        rain.position = player.global_position + Vector3(0, 14, 0)


func _update_timers(delta: float) -> void:
    dash_left = maxf(0.0, dash_left - delta)
    dash_cooldown = maxf(0.0, dash_cooldown - delta)
    shot_cooldown = maxf(0.0, shot_cooldown - delta)
    pulse_cooldown = maxf(0.0, pulse_cooldown - delta)
    player_energy = minf(100.0, player_energy + 8.5 * delta)


func _move_player(delta: float) -> void:
    var input_dir := Vector2.ZERO
    if Input.is_key_pressed(KEY_W):
        input_dir.y += 1.0
    if Input.is_key_pressed(KEY_S):
        input_dir.y -= 1.0
    if Input.is_key_pressed(KEY_D):
        input_dir.x += 1.0
    if Input.is_key_pressed(KEY_A):
        input_dir.x -= 1.0
    if input_dir.length_squared() > 1.0:
        input_dir = input_dir.normalized()

    var forward := Vector3(-sin(yaw), 0, -cos(yaw))
    var right := Vector3(cos(yaw), 0, -sin(yaw))
    var wish_dir := (forward * input_dir.y + right * input_dir.x).normalized()

    if Input.is_key_pressed(KEY_SHIFT) and dash_cooldown <= 0.0 and player_energy >= 22.0 and player_health > 0.0:
        if wish_dir.length_squared() < 0.05:
            wish_dir = forward
        dash_direction = wish_dir.normalized()
        dash_left = 0.20
        dash_cooldown = 1.0
        player_energy -= 22.0
        _spawn_dash_trail()

    var vel := player.velocity
    if not player.is_on_floor():
        vel.y -= GRAVITY * delta
    elif vel.y < 0.0:
        vel.y = 0.0

    if Input.is_key_pressed(KEY_SPACE) and player.is_on_floor():
        vel.y = PLAYER_JUMP_SPEED

    if dash_left > 0.0:
        vel.x = dash_direction.x * PLAYER_DASH_SPEED
        vel.z = dash_direction.z * PLAYER_DASH_SPEED
        if rng.randf() > 0.56:
            _add_trail_spark(player.global_position + Vector3(0, 0.8, 0))
    else:
        var target_speed := PLAYER_SPRINT_SPEED if Input.is_key_pressed(KEY_C) else PLAYER_WALK_SPEED
        var target_horizontal := wish_dir * target_speed
        vel.x = move_toward(vel.x, target_horizontal.x, 28.0 * delta)
        vel.z = move_toward(vel.z, target_horizontal.z, 28.0 * delta)

    player.velocity = vel
    player.move_and_slide()
    if wish_dir.length_squared() > 0.04:
        player.rotation.y = lerp_angle(player.rotation.y, atan2(-wish_dir.x, -wish_dir.z), 10.0 * delta)


func _update_camera(delta: float) -> void:
    if player == null or camera == null:
        return
    var target := player.global_position + Vector3(0, 1.35, 0)
    var offset := Vector3(-sin(yaw) * 7.2, 2.65 + pitch * 4.0, cos(yaw) * 7.2)
    var desired := player.global_position + offset
    camera.global_position = camera.global_position.lerp(desired, 1.0 - exp(-7.5 * delta))
    camera.look_at(target, Vector3.UP)


func _shoot() -> void:
    if player_health <= 0.0 or shot_cooldown > 0.0 or player_energy < 2.0:
        return
    shot_cooldown = 0.145
    player_energy = maxf(0.0, player_energy - 2.0)
    var screen_center := get_viewport().get_visible_rect().size * 0.5
    var dir := camera.project_ray_normal(screen_center).normalized()
    var origin := player.global_position + Vector3(0, 1.37, 0) + dir * 0.58
    _spawn_projectile(origin, dir, false)


func _pulse_blast() -> void:
    if player_health <= 0.0 or pulse_cooldown > 0.0 or player_energy < 28.0:
        if hud_message and player_energy < 28.0:
            hud_message.text = "ENERGY LOW"
        return
    pulse_cooldown = 4.5
    player_energy -= 28.0
    if hud_message:
        hud_message.text = "ION PULSE"
    var ring := MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = 0.24
    torus.outer_radius = 0.34
    torus.rings = 32
    torus.ring_segments = 12
    ring.mesh = torus
    var ring_mat := _make_mat(Color(0.10, 0.82, 1.0, 0.48), Color(0.08, 0.8, 1.0), 3.8, 0.0, 0.2, true)
    ring.material_override = ring_mat
    ring.position = player.global_position + Vector3(0, 1.0, 0)
    add_child(ring)
    pulse_rings.append({"node": ring, "mat": ring_mat, "life": 0.42, "total": 0.42})

    for i in range(enemies.size() - 1, -1, -1):
        var e: Dictionary = enemies[i]
        var drone: Node3D = e["node"]
        if is_instance_valid(drone) and drone.global_position.distance_to(player.global_position) <= 10.5:
            _damage_enemy(i, 70.0)


func _spawn_projectile(origin: Vector3, direction: Vector3, from_enemy: bool) -> void:
    var bolt := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.12 if not from_enemy else 0.15
    sphere.height = sphere.radius * 2.0
    bolt.mesh = sphere
    bolt.material_override = enemy_shot_mat if from_enemy else shot_mat
    bolt.position = origin
    add_child(bolt)
    projectiles.append({
        "node": bolt,
        "dir": direction.normalized(),
        "speed": 38.0 if not from_enemy else 16.0,
        "life": 2.6 if not from_enemy else 3.8,
        "enemy": from_enemy
    })


func _update_enemies(delta: float) -> void:
    for i in range(enemies.size() - 1, -1, -1):
        var e: Dictionary = enemies[i]
        var drone: Node3D = e["node"]
        if not is_instance_valid(drone):
            enemies.remove_at(i)
            continue
        var base: Vector3 = e["base"]
        var phase: float = e["phase"]
        drone.global_position = Vector3(base.x + sin(elapsed * 0.75 + phase) * 1.25, base.y + sin(elapsed * 2.2 + phase) * 0.58, base.z + cos(elapsed * 0.48 + phase) * 1.3)
        var aim_point := player.global_position + Vector3(0, 1.0, 0)
        drone.look_at(aim_point, Vector3.UP)
        e["fire"] = float(e["fire"]) - delta
        if float(e["fire"]) <= 0.0 and drone.global_position.distance_to(player.global_position) < 46.0:
            var dir := (aim_point - drone.global_position).normalized()
            _spawn_projectile(drone.global_position + dir * 0.55, dir, true)
            e["fire"] = rng.randf_range(2.0, 3.4)
        enemies[i] = e


func _update_projectiles(delta: float) -> void:
    for i in range(projectiles.size() - 1, -1, -1):
        var p: Dictionary = projectiles[i]
        var node: MeshInstance3D = p["node"]
        if not is_instance_valid(node):
            projectiles.remove_at(i)
            continue
        var projectile_dir: Vector3 = p["dir"]
        node.global_position += projectile_dir * float(p["speed"]) * delta
        p["life"] = float(p["life"]) - delta
        var hit := false
        if bool(p["enemy"]):
            var target := player.global_position + Vector3(0, 1.0, 0)
            if node.global_position.distance_to(target) < 0.8:
                _damage_player(9.0)
                hit = true
        else:
            for j in range(enemies.size() - 1, -1, -1):
                var e: Dictionary = enemies[j]
                var drone: Node3D = e["node"]
                if is_instance_valid(drone) and node.global_position.distance_to(drone.global_position) < 0.83:
                    _damage_enemy(j, 34.0)
                    hit = true
                    break
        if hit or float(p["life"]) <= 0.0 or node.global_position.distance_to(player.global_position) > 125.0:
            node.queue_free()
            projectiles.remove_at(i)
        else:
            projectiles[i] = p


func _damage_enemy(index: int, amount: float) -> void:
    if index < 0 or index >= enemies.size():
        return
    var e: Dictionary = enemies[index]
    e["hp"] = float(e["hp"]) - amount
    if float(e["hp"]) <= 0.0:
        var drone: Node3D = e["node"]
        if is_instance_valid(drone):
            _spawn_explosion_ring(drone.global_position)
            drone.queue_free()
        enemies.remove_at(index)
        drones_destroyed += 1
        score += 100
        if hud_message:
            hud_message.text = "DRONE DISABLED  +100"
        if enemies.is_empty() and hud_message:
            hud_message.text = "SECTOR SECURED  —  PRESS R TO RESET"
    else:
        enemies[index] = e
        if hud_message:
            hud_message.text = "TARGET DAMAGED"


func _damage_player(amount: float) -> void:
    player_health = maxf(0.0, player_health - amount)
    if player_health <= 0.0 and hud_message:
        hud_message.text = "SYSTEM FAILURE  —  PRESS R TO REBOOT"


func _spawn_explosion_ring(pos: Vector3) -> void:
    var ring := MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = 0.2
    torus.outer_radius = 0.3
    ring.mesh = torus
    ring.material_override = neon_pink
    ring.global_position = pos
    add_child(ring)
    pulse_rings.append({"node": ring, "mat": neon_pink, "life": 0.28, "total": 0.28})


func _update_pulse_rings(delta: float) -> void:
    for i in range(pulse_rings.size() - 1, -1, -1):
        var effect: Dictionary = pulse_rings[i]
        var node: MeshInstance3D = effect["node"]
        if not is_instance_valid(node):
            pulse_rings.remove_at(i)
            continue
        effect["life"] = float(effect["life"]) - delta
        var t := clampf(1.0 - float(effect["life"]) / float(effect["total"]), 0.0, 1.0)
        var radius := lerpf(0.25, 8.0, t)
        node.scale = Vector3(radius, 1.0, radius)
        var mat: StandardMaterial3D = effect["mat"]
        if mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
            var c := mat.albedo_color
            c.a = maxf(0.0, 0.48 * (1.0 - t))
            mat.albedo_color = c
        if float(effect["life"]) <= 0.0:
            node.queue_free()
            pulse_rings.remove_at(i)
        else:
            pulse_rings[i] = effect


func _spawn_dash_trail() -> void:
    for i in range(5):
        _add_trail_spark(player.global_position + Vector3(rng.randf_range(-0.28, 0.28), rng.randf_range(0.3, 1.5), rng.randf_range(-0.3, 0.3)))


func _add_trail_spark(pos: Vector3) -> void:
    var spark := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = rng.randf_range(0.055, 0.12)
    sphere.height = sphere.radius * 2.0
    spark.mesh = sphere
    spark.material_override = neon_cyan
    spark.global_position = pos
    add_child(spark)
    trails.append({"node": spark, "life": 0.25, "total": 0.25})


func _update_trails(delta: float) -> void:
    for i in range(trails.size() - 1, -1, -1):
        var trail: Dictionary = trails[i]
        var node: MeshInstance3D = trail["node"]
        if not is_instance_valid(node):
            trails.remove_at(i)
            continue
        trail["life"] = float(trail["life"]) - delta
        var t := clampf(float(trail["life"]) / float(trail["total"]), 0.0, 1.0)
        node.scale = Vector3.ONE * t
        if float(trail["life"]) <= 0.0:
            node.queue_free()
            trails.remove_at(i)
        else:
            trails[i] = trail


func _reset_player() -> void:
    player_health = 100.0
    player_energy = 100.0
    player.velocity = Vector3.ZERO
    player.global_position = Vector3(0, 0.08, 8.5)
    dash_left = 0.0
    dash_cooldown = 0.0
    if hud_message:
        hud_message.text = "SYSTEM REBOOT COMPLETE"
    if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _refresh_hud() -> void:
    if hud_stats == null:
        return
    hud_stats.text = "VITALITY  %s  %3d%%\nENERGY    %s  %3d%%\nDRONES DISABLED  %d / 6     SCORE  %05d" % [
        _bar(player_health, 100.0, 13), int(round(player_health)),
        _bar(player_energy, 100.0, 13), int(round(player_energy)),
        drones_destroyed, score
    ]
    if player_health <= 0.0 and hud_message:
        hud_message.text = "SYSTEM FAILURE  —  PRESS R TO REBOOT"


func _bar(value: float, max_value: float, width: int) -> String:
    var lit := clampi(int(round(value / max_value * float(width))), 0, width)
    var result := ""
    for i in range(width):
        result += "■" if i < lit else "□"
    return result


func _add_box(parent: Node3D, label: String, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = label
    var mesh := BoxMesh.new()
    mesh.size = size
    instance.mesh = mesh
    instance.material_override = mat
    instance.position = pos
    parent.add_child(instance)
    return instance


func _add_sphere(parent: Node3D, label: String, pos: Vector3, radius: float, mat: Material) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = label
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 16
    mesh.rings = 8
    instance.mesh = mesh
    instance.material_override = mat
    instance.position = pos
    parent.add_child(instance)
    return instance


func _add_cylinder(parent: Node3D, label: String, pos: Vector3, height: float, radius: float, mat: Material) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = label
    var mesh := CylinderMesh.new()
    mesh.height = height
    mesh.top_radius = radius * 0.8
    mesh.bottom_radius = radius
    mesh.radial_segments = 10
    instance.mesh = mesh
    instance.material_override = mat
    instance.position = pos
    parent.add_child(instance)
    return instance
