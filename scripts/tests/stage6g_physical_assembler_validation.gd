extends Node3D
func _ready()->void:
	var dungeon:Node3D=$Stage6GProceduralPrototype; while not dungeon.nav_ready: await get_tree().physics_frame
	var map:RID=dungeon.get_world_3d().get_navigation_map(); var start:=NavigationServer3D.map_get_closest_point(map,dungeon.start_point); var finish:=NavigationServer3D.map_get_closest_point(map,dungeon.exit_point); var path:=NavigationServer3D.map_get_path(map,start,finish,true)
	var valid:bool=dungeon.proxies>0 and dungeon.nav_mesh.vertices.size()>0 and path.size()>1
	var forward:=await _walk(path,start,finish)
	var reverse_path:=NavigationServer3D.map_get_path(map,finish,start,true)
	var reverse:=await _walk(reverse_path,finish,start)
	valid=valid and forward and reverse
	print("6G BAKE valid=%s start=%s exit=%s path=%d forward=%s reverse=%s clearance=1.50"%[valid,start,finish,path.size(),forward,reverse])
	if valid: print("Stage6G physical assembler: PASS"); get_tree().quit(0)
	else: push_error("Stage6G physical assembler: FAIL"); get_tree().quit(1)

func _walk(path:PackedVector3Array,start:Vector3,target:Vector3)->bool:
	if path.size()<2:return false
	var body:=CharacterBody3D.new(); var collision:=CollisionShape3D.new(); var capsule:=CapsuleShape3D.new(); capsule.radius=.4; capsule.height=1.8; collision.shape=capsule; body.add_child(collision); add_child(body); body.global_position=Vector3(start.x,.9,start.z)
	var index:=1
	for tick in 800:
		# Rutas de corredores 6H pueden ser más largas y el bake da puntos densos.
		# Esto conserva move_and_slide/cápsula real, sin recovery ni teleport.
		while index<path.size() and Vector2(body.global_position.x,body.global_position.z).distance_to(Vector2(path[index].x,path[index].z))<.65:index+=1
		var goal:Vector3=target if index>=path.size() else path[index]; var flat:=goal-body.global_position; flat.y=0; body.velocity=flat.normalized()*24.0 if flat.length()>.01 else Vector3.ZERO; body.move_and_slide()
		if Vector2(body.global_position.x,body.global_position.z).distance_to(Vector2(target.x,target.z))<.35: body.queue_free(); return true
		await get_tree().physics_frame
	body.queue_free(); return false
