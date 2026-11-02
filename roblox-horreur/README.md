# 🩸 L'Asile des Ombres — jeu d'horreur Roblox

Tu te réveilles dans un asile plongé dans le noir. Trouve les **5 clés rouillées** cachées dans les couloirs, puis rejoins la **porte de SORTIE**… sans te faire attraper par **la Chose** aux yeux rouges.

## Gameplay

- **Labyrinthe différent à chaque manche**, construit par script (pas besoin de construire la carte).
- **Le monstre** erre dans les couloirs, puis te traque dès qu'il :
  - te **voit** (il voit beaucoup plus loin si ta **lampe est allumée**) ;
  - t'**entend courir** ;
  - te **sent** quand tu es tout près.
  Il devient plus rapide à chaque clé ramassée. Si tu le sèmes, il va fouiller le dernier endroit où il t'a vu.
- **Lampe torche** `[F]` : sa pile s'use. Elle grésille quand le monstre approche.
- **Course** `[Maj]` : limitée par l'endurance. Le monstre est plus rapide que toi quand tu marches, mais plus lent quand tu cours.
- **Peur** : battements de cœur, image qui tremble, couleurs qui se délavent, voile rouge quand il est proche.
- **Screamers** : sa tête en plein écran quand il t'attrape, apparitions fantômes au bout des couloirs, chuchotements.
- Lampes du plafond qui clignotent (et s'affolent quand il est proche), messages en lettres de sang sur les murs.
- Manches de 5 min : lobby → asile → survivants. Si le temps est écoulé, les lumières s'éteignent… et c'est fini.
- Multijoueur : les clés sont partagées par toute l'équipe.

## Installation dans Roblox Studio (copier-coller)

1. Ouvre Roblox Studio et crée un nouveau jeu **Baseplate** (le script supprime le Baseplate tout seul).
2. Crée les 4 scripts ci-dessous et colle le contenu de chaque fichier :

| Fichier | Où le créer dans l'Explorer | Type | Nom exact |
|---|---|---|---|
| `src/ReplicatedStorage/HorrorConfig.luau` | `ReplicatedStorage` | **ModuleScript** | `HorrorConfig` |
| `src/ServerScriptService/Maze.luau` | `ServerScriptService` | **ModuleScript** | `Maze` |
| `src/ServerScriptService/HorrorServer.server.luau` | `ServerScriptService` | **Script** | `HorrorServer` |
| `src/StarterPlayerScripts/HorrorClient.client.luau` | `StarterPlayer > StarterPlayerScripts` | **LocalScript** | `HorrorClient` |

3. Clique sur **Play** ▶️. Après 15 secondes de lobby, tu es envoyé dans l'asile.

### Avec Rojo (optionnel)

```bash
cd roblox-horreur
rojo serve
```
puis connecte-toi avec le plugin Rojo dans Studio.

## Ajouter des sons (fortement conseillé 🔊)

Les sons sont vides par défaut (le jeu fonctionne sans). Dans Studio, ouvre la **Toolbox → Audio**, cherche par exemple « heartbeat », « horror ambience », « scream », « whisper », copie l'ID de l'asset et colle-le dans `HorrorConfig` :

```lua
SOUNDS = {
	Ambient = "rbxassetid://TON_ID",
	Heartbeat = "rbxassetid://TON_ID",
	Scream = "rbxassetid://TON_ID",
	...
}
```

## Régler la difficulté

Tout est dans `HorrorConfig` : taille du labyrinthe, nombre de clés, vitesse du monstre, portée de vue/ouïe, durée de la pile, endurance, durée d'une manche…

- Plus facile : baisse `MONSTER_CHASE_SPEED`, augmente `BATTERY_MAX` ou `ROUND_TIME`.
- Plus dur : augmente `MAZE_WIDTH`/`MAZE_HEIGHT`, `KEY_COUNT` ou `MONSTER_ENRAGE_PER_KEY`, baisse `LAMP_RATIO`.
