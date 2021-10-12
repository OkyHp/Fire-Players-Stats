<h1 align="center">Fire Players Stats - Statistics plugin for CS:GO servers</h1>
<p align="center">
	<img src="https://github.com/OkyHp/fire-players-stats/blob/master/.gitdata/FPS_Menus.png?raw=true" height="210">
	<img src="https://github.com/OkyHp/fire-players-stats/blob/master/.gitdata/FPS_BigLogo.png?raw=true" height="210">
	<img src="https://github.com/OkyHp/fire-players-stats/blob/master/.gitdata/FPS_ChatMessages.png?raw=true" height="210">
</p>

## Statistics Information:

 - Support only **CS:GO**.
 - Statistics work based on **ELO [Levels Ranks](https://github.com/levelsranks/levels-ranks-core)** formula. Its essence is that you get 1000 experience points and after calibration average rank. Depending on how well you play, your rank depends.
 - Statistics only works with **MySQL** and is designed to work with **[WEB Interface](https://hlmod.ru/resources/levels-ranks-actual-adaptive-web.1291/)** that has FPS support!
 - Ranks number of is not limited. Setup is done through the command **sm_fps_create_default_ranks** or manually by sending an SQL query.
 - Combined database for several servers with a normal structure.
 - Weapon statistics are stored in separate table, because of which, when new weapon is released, it is not necessary to change the plugin and database.
 - Statistics is trying to fix the superiority of new players over old ones when calculating points. This is calibration function!
 - KillStrick: Additional points are credited within 10 seconds after the kill, after which there is a reset.
 - It's possible to set limit for resetting time statistics for the user.
 - Information on gained/lost points is displayed only at the end of the round or player die.
 - Point values ​​are stored in float.
 - Plugin supports ability to make rank transfers.
 - Plugin supports bonus for killing with particular weapon taking into account map (You can specify different for different maps).

### It's important to understand that statistics on functionality are very similar to LR, because it was taken as a basis, but plugin was written completely from scratch! He is deprived of possible problems of LR, but may have new ones!

<!-- <details><summary>Меню плагина</summary> </details> -->

 [**_List of modules for statistics_**](https://gitlab.com/OkyHp/fire-players-stats/tree/master/FPS_Modules)

 > Thanks for the implementation ideas: [Someone](https://hlmod.ru/members/someone.73313/), [Wend4r](https://hlmod.ru/members/wend4r.105753/), [M0st1ce](https://hlmod.ru/members/m0st1ce.95027/).

## Plugin Commands:

### For players:

**_sm_pos_**, **_sm_position_** - Player Position on Server. \
**_sm_stats_**, **sm_rank**, **sm_fps** - Statistics main menu. \
**_sm_top_** - List of available tops. Using the points, kdr, time, clutch arguments opens the corresponding top.​

### For admin:

**_sm_fps_create_default_ranks_** - Creating default rank preset.\
	⋅⋅⋅ **0** - Default CS:GO Competitive ranks (18 lvl)\
 	⋅⋅⋅ **1** - Danger Zone Ranks (15 lvl)\
 	⋅⋅⋅ **2** - Facet ranks (10 lvl)
**sm_fps_reset_all_stats** - Reset all server statistics.

## Requirements

  - [**Sourcemod 1.10+**](https://www.sourcemod.net/downloads.php?branch=stable)
  - [**SteamWorks (Optional)**](https://users.alliedmods.net/~kyles/builds/SteamWorks/)

## Installation

 1. Download current version from repository..
 2. Place contents of archive in desired directories on server.
 4. Add a section with your database settings to `addons/sourcemod/configs/databases.cfg`:
	```
	"fire_players_stats"
	{
		"driver"			"mysql"
		"host"				""
		"database"			""
		"user"				""
		"pass"				""
		"port"				"3306"
	}
	```
 5. Start server so that plugin creates necessary tables in database..
 6. Enter the `sm_fps_create_default_ranks` command to use default ranks preset.\
 		**0** - Default CS:GO Competitive ranks (18 lvl),\
 		**1** - Danger Zone Ranks (15 lvl),\
 		**2** - Facet ranks (10 lvl),
 	<details><summary>Or load rank settings manually by sending an SQL query to database, having previously adjusted it to your needs:</summary>

	```sql
	INSERT INTO `fps_ranks` (`rank_id`, `rank_name`, `points`) 
	VALUES 
		('1', 'Silver I',				'0'),
		('1', 'Silver II',				'700'), 
		('1', 'Silver III',				'800'), 
		('1', 'Silver IV',				'850'), 
		('1', 'Silver Elite',				'900'), 
		('1', 'Silver Elite Master',			'925'), 
		('1', 'Gold Nova I',				'950'), 
		('1', 'Gold Nova II',				'975'), 
		('1', 'Gold Nova III',				'1000'), 
		('1', 'Gold Nova Master',			'1100'), 
		('1', 'Master Guardian I',			'1250'), 
		('1', 'Master Guardian II',			'1400'), 
		('1', 'Master Guardian Elite',			'1600'), 
		('1', 'Distinguished Master Guardian',		'1800'), 
		('1', 'Legendary Eagle',			'2100'), 
		('1', 'Legendary Eagle Master',			'2400'), 
		('1', 'Supreme Master First Class',		'3000'), 
		('1', 'The Global Elite',			'4000');
	```

	</details>

**Topic on [HLMOD](https://hlmod.ru/resources/fire-players-stats.1232/)**.
**[Support | Discord server](https://discord.gg/M82xN4y)**.
