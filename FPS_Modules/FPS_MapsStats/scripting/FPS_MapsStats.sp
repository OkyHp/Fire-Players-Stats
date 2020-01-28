#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <FirePlayersStats>

int			g_iPlayerData[MAXPLAYERS+1][13],
			g_iMapSessionTime[MAXPLAYERS+1];
char		g_sCurrentMap[256];
Database	g_hDatabase;

enum PlayerData
{
	ACCOUNT_ID = 0,
	PLAYED_ON_MAP,
	MAP_KILLS,
	MAP_DEATHS,
	MAP_ASSISTS,
	MAP_ROUNDS_OVARALL,
	MAP_ROUNDS_T,
	MAP_ROUNDS_CT,
	BOMB_PLANTED,
	BOMB_DEFUSED,
	HOSTAGE_KILLED,
	HOSTAGE_RESCUED,
	MAP_TIME
}

static const char g_sFeature[][] = {"FPS_MapsStats_Menu", "FPS_MapsStats_Top"};

public Plugin myinfo =
{
	name	=	"FPS Maps Stats",
	author	=	"OkyHp",
	version	=	"1.0.0",
	url		=	"https://blackflash.ru/, https://dev-source.ru/, https://hlmod.ru/"
};

public void OnPluginStart()
{
	if(GetEngineVersion() != Engine_CSGO)
	{
		SetFailState("[FPS] Maps Stats: This plugin works only on CS:GO");
	}

	HookEvent("player_death", 		Event_PlayerDeath);
	HookEvent("round_end",			Event_RoundEnd);

	HookEvent("bomb_planted",		Event_OtherAction);
	HookEvent("bomb_defused",		Event_OtherAction);
	HookEvent("hostage_killed",		Event_OtherAction);
	HookEvent("hostage_rescued",	Event_OtherAction);

	LoadTranslations("FPS_MapStats.phrases");
	LoadTranslations("FirePlayersStats.phrases");

	if (FPS_StatsLoad())
	{
		FPS_OnDatabaseConnected(FPS_GetDatabase());
		FPS_OnFPSStatsLoaded();
	}

	AddCommandListener(CommandTopCallback, "sm_top");
}

public void FPS_OnDatabaseLostConnection()
{
	if (g_hDatabase)
	{
		delete g_hDatabase;
	}
}

public void FPS_OnDatabaseConnected(Database hDatabase)
{
	if (hDatabase)
	{
		g_hDatabase = hDatabase;

		static bool bFirstLoad;
		if (!bFirstLoad)
		{
			bFirstLoad = true;
			g_hDatabase.Query(SQL_Callback_CreateTable, "CREATE TABLE IF NOT EXISTS `fps_maps` ( \
					`id`				int				NOT NULL AUTO_INCREMENT, \
					`account_id`		int				NOT NULL, \
					`server_id`			int				NOT NULL, \
					`name_map`			varchar(256)	NOT NULL DEFAULT '', \
					`countplays`		int				NOT NULL DEFAULT 0, \
					`kills`				int				NOT NULL DEFAULT 0, \
					`deaths` 			int				NOT NULL DEFAULT 0, \
					`assists`			int				NOT NULL DEFAULT 0, \
					`rounds_overall` 	int				NOT NULL DEFAULT 0, \
					`rounds_t`			int				NOT NULL DEFAULT 0, \
					`rounds_ct`			int				NOT NULL DEFAULT 0, \
					`bomb_planted`		int				NOT NULL DEFAULT 0, \
					`bomb_defused`		int				NOT NULL DEFAULT 0, \
					`hostage_rescued`	int				NOT NULL DEFAULT 0, \
					`hostage_killed`	int				NOT NULL DEFAULT 0, \
					`playtime`			int				NOT NULL DEFAULT 0, \
					PRIMARY KEY (`id`), \
					UNIQUE(`account_id`, `server_id`, `name_map`) \
				) ENGINE = InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;");
		}

		for (int i = MaxClients+1; --i;)
		{
			if (FPS_ClientLoaded(i))
			{
				FPS_OnClientLoaded(i, 0.0);
			}
		}
	}
}

