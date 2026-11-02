-- HorrorConfig (ModuleScript dans ReplicatedStorage)
-- Tous les réglages du jeu sont ici : modifie-les pour rendre le jeu plus ou moins dur.

local Config = {
	-- Labyrinthe
	CELL_SIZE = 16, -- taille d'une case en studs
	MAZE_WIDTH = 12, -- nombre de cases en X
	MAZE_HEIGHT = 12, -- nombre de cases en Z
	WALL_HEIGHT = 12,
	BRAID_RATIO = 0.12, -- proportion de murs supprimés en plus (crée des boucles pour semer le monstre)
	LAMP_RATIO = 0.14, -- proportion de cases avec une lampe au plafond

	-- Partie
	KEY_COUNT = 5,
	MIN_PLAYERS = 1,
	INTERMISSION = 15, -- secondes dans le lobby avant une manche
	ROUND_TIME = 300, -- durée max d'une manche (secondes)

	-- Joueur
	WALK_SPEED = 12,
	SPRINT_SPEED = 20,
	STAMINA_MAX = 100,
	STAMINA_DRAIN = 22, -- par seconde en courant
	STAMINA_REGEN = 14, -- par seconde sans courir
	BATTERY_MAX = 100,
	BATTERY_DRAIN = 2.2, -- par seconde lampe allumée
	BATTERY_REGEN = 1.2, -- par seconde lampe éteinte

	-- Monstre
	MONSTER_GRACE = 12, -- secondes avant que le monstre se réveille
	MONSTER_WANDER_SPEED = 8,
	MONSTER_CHASE_SPEED = 16,
	MONSTER_ENRAGE_PER_KEY = 0.6, -- vitesse en plus par clé ramassée
	MONSTER_SIGHT_RANGE = 45, -- portée de vue si le joueur est dans le noir
	MONSTER_SIGHT_RANGE_LIGHT = 85, -- portée de vue si la lampe du joueur est allumée
	MONSTER_HEAR_RANGE = 30, -- entend les joueurs qui courent
	MONSTER_SENSE_RANGE = 9, -- sent toujours les joueurs très proches
	MONSTER_KILL_RANGE = 4.5,

	-- Sons (optionnels) : colle ici des ID de sons du Creator Store, ex. "rbxassetid://1234567890"
	-- Laisser vide = pas de son (le jeu fonctionne quand même).
	SOUNDS = {
		Ambient = "", -- ambiance en boucle
		Heartbeat = "", -- battements de cœur (boucle)
		Scream = "", -- cri du screamer
		Sting = "", -- son quand le monstre te repère
		Whisper = "", -- chuchotements
		KeyPickup = "", -- ramassage de clé
		Flashlight = "", -- clic de la lampe
	},
}

return Config
