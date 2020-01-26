return {
	generator = {
		SURFACE_HEIGHT = 80,
		SURFACE_VARIATION = 100,
		SURFACE_OCTAVES = 4,
		SURFACE_FREQUENCY = 200,
		SURFACE_GAIN = 1,
		SURFACE_MIN = -400,
		SURFACE_MAX = 1000,
		Y_GAIN = 0.05,

		SEED = 1234,
	},
	physics = {
		FRICTION = 3,
		GRAVITY = 850, -- pixels/second
		TERMINAL_VELOCITY = 250, -- pixels/second
	},
	debug = {
		DRAW_CHUNK_BORDERS = false,
		SHOW_DATA = true,
	},
	keybinds = {
		PLAYER_MOVE_LEFT = "a",
		PLAYER_MOVE_RIGHT = "d",
		PLAYER_MOVE_UP = "w",
		PLAYER_MOVE_DOWN = "s",
		PLAYER_JUMP = "space",
	},
	TILE_REDRAWS_PER_SECOND = 15,
	MAX_TILE_UPDATES_PER_FRAME = math.huge,
	UNDERGROUND_DEPTH = 250,
	CHUNK_SIZE = 32,
	TILE_SIZE = 8,
	UNIT = 8,
	CHUNK_DRAW_RADIUS = 2,
	CHUNK_SIMULATION_RADIUS = 2,
	CHUNK_BUFFER_RADIUS = 3,
	CHUNK_COORDINATE_DIVIDER = "_",
	GAME_VERSION = "2.7.2 alpha",
	DATA_VERSION = "16",
}