void SQL_Callback_CreateTable(Database hDatabase, DBResultSet hResult, const char[] szError, any data)
{
	if (!hResult || szError[0])
	{
		SetFailState("SQL_Callback_CreateTable: %s", szError);
	}

	if (g_hDatabase)
	{
		g_hDatabase.Query(SQL_Default_Callback, "SET NAMES 'utf8mb4'", 1);
		g_hDatabase.Query(SQL_Default_Callback, "SET CHARSET 'utf8mb4'", 2);
		g_hDatabase.SetCharset("utf8mb4");
	}
}

void SQL_Default_Callback(Database hDatabase, DBResultSet hResult, const char[] szError, any QueryID)
{
	if (!hResult || szError[0])
	{
		LogError("SQL_Default_Callback #%i: %s", QueryID, szError);
	}
}

public void FPS_OnFPSStatsLoaded()
{
	FPS_AddFeature(g_sFeature[0], FPS_STATS_MENU, OnItemSelectStatsMenu, OnItemDisplayStatsMenu);
	FPS_AddFeature(g_sFeature[1], FPS_TOP_MENU, OnItemSelectTopMenu, OnItemDisplayTopMenu);
}

public void OnPluginEnd()
{
	if (CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "FPS_RemoveFeature") == FeatureStatus_Available)
	{
		FPS_RemoveFeature(g_sFeature[0]);
		FPS_RemoveFeature(g_sFeature[1]);
	}
}

public void FPS_OnClientLoaded(int iClient, float fPoints)
{
	int iAccountID = GetSteamAccountID(iClient, true);
	if (iAccountID)
	{
		g_iPlayerData[iClient][ACCOUNT_ID] = iAccountID;
		g_iMapSessionTime[iClient] = GetTime();

		if (g_hDatabase)
		{
			char szQuery[256];
			g_hDatabase.Format(SZF(szQuery), "SELECT \
					`countplays`, `kills`, `deaths`, `assists`, `rounds_overall`, `rounds_t`, \
					`rounds_ct`, `bomb_planted`, `bomb_defused`, `hostage_rescued`, `hostage_killed`, `playtime` \
				FROM `fps_maps` WHERE `server_id` = '%i' AND `account_id` = '%i' AND `name_map` = '%s' LIMIT 1", 
				FPS_GetID(FPS_SERVER_ID), g_iPlayerData[iClient][ACCOUNT_ID], g_sCurrentMap);
			g_hDatabase.Query(SQL_Callback_LoadPlayerData, szQuery, UID(iClient));
		}
		return;
	}

	LogError("GetSteamAccountID >> %N: AccountID not valid: %i", iClient, iAccountID);
}

public void SQL_Callback_LoadPlayerData(Database hDatabase, DBResultSet hResult, const char[] szError, any iUserID)
{
	if (!hResult || szError[0])
	{
		LogError("SQL_Callback_LoadPlayerData: %s", szError);
		return;
	}

	int iClient = CID(iUserID);
	if (iClient && hResult.FetchRow())
	{
		for (int i = sizeof(g_iPlayerData[]) - 1; i--;)
		{
			g_iPlayerData[iClient][i] = hResult.FetchInt(i);
		}
	}
}

public void OnClientDisconnect(int iClient)
{
	if (iClient && FPS_ClientLoaded(iClient))
	{
		SavePlayerData(iClient);
	}

	g_iMapSessionTime[iClient] = 0;
	for (int i = sizeof(g_iPlayerData[]); i--;)
	{
		g_iPlayerData[iClient][i] = 0;
	}
}

public void OnMapStart()
{
	GetCurrentMapEx(g_sCurrentMap, sizeof(g_sCurrentMap));
}

