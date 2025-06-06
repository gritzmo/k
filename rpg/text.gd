extends Label

enum state{ready, reading, finished}

var currentstate = state.ready

func _ready():
 print("starting state is ready")
 pass

func changestate(nextstate):
 currentstate = nextstate
 match currentstate:
  state.ready:
   print("state is ready")
   pass
  state.reading:
   print("state is reading")
   pass
  state.finished:
   print("state is finished")
   pass

	
		


