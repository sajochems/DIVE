extends FallEffect

func start(_player):
	pass
	
func update(player, _delta):
	stop(player)
	
func stop(_player):
	FallEffectManager.clear_active_impact()