void SavePlayerData(int iClient, bool bReset = false)
{
	if (g_hDatabase && FPS_ClientLoaded(iClient))
	{
		int iPlayTime = g_iMapSessionTime[iClient] ? ((GetTime() - g_iMapSessionTime[iClient]) + g_iPlayerData[iClient][MAP_TIME]) : 0;

		if (!bReset && GetClientTime(iClient) > 90.0)
		{
			g_iPlayerData[iClient][PLAYED_ON_MAP]++;
		}

		char szQuery[256];
		g_hDatabase.Format(SZF(szQuery), "INSERT INTO `fps_maps` ( \
				`account_id`, `server_id`, `name_map`, `countplays`, `kills`, \
				`deaths`, `assists`, `rounds_overall`, `rounds_t`, `rounds_ct`, \
				`bomb_planted`, `bomb_defused`, `hostage_rescued`, `hostage_killed`, `playtime` \
			) \
			VALUES \
				('%i', '%i', '%s', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i') ON DUPLICATE KEY \
			UPDATE \
				`countplays` = '%i', \
				`kills` = '%i', \
				`deaths` = '%i', \
				`assists` = '%i', \
				`rounds_overall` = '%i', \
				`rounds_t` = '%i', \
				`rounds_ct` = '%i', \
				`bomb_planted` = '%i', \
				`bomb_defused` = '%i', \
				`hostage_rescued` = '%i', \
				`hostage_killed` = '%i', \
				`playtime` = '%i';", 
			g_iPlayerData[iClient][ACCOUNT_ID], FPS_GetID(FPS_SERVER_ID), g_sCurrentMap,

			g_iPlayerData[iClient][PLAYED_ON_MAP], g_iPlayerData[iClient][MAP_KILLS], g_iPlayerData[iClient][MAP_DEATHS], 
			g_iPlayerData[iClient][MAP_ASSISTS], g_iPlayerData[iClient][MAP_ROUNDS_OVARALL], g_iPlayerData[iClient][MAP_ROUNDS_T],
			g_iPlayerData[iClient][MAP_ROUNDS_CT], g_iPlayerData[iClient][BOMB_PLANTED], g_iPlayerData[iClient][BOMB_DEFUSED],
			g_iPlayerData[iClient][HOSTAGE_KILLED], g_iPlayerData[iClient][HOSTAGE_RESCUED], iPlayTime,

			g_iPlayerData[iClient][PLAYED_ON_MAP], g_iPlayerData[iClient][MAP_KILLS], g_iPlayerData[iClient][MAP_DEATHS], 
			g_iPlayerData[iClient][MAP_ASSISTS], g_iPlayerData[iClient][MAP_ROUNDS_OVARALL], g_iPlayerData[iClient][MAP_ROUNDS_T],
			g_iPlayerData[iClient][MAP_ROUNDS_CT], g_iPlayerData[iClient][BOMB_PLANTED], g_iPlayerData[iClient][BOMB_DEFUSED],
			g_iPlayerData[iClient][HOSTAGE_KILLED], g_iPlayerData[iClient][HOSTAGE_RESCUED], iPlayTime);
		g_hDatabase.Query(SQL_Default_Callback, szQuery, 3);
	}
}

void Event_PlayerDeath(Event hEvent, const char[] sEvName, bool bDontBroadcast)
{
	if (FPS_StatsActive())
	{
		int iClient = CID(hEvent.GetInt("assister"));
		if (iClient && FPS_ClientLoaded(iClient))
		{
			g_iPlayerData[iClient][MAP_ASSISTS]++;
		}

		iClient = CID(hEvent.GetInt("userid"));

		int iAttacker = CID(hEvent.GetInt("attacker"));
		if (iAttacker && iAttacker != iClient && FPS_ClientLoaded(iAttacker))
		{
			g_iPlayerData[iAttacker][MAP_KILLS]++;
		}

		if (iClient && FPS_ClientLoaded(iClient))
		{
			g_iPlayerData[iClient][MAP_DEATHS]++;
		}
	}
}

