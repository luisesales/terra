extends AudioStreamPlayer

class_name StreamPlayer

func _ready() -> void:		
	play()	
	await finished		
	queue_free()	
