extends DirectionalLight3D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var dl0: DirectionalLight3D = get_node("/root/Main/DirectionalLight3D");
	var lbd: RichTextLabel = get_node("/root/Main/UI/lbDebug");
	var rrd = rad_to_deg(dl0.rotation.x);
	var rrnf = rrd * 0.002777;
	lbd.text = "RY: %f - %f" % [rrd, rrnf];
	
	
	self.rotation.x += delta * 0.1;
