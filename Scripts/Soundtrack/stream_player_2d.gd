extends AudioStreamPlayer2D

class_name StreamPlayer2D

func _ready() -> void:		
	max_distance = 500	
	play()	
	await finished		
	queue_free()	
