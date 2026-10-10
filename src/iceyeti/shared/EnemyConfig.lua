-- Central defaults and named enemy definitions.
-- Template Attributes override definitions; definitions override these defaults.
local EnemyConfig = {}

EnemyConfig.TemplateFolderName = "EnemyTemplates"
EnemyConfig.SpawnFolderName = "EnemySpawnPoints"
EnemyConfig.ActiveFolderName = "ConfiguredEnemies"

EnemyConfig.Defaults = {
	Level = 1,
	Damage = 10,
	MaxHealth = 100,
	MoveSpeed = 12,
	SpawnCount = 1,
	MinDay = 1,
	MaxDay = 100,
	SpawnEnabled = true,
}

EnemyConfig.Types = {
	Common = { Level = 1, Damage = 10, MaxHealth = 100, MoveSpeed = 12 },
	Elite = { Level = 5, Damage = 20, MaxHealth = 250, MoveSpeed = 14 },
	Ancient = { Level = 10, Damage = 35, MaxHealth = 600, MoveSpeed = 16 },
}

return EnemyConfig