void Event_RoundEnd(Event hEvent, const char[] sEvName, bool bDontBroadcast)
{
	if (FPS_StatsActive())
	{
		int iWinTeam = GetEventInt(hEvent, "winner");
		if (iWinTeam > 1)
		{
			for(int i = MaxClients+1; --i;)
			{
				g_iPlayerData[i][MAP_ROUNDS_OVARALL]++;
				if (FPS_ClientLoaded(i) && GetClientTeam(i) == iWinTeam)
				{
					g_iPlayerData[i][view_as<int>(MAP_ASSISTS) + iWinTeam]++;
				}
			}
		}
	}
}

void Event_OtherAction(Event hEvent, const char[] sEvName, bool bDontBroadcast)
{
	if (FPS_StatsActive())
	{
		int iClient = CID(hEvent.GetInt("userid"));
		if (!iClient || !FPS_ClientLoaded(iClient))
		{
			return;
		}

		switch(sEvName[8])
		{
			case 'n': g_iPlayerData[iClient][BOMB_PLANTED]++;
			case 'u': g_iPlayerData[iClient][BOMB_DEFUSED]++;
			case 'k': g_iPlayerData[iClient][HOSTAGE_KILLED]++;
			case 'r': g_iPlayerData[iClient][HOSTAGE_RESCUED]++;
		}
	}
}

bool OnItemSelectStatsMenu(int iClient)
{
	StatsMapMenu(iClient);
	return false;
}

bool OnItemDisplayStatsMenu(int iClient, char[] szDisplay, int iMaxLength)
{
	FormatEx(szDisplay, iMaxLength, "%T", "MapStatistics_Title", iClient, g_sCurrentMap);
	return true;
}

