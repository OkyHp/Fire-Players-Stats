#if defined _fire_players_stats_included
 #endinput
#endif
#define _fire_players_stats_included

public SharedPlugin __pl_fire_players_stats= 
{
	name = "FirePlayersStats",
	file = "FirePlayersStats.smx",
	#if defined REQUIRE_PLUGIN
		required = 1
	#else
		required = 0
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_fire_players_stats_SetNTVOptional()
{
	MarkNativeAsOptional("FPS_StatsLoad");
	MarkNativeAsOptional("FPS_GetDatabase");
	MarkNativeAsOptional("FPS_ClientLoaded");
	MarkNativeAsOptional("FPS_ClientReloadData");
	MarkNativeAsOptional("FPS_DisableStatisPerRound");
	MarkNativeAsOptional("FPS_GetPlayedTime");
	MarkNativeAsOptional("FPS_GetPoints");
	MarkNativeAsOptional("FPS_GetLevel");
	MarkNativeAsOptional("FPS_GetRanks");
	MarkNativeAsOptional("FPS_GetMaxRanks");
	MarkNativeAsOptional("FPS_GetStatsData");
	MarkNativeAsOptional("FPS_IsCalibration");
	MarkNativeAsOptional("FPS_AddFeature");
	MarkNativeAsOptional("FPS_RemoveFeature");
	MarkNativeAsOptional("FPS_IsExistFeature");
	MarkNativeAsOptional("FPS_MoveToMenu");
	MarkNativeAsOptional("FPS_StatsActive");
	MarkNativeAsOptional("FPS_GetID");
	MarkNativeAsOptional("FPS_GetPosition");
	MarkNativeAsOptional("FPS_GetPlayersCount");
	MarkNativeAsOptional("FPS_GetAllRanks");
	MarkNativeAsOptional("FPS_PrintToChat");
	MarkNativeAsOptional("FPS_PrintToChatAll");
}
#endif

#define FPS_INC_VER				154
#define UID(%0)					GetClientUserId(%0)
#define CID(%0)					GetClientOfUserId(%0)
#define SZF(%0)					%0, sizeof(%0)

enum StatsData
{
	KILLS = 0,
	DEATHS,
	ASSISTS,
	MAX_ROUNDS_KILLS,
	ROUND_WIN,
	ROUND_LOSE,
	PLAYTIME
};

enum FeatureMenus
{
	FPS_STATS_MENU = 0,	// Statistics menu section
	FPS_TOP_MENU,		// TOP menu section
	FPS_ADVANCED_MENU	// Additional menu section
};

enum StatsID
{
	FPS_SERVER_ID = 0,
	FPS_RANK_ID
};

/**
 *	Called when the core/statistics are loaded.
 *
 *	@noparams
 *	@noreturn
*/
forward void FPS_OnFPSStatsLoaded();

/**
 *	Called when database connection has been established.
 *
 *	@param hDatabase		Database handle.
 *	@noreturn
*/
forward void FPS_OnDatabaseConnected(Database hDatabase);

/**
 *	Called when database connection has been lost.
 *
 *	@noparams
 *	@noreturn
*/
forward void FPS_OnDatabaseLostConnection();

/**
 *	Called when player data has been loaded.
 *
 *	@param iClient			Player index.
 *	@param fPoints			Player points.
 *	@noreturn
*/
forward void FPS_OnClientLoaded(int iClient, float fPoints);

/**
 *	Called before setting points to player.
 *
 *	@param iAttacker			Attacker index.
 *	@param iVictim				Victim index.
 *	@param hEvent				Event handle.
 *	@param fAddPointsAttacker	Count of add points for killing.
 *	@param fAddPointsVictim		Count of deduct points for killing.
 *	@return						Plugin_Stop or Plugin_Handled - Block give of experience points for player. Does not affect weapon statistics and extra points;
 								Plugin_Continue - Allow issuance of experience unchanged;
 								Plugin_Changed - Allow issuance of experience with change fAddPointsAttacker and fAddPointsVictim.

*/
forward Action FPS_OnPointsChangePre(int iAttacker, int iVictim, Event hEvent, float &fAddPointsAttacker, float &fAddPointsVictim);

/**
 *	Called after setting points to player.
 *
 *	@param iAttacker			Attacker index.
 *	@param iVictim				Victim index.
 *	@param fPointsAttacker		Count of attacker points.
 *	@param fPointsVictim		Count of victim points.
 *	@noreturn
*/
forward void FPS_OnPointsChange(int iAttacker, int iVictim, float fPointsAttacker, float fPointsVictim);

/**
 *	Called after level change.
 *
 *	@param iClient				Player index.
 *	@param iOldLevel			Old player level.
 *	@param iNewLevel			New player level.
 *	@noreturn
*/
forward void FPS_OnLevelChange(int iClient, int iOldLevel, int iNewLevel);

/**
 *	Called after receiving player’s position.
 *
 *	@param iClient				Player index.
 *	@param iPosition			Player's current position.
 *	@param iPlayersCount		All players count.
 *	@noreturn
*/
forward void FPS_PlayerPosition(int iClient, int iPosition, int iPlayersCount);

/**
 *	Called when updating data in top, etc., after saving statistics.
 *
 *	@noparams
 *	@noreturn
*/
forward void FPS_OnSecondDataUpdated();

/**
 *	Called when resetting statistics for a player.
 *
 *	@param iClient				Индекс игрока.
 *	@noreturn
*/
forward void FPS_OnResetGeneralStats(int iClient);

/**
 *	Called when all statistics are reset.
 *
 *	@noreturn
*/
forward void FPS_OnFPSResetAllStats();



/**
 *	Get state core/stats
 *
 *	@noparams
 *	@return						true - Loaded.
 * 								false - Not loaded.
*/
native bool FPS_StatsLoad();

/**
 *	Get database handle. After use, you must close handle using CloseHandle() or delete.
 *
 *	@noparams
 *	@return						Database handle.
*/
native Database FPS_GetDatabase();

/**
 *	Get player state.
 *
 *	@param iClient				Player index.
 *	@return						true - Player data is loaded.
 * 								false - Player data is not load.
*/
native bool FPS_ClientLoaded(int iClient);

/**
 *	Relaod player data.
 *
 *	@param iClient				Player index.
 *	@noreturn
*/
native void FPS_ClientReloadData(int iClient);

/**
 *	Disable statistics for 1 round.
 *  Use only after event of end round and no later than event of beginning new round.
 *
 *	@noreturn
*/
native void FPS_DisableStatisPerRound();

/**
 *	Get played time for player.
 *
 *	@param iClient				Player index.
 *	@return						Played time.
*/
native int FPS_GetPlayedTime(int iClient);

/**
 *	Get player points count.
 *
 *	@param iClient				Player index.
 *	@param bSession				Get data for game session.
 *	@return						Player points count.
*/
native float FPS_GetPoints(int iClient, bool bSession = false);

/**
 *	Get current level.
 *
 *	@param iClient				Player index.
 *	@return						Current level.
*/
native int FPS_GetLevel(int iClient);

/**
 *	Get current rank.
 *
 *	@param iClient				Player index.
 *	@param szBufferLevelName	Buffer to record rank name.
 *	@param iMaxLength			Buffer size.
 *	@noreturn
*/
native void FPS_GetRanks(int iClient, char[] szBufferRank, int iMaxLength);

/**
 *	Get all ranks count. Gets value at start of map.
 *
 *	@return						All ranks count.
*/
native int FPS_GetMaxRanks();

/**
 *	Get player data
 *
 *	@param iClient				Player index.
 *	@param eData				Type of data to receive. Don't use MAX_ROUNDS_KILLS, it`s service variable!
 *	@param bSession				Get data for game session.
 *	@return						Player data.
*/
native int FPS_GetStatsData(int iClient, StatsData eData, bool bSession = false);

/**
 *	Get calibration status.
 *
 *	@param iClient				Player index.
 *	@return						true - Player is calibrating.
 * 								false - Player is calibrated.
*/
native bool FPS_IsCalibration(int iClient);

/////////////////////////////////////////////////////////////////////////////////

/**
 *	Called when an item is pressed.
 *
 *	@param iClient				Player index.
 *	@return						true - Returns back to main section.
*/
typedef FPS_ItemSelectCallback		= function bool (int iClient);

/**
 *	Called when item is displayed.
 *
 *	@param iClient				Player index.
 *	@param szDisplay			Buffer with name of item.
 *	@param iMaxLength			Buffer size.
 *	@return						true - Set new name with szDisplay.
*/
typedef FPS_ItemDisplayCallback		= function bool (int iClient, char[] szDisplay, int iMaxLength);

/**
 *	Called when accessing an item.
 *
 *	@param iClient				Player index.
 *	@param iStyle				Current item style.
 *	@return						New style for item (ITEMDRAW_DEFAULT, ITEMDRAW_DISABLED, ITEMDRAW_RAWLINE).
*/
typedef FPS_ItemDrawCallback		= function int (int iClient, int iStyle);

/**
 *	Add new custom function.
 *
 *	@param szFeature			Function name.
 *	@param eType				Menu section to add.
 *	@param OnItemSelect			Callback when click an item.
 *	@param OnItemDisplay		Callback when displaying an item.
 *	@param OnItemDraw			Callback when accessing an item.
 *	@noreturn
*/
native void FPS_AddFeature(const char[]					szFeature,
							FeatureMenus				eType,
							FPS_ItemSelectCallback		OnItemSelect	= INVALID_FUNCTION,
							FPS_ItemDisplayCallback		OnItemDisplay	= INVALID_FUNCTION,
							FPS_ItemDrawCallback		OnItemDraw		= INVALID_FUNCTION);

/**
 *	Delete custom function.
 *
 *	@param szFeature			Function name.
 *	@noreturn
*/
native void FPS_RemoveFeature(const char[] szFeature);

/**
 *	Get custom function state
 *
 *	@param szFeature			Function name.
 *	@return						true - Exist.
 * 								false - Not exist.
*/
native bool FPS_IsExistFeature(const char[] szFeature);

/**
 *	Open statistics section
 *
 *	@param iClient				Player index.
 *	@param eType				Section menu. -1 - Open main menu of statistics (only applies to this native!).
 *	@param iPage				Menu page to open (GetMenuSelectionPosition()).
 *	@noreturn
*/
native void FPS_MoveToMenu(int iClient, FeatureMenus eType, int iPage = 0);

/**
 *	Gets status of whether statistics are working (collects data and calculates points).
 *
 *	@return						true - Working.
 * 								false - Disable in this moment.
*/
native bool FPS_StatsActive();

/**
 *	Get ID`s.
 *
 *	@param eType				Type ID.
 *	@return						ID.
*/
native int FPS_GetID(StatsID eType);

/**
 *	Get current player position.
 *
 *	@param iClient				Player index.
 *	@return						Current position.
*/
native int FPS_GetPosition(int iClient);

/**
 *	Gets count players.
 *
 *	@return						Count all players.
*/
native int FPS_GetPlayersCount();

/**
 *	Get array (not copy!) with ranks for current server.
 *	Array contains, in order, POINTS and TITLE for rank, from larger to smaller.
 *	Example: 1.4000 2.Global 3.3600 4.Supreme ...
 *
 *	@return						Array with ranks.
*/
native ArrayList FPS_GetAllRanks();

/**
 *	Print message in chat with prefix for player (cvar sm_fps_chat_prefix).
 *
 *	@param iClient				Player index.
 *	@param szMessage			Message formatting rules.
 *	@param ...					Formatting parameters.
 *	@noreturn
*/
native void FPS_PrintToChat(int iClient, const char[] szMessage, any ...);

/**
 *	Print message in chat with prefix for all player (cvar sm_fps_chat_prefix).
 *
 *	@param szMessage			Message formatting rules.
 *	@param ...					Formatting parameters.
 *	@noreturn
*/
native void FPS_PrintToChatAll(const char[] szMessage, any ...);

/////////////////////////////////////////////////////////////////////////////////

// Find translation rank
stock char[] FindTranslationRank(int iClient, char[] szRank = NULL_STRING)
{
	static char szRankName[128];
	
	if (!szRank[0])
	{
		FPS_GetRanks(iClient, SZF(szRankName));
	}
	else
	{
		strcopy(SZF(szRankName), szRank);
	}
	
	if (TranslationPhraseExists(szRankName))
	{
		Format(SZF(szRankName), "%T", szRankName, iClient);
	}

	return szRankName;
}
