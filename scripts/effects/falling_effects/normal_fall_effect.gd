extends FallEffect

const GRAVITY := 9.81

var active := false

func start(player):
	active = true
	player.gravity_provider.gravity_strength = GRAVITY
	player.gravity_provider.gravity_direction = Vector3.DOWN
	
func update(player, _delta):
	if not active:
		return
		
	player.playerbody.velocity.x = 0
	player.playerbody.velocity.z = 0
	
func stop(_player):
	active = false