void StatsMapMenu(int iClient)
{
	Menu hMenu = new Menu(Handler_StatsMapMenu);
	SetGlobalTransTarget(iClient);
	
	char szBuffer[256];
	if (g_sCurrentMap[2] == '_')
	{
		static const char szSubData[][] = {"MapStatistics_De", "MapStatistics_Cs"};

		int iIndex[2] = {-1, ...};
		switch (g_sCurrentMap[0])
		{
			case 'd': iIndex[0]++, iIndex[1] = 8;
			case 'c': iIndex[0]+=2, iIndex[1] = 10;
		}

		if (iIndex[0] != -1)
		{
			FormatEx(SZF(szBuffer), "%t", szSubData[iIndex[0]], g_iPlayerData[iClient][iIndex[1]], g_iPlayerData[iClient][++iIndex[1]]);
		}
	}

	hMenu.SetTitle("[ %t ]\n %t\n ", "MapStatistics_Title", "MapStatistics", g_sCurrentMap,
		g_iPlayerData[iClient][PLAYED_ON_MAP], 
		(g_iPlayerData[iClient][MAP_TIME] ? (float(g_iPlayerData[iClient][MAP_TIME]) / 60.0 / 60.0) : 0.0),
		(100.0 / float(g_iPlayerData[iClient][MAP_ROUNDS_OVARALL])) * float(g_iPlayerData[iClient][MAP_ROUNDS_T] + g_iPlayerData[iClient][MAP_ROUNDS_CT]),
		g_iPlayerData[iClient][MAP_ROUNDS_OVARALL],
		g_iPlayerData[iClient][MAP_ROUNDS_T],
		g_iPlayerData[iClient][MAP_ROUNDS_CT], 
		g_iPlayerData[iClient][MAP_KILLS], 
		g_iPlayerData[iClient][MAP_DEATHS],
		(g_iPlayerData[iClient][MAP_KILLS] && g_iPlayerData[iClient][MAP_DEATHS] ? (float(g_iPlayerData[iClient][MAP_KILLS]) / float(g_iPlayerData[iClient][MAP_DEATHS])) : 0.0),
		szBuffer
	);

	FormatEx(SZF(szBuffer), "%t", "ResetPlayerStatsByMaps");
	hMenu.AddItem(NULL_STRING, szBuffer);

	hMenu.ExitBackButton = true;
	hMenu.ExitButton = true;
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

int Handler_StatsMapMenu(Menu hMenu, MenuAction action, int iClient, int iItem)
{
	switch(action)
	{
		case MenuAction_End: delete hMenu;
		case MenuAction_Cancel:
		{
			if(iItem == MenuCancel_ExitBack)
			{
				FPS_MoveToMenu(iClient, FPS_STATS_MENU);
			}
		}
		case MenuAction_Select: ResetPlayerStatsByMaps(iClient);
	}
}

void ResetPlayerStatsByMaps(int iClient)
{
	char szBuffer[512];
	Panel hPanel = new Panel();
	SetGlobalTransTarget(iClient);

	FormatEx(SZF(szBuffer), "[ %t ]\n ", "ResetPlayerStatsByMaps");
	hPanel.SetTitle(szBuffer);

	FormatEx(SZF(szBuffer), "%t\n ", "AreYouSureResetStats");
	hPanel.DrawText(szBuffer);

	FormatEx(SZF(szBuffer), "%t\n ", "YesImSure");
	hPanel.CurrentKey = GetRandomInt(1, 6);
	hPanel.DrawItem(szBuffer);

	FormatEx(SZF(szBuffer), "%t", "Back");
	hPanel.CurrentKey = 7;
	hPanel.DrawItem(szBuffer);

	FormatEx(SZF(szBuffer), "%t", "Exit");
	hPanel.CurrentKey = 9;
	hPanel.DrawItem(szBuffer);

	hPanel.Send(iClient, Handler_PanelResetStatsByMaps, MENU_TIME_FOREVER);
	delete hPanel;
}

int Handler_PanelResetStatsByMaps(Menu hPanel, MenuAction action, int iClient, int iOption)
{
	if(FPS_ClientLoaded(iClient) && action == MenuAction_Select)
	{
		if (iOption != 7 && iOption != 9 && g_hDatabase)
		{
			for (int i = sizeof(g_iPlayerData[]) - 1; i--;)
			{
				g_iPlayerData[iClient][i] = 0;
			}
			SavePlayerData(iClient, true);
			FPS_PrintToChat(iClient, "%t", "YourStatsReset");
			PlayItemSelectSound(iClient, false);
		}
		else
		{
			if (iOption == 7)
			{
				StatsMapMenu(iClient);
			}
			PlayItemSelectSound(iClient, true);
		}
	}
}

bool OnItemSelectTopMenu(int iClient)
{
	TopMapmenu(iClient);
	return false;
}

bool OnItemDisplayTopMenu(int iClient, char[] szDisplay, int iMaxLength)
{
	FormatEx(szDisplay, iMaxLength, "%T", "MapTop_Title", iClient);
	return true;
}

void TopMapmenu(int iClient)
{
	Menu hMenu = new Menu(Handler_TopMapmenu);
	SetGlobalTransTarget(iClient);
	hMenu.SetTitle("[ %t ]\n ", "MapTop_Title");
	
	char szBuffer[128];
	FormatEx(SZF(szBuffer), "%t", "MapTop_PlayerKills");
	hMenu.AddItem(NULL_STRING, szBuffer);
	FormatEx(SZF(szBuffer), "%t", "MapTop_All", g_sCurrentMap);
	hMenu.AddItem(NULL_STRING, szBuffer);

	hMenu.ExitBackButton = true;
	hMenu.ExitButton = true;
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

int Handler_TopMapmenu(Menu hMenu, MenuAction action, int iClient, int iItem)
{
	switch(action)
	{
		case MenuAction_End: delete hMenu;
		case MenuAction_Cancel:
		{
			if(iItem == MenuCancel_ExitBack)
			{
				FPS_MoveToMenu(iClient, FPS_TOP_MENU);
			}
		}
		case MenuAction_Select:
		{
			if (g_hDatabase && FPS_ClientLoaded(iClient))
			{
				char szQuery[256];
				switch(iItem)
				{
					case 0: g_hDatabase.Format(SZF(szQuery), "SELECT `name_map`, `kills` FROM `fps_maps` \
						WHERE `kills` != 0 AND `server_id` = '%i' AND `account_id` = '%i' ORDER BY `kills` DESC LIMIT 10", 
						FPS_GetID(FPS_SERVER_ID), g_iPlayerData[iClient][ACCOUNT_ID]);
					case 1: g_hDatabase.Format(SZF(szQuery), "SELECT `s`.`nickname`, `m`.`kills` \
						FROM \
							`fps_maps` AS `m` \
							INNER JOIN `fps_players` AS `s` ON `s`.`account_id` = `m`.`account_id` \
						WHERE `m`.`kills` != 0 AND `server_id` = %i AND `name_map` = '%s' ORDER BY `m`.`kills` DESC LIMIT 10", 
						FPS_GetID(FPS_SERVER_ID), g_sCurrentMap);
				}
				g_hDatabase.Query(SQL_Callback_TopData, szQuery, UID(iClient) << 4 | iItem);
			}
		}
	}
}

public void SQL_Callback_TopData(Database hDatabase, DBResultSet hResult, const char[] szError, any iData)
{
	if (!hResult || szError[0])
	{
		LogError("SQL_Callback_LoadPlayerData: %s", szError);
		return;
	}

	int	iClient = CID(iData >> 4);
	if (!iClient)
	{
		return;
	}

	Panel hPanel = new Panel();
	SetGlobalTransTarget(iClient);

	char	szBuffer[512],
			szSubBuffer[256];
	switch(iData & 0xF)
	{
		case 0: FormatEx(SZF(szBuffer), "[ %t ]\n ", "MapTop_PlayerKills");
		case 1: FormatEx(SZF(szBuffer), "[ %t ]\n ", "MapTop_All", g_sCurrentMap);
	}
	hPanel.SetTitle(szBuffer);

	int i;
	while(hResult.FetchRow())
	{
		hResult.FetchString(0, SZF(szSubBuffer));
		FormatEx(SZF(szBuffer), "%i. %s - %i %t", ++i, szSubBuffer, hResult.FetchInt(1), "Kills");
		hPanel.DrawText(szBuffer);
	}

	if (!i)
	{
		FormatEx(SZF(szBuffer), "%t", "NoData");
		hPanel.DrawText(szBuffer);
	}

	hPanel.DrawText("\n ");
	
	FormatEx(SZF(szBuffer), "%t", "Back");
	hPanel.CurrentKey = 7;
	hPanel.DrawItem(szBuffer);

	FormatEx(SZF(szBuffer), "%t", "Exit");
	hPanel.CurrentKey = 9;
	hPanel.DrawItem(szBuffer);

	hPanel.Send(iClient, Handler_PanelTop, MENU_TIME_FOREVER);
	delete hPanel;
}

public int Handler_PanelTop(Menu hPanel, MenuAction action, int iClient, int iOption)
{
	if(FPS_ClientLoaded(iClient) && action == MenuAction_Select)
	{
		if (iOption == 7)
		{
			TopMapmenu(iClient);
		}
		PlayItemSelectSound(iClient, true);
	}
}

Action CommandTopCallback(int iClient, const char[] szCommand, int iArgs)
{
	char szArg[2];
	GetCmdArg(1, SZF(szArg));
	if (szArg[0])
	{
		if (!strcmp(szArg, "maps", false))
		{
			TopMapmenu(iClient);
		}
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

void PlayItemSelectSound(int iClient, bool bClose)
{
	ClientCommand(iClient, bClose ? "playgamesound *buttons/combine_button7.wav" : "playgamesound *buttons/button14.wav");
}

void GetCurrentMapEx(char[] szMapBuffer, int iSize)
{
	char szBuffer[256];
	GetCurrentMap(szBuffer, sizeof szBuffer);
	int iIndex = -1, iLen = strlen(szBuffer);
	
	for(int i = 0; i < iLen; i++)
	{
		if(FindCharInString(szBuffer[i], '/') != -1 || FindCharInString(szBuffer[i], '\\') != -1)
		{
			if(i != iLen - 1)
			{
				iIndex = i;
			}
			continue;
		}
		break;
	}

	strcopy(szMapBuffer, iSize, szBuffer[iIndex+1]);
}
