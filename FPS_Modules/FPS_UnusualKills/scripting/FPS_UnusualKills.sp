/**
 *	v1.0.3 -	Use data from event player_death.
 *				Added menu for reset stats.
 *				Added reset stats, when resetting general stats for player or all players.
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <FirePlayersStats>

#if SOURCEMOD_V_MINOR < 10
	#error This plugin can only compile on SourceMod 1.10!
#endif

#if FPS_INC_VER != 154
	#error "FirePlayersStats.inc is outdated and not suitable for compilation! Version required: 154"
#endif

#define MAX_UKTYPES 9
#define UnusualKill_None 0
#define UnusualKill_OpenFrag (1 << 0)
#define UnusualKill_Penetrated (1 << 1)
#define UnusualKill_NoScope (1 << 2)
#define UnusualKill_Run (1 << 3)
#define UnusualKill_Jump (1 << 4)
#define UnusualKill_Flash (1 << 5)
#define UnusualKill_Smoke (1 << 6)
#define UnusualKill_Whirl (1 << 7)
#define UnusualKill_LastClip (1 << 8)

#define SQL_CreateTable "CREATE TABLE IF NOT EXISTS `fps_unusualkills` (\
	`id`			int NOT NULL AUTO_INCREMENT, \
	`account_id`	int NOT NULL, \
	`server_id`		int	NOT NULL, \
	`op`			int NOT NULL DEFAULT 0, \
	`penetrated`	int NOT NULL DEFAULT 0, \
	`no_scope`		int NOT NULL DEFAULT 0, \
	`run`			int NOT NULL DEFAULT 0, \
	`jump`			int NOT NULL DEFAULT 0, \
	`flash`			int NOT NULL DEFAULT 0, \
	`smoke`			int NOT NULL DEFAULT 0, \
	`whirl`			int NOT NULL DEFAULT 0, \
	`last_clip`		int NOT NULL DEFAULT 0, \
	PRIMARY KEY (`id`), \
	UNIQUE(`account_id`, `server_id`) \
) CHARSET = utf8mb4 COLLATE utf8mb4_general_ci;"
#define SQL_CreatePlayer "INSERT INTO `fps_unusualkills` (`account_id`, `server_id`) VALUES ('%i', '%i');"
#define SQL_LoadPlayer "SELECT \
	`op`, \
	`penetrated`, \
	`no_scope`, \
	`run`, \
	`jump`, \
	`flash`, \
	`smoke`, \
	`whirl`, \
	`last_clip` \
FROM `fps_unusualkills` WHERE `account_id` = '%i' AND `server_id` = '%i';"
#define SQL_SavePlayer "UPDATE `fps_unusualkills` SET %s WHERE `account_id` = '%i' AND `server_id` = '%i';"
#define SQL_PrintTop "SELECT `p`.`nickname`, `u`.`%s` \
FROM \
	`fps_unusualkills` AS `u` \
	INNER JOIN `fps_players` AS `p` ON `p`.`account_id` = `u`.`account_id` \
WHERE `u`.`server_id` = %i ORDER BY `u`.`%s` DESC LIMIT 10;"

bool  	g_bOPKill,
		g_bShowItem[MAX_UKTYPES],
		g_bResetModuleStats;

int 	g_iPlayerAccountID[MAXPLAYERS+1],
		g_iExp[MAX_UKTYPES],
		g_iExpMode,
		g_iWhirlInterval = 2,
		g_iUK[MAXPLAYERS+1][MAX_UKTYPES],
		m_iClip1,
		m_hActiveWeapon,
		m_vecVelocity,
		g_iResetStatsTime;

float	g_flRotation[MAXPLAYERS+1],
		g_flMinLenVelocity = 100.0,
		g_flWhirl = 200.0;

static const char	g_sNameUK[][] = {"op", "penetrated", "no_scope", "run", "jump", "flash", "smoke", "whirl", "last_clip"},
					g_sFeature[][] = {"FPS_UnusualKills_Menu", "FPS_UnusualKills_Top"};

Database	g_hDatabase;

ArrayList	g_hProhibitedWeapons;

public Plugin myinfo = 
{
	name = "[FPS] Unusual Kills", 
	author = "Wend4r, OkyHp", 
	version = "1.0.3 (Original: SR1)",
	url = "Discord: Wend4r#0001, OkyHek#2441 | VK: vk.com/wend4r"
}

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] szError, int iErr_max)
{
	if(GetEngineVersion() != Engine_CSGO)
	{
		strcopy(szError, iErr_max, "This plugin works only on CS:GO!");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	m_iClip1			= FindSendPropInfo("CBaseCombatWeapon",	"m_iClip1");
	m_hActiveWeapon		= FindSendPropInfo("CBasePlayer",		"m_hActiveWeapon");
	m_vecVelocity		= FindSendPropInfo("CBasePlayer",		"m_vecVelocity[0]");

	LoadSettings();

	HookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);

	if (FPS_StatsLoad())
	{
		FPS_OnDatabaseConnected(FPS_GetDatabase());
		FPS_OnFPSStatsLoaded();
	}

	LoadTranslations("FPS_UnusualKills.phrases");
	LoadTranslations("FirePlayersStats.phrases");

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

		static bool bLoaded;
		if (!bLoaded)
		{
			bLoaded = true;
			g_hDatabase.Query(SQL_Callback_CreateTable, SQL_CreateTable);
		}
	}
}

public void SQL_Callback_CreateTable(Database hDatabase, DBResultSet hResult, const char[] szError, any data)
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

public void SQL_Default_Callback(Database hDatabase, DBResultSet hResult, const char[] szError, any QueryID)
{
	if (hResult == null || szError[0])
	{
		LogError("SQL_Default_Callback #%i: %s", QueryID, szError);
	}
}

public void FPS_OnFPSStatsLoaded()
{
	FPS_AddFeature(g_sFeature[0], FPS_STATS_MENU, OnItemSelectMenu, OnItemDisplayMenu);
	FPS_AddFeature(g_sFeature[1], FPS_TOP_MENU, OnItemSelectTop, OnItemDisplayTop);

	ConVar Convar;
	(Convar = FindConVar("sm_fps_reset_stats_time")).AddChangeHook(ChangeCvar_ResetStatsTime);
	ChangeCvar_ResetStatsTime(Convar, NULL_STRING, NULL_STRING);
	(Convar = FindConVar("sm_fps_reset_modules_stats")).AddChangeHook(ChangeCvar_ResetModuleStats);
	ChangeCvar_ResetModuleStats(Convar, NULL_STRING, NULL_STRING);

	for (int i = 1; i <= MaxClients; ++i)
	{
		if (FPS_ClientLoaded(i))
		{
			FPS_OnClientLoaded(i, 0.0);
		}
	}
}

void ChangeCvar_ResetStatsTime(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	g_iResetStatsTime = Convar.IntValue;
}

void ChangeCvar_ResetModuleStats(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	g_bResetModuleStats = Convar.BoolValue;
}

public void OnPluginEnd()
{
	if (CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "FPS_RemoveFeature") == FeatureStatus_Available)
	{
		FPS_RemoveFeature(g_sFeature[0]);
		FPS_RemoveFeature(g_sFeature[1]);
	}
}

public bool OnItemSelectMenu(int iClient)
{
	UnusualKillMenu(iClient);
	return false;
}

public bool OnItemDisplayMenu(int iClient, char[] szDisplay, int iMaxLength)
{
	FormatEx(szDisplay, iMaxLength, "%T", "UnusualKillMenu", iClient);
	return true;
}

public bool OnItemSelectTop(int iClient)
{
	UnusualKillTop(iClient);
	return false;
}

public bool OnItemDisplayTop(int iClient, char[] szDisplay, int iMaxLength)
{
	FormatEx(szDisplay, iMaxLength, "%T", "UnusualKillsTop", iClient);
	return true;
}

public void FPS_OnClientLoaded(int iClient, float fPoints)
{
	int iAccountID = GetSteamAccountID(iClient, true);
	if (iAccountID)
	{
		g_iPlayerAccountID[iClient] = iAccountID;

		static char sQuery[256];
		FormatEx(sQuery, sizeof(sQuery), SQL_LoadPlayer, g_iPlayerAccountID[iClient], FPS_GetID(FPS_SERVER_ID));
		g_hDatabase.Query(SQL_Callback_LoadPlayer, sQuery, GetClientUserId(iClient));

		return;
	}

	LogError("GetSteamAccountID >> %N: AccountID not valid: %i", iClient, iAccountID);
}

public void SQL_Callback_LoadPlayer(Database db, DBResultSet dbRs, const char[] sError, int iUserID)
{
	if (!dbRs || sError[0])
	{
		LogError("SQL_Callback_LoadPlayer: error when sending the request (%s)", sError);
		return;
	}

	int iClient = GetClientOfUserId(iUserID);
	if(iClient)
	{
		bool bLoadData = true;

		if(!(dbRs.HasResults && dbRs.FetchRow()))
		{
			if (g_hDatabase)
			{
				static char sQuery[256];
				FormatEx(sQuery, sizeof(sQuery), SQL_CreatePlayer, g_iPlayerAccountID[iClient], FPS_GetID(FPS_SERVER_ID));
				g_hDatabase.Query(SQL_Default_Callback, sQuery, 4);
			}

			bLoadData = false;
		}

		for(int i = 0; i != MAX_UKTYPES; i++)
		{
			g_iUK[iClient][i] = bLoadData ? dbRs.FetchInt(i) : 0;
		}
	}
}

void LoadSettings()
{
	static int  iUKSymbolTypes[] = {127, 127, 127, 127, 127, 5, 127, 127, 127, 4, 127, 8, 127, 2, 0, 1, 127, 3, 6, 127, 127, 127, 7};
	static char sPath[PLATFORM_MAX_PATH], sBuffer[512];

	KeyValues hKv = new KeyValues("FPS_UnusualKills");

	if(sPath[0])
	{
		g_hProhibitedWeapons.Clear();
	}
	else
	{
		g_hProhibitedWeapons = new ArrayList(64);

		BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/UnusualKills.ini");
	}

	if(!hKv.ImportFromFile(sPath))
	{
		SetFailState("[FPS] Unusual Kills: LoadSettings: %s - not found!", sPath);
	}
	hKv.GotoFirstSubKey();

	hKv.Rewind();
	hKv.JumpToKey("Settings");	/**/

	g_iExpMode = hKv.GetNum("Exp_Mode", 2);

	hKv.GetString("ProhibitedWeapons", sBuffer, sizeof(sBuffer), "hegrenade,molotov,incgrenade");
	ExplodeInArrayList(sBuffer, g_hProhibitedWeapons);

	hKv.JumpToKey("TypeKills"); /**/

	hKv.GotoFirstSubKey();
	do
	{
		hKv.GetSectionName(sBuffer, 32);

		int iUKType = iUKSymbolTypes[(sBuffer[0] | 32) - 97];

		switch(iUKType)
		{
			case 127:
			{
				LogError("%s: \"FPS_UnusualKills\" -> \"Settings\" -> \"TypeKills\" -> \"%s\" - invalid selection", sPath, sBuffer);
			}
			case 3:
			{
				g_flMinLenVelocity = hKv.GetFloat("minspeed", 100.0);
			}
			case 7:
			{
				g_flWhirl = hKv.GetFloat("whirl", 200.0);
				g_iWhirlInterval = hKv.GetNum("interval", 2);
			}
		}

		g_iExp[iUKType] = g_iExpMode ? hKv.GetNum("exp") : 0;
		g_bShowItem[iUKType] = hKv.GetNum("menu", 1) != 0;
	}
	while(hKv.GotoNextKey());

	delete hKv;
}

void ExplodeInArrayList(const char[] sText, ArrayList hArray)
{
	int iLastSize = 0;

	char sBuf[64];
	for(int i = 0, iLen = strlen(sText) + 1; i != iLen;)
	{
		if(iLen == ++i || sText[i - 1] == ',')
		{
			strcopy(sBuf, i - iLastSize, sText[iLastSize]);
			hArray.PushString(sBuf);

			iLastSize = i;
		}
	}

	if(!iLastSize)
	{
		hArray.PushString(sText);
	}
}

void OnRoundStart(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	g_bOPKill = false;
}

public Action FPS_OnPointsChangePre(int iAttacker, int iVictim, Event hEvent, float& fAddPointsAttacker, float& fAddPointsVictim)
{
	if (FPS_StatsActive())
	{
		static char sWeapon[32];
		hEvent.GetString("weapon", sWeapon, sizeof(sWeapon));

		if(g_hProhibitedWeapons.FindString(sWeapon) == -1 && sWeapon[0] != 'k' && sWeapon[2] != 'y')
		{
			int iActiveWeapon = GetEntDataEnt2(iAttacker, m_hActiveWeapon),
				iUKFlags = UnusualKill_None;

			static float vecVelocity[3];

			if(!g_bOPKill)
			{
				iUKFlags |= UnusualKill_OpenFrag;
				g_bOPKill = true;
			}

			if(hEvent.GetBool("penetrated"))
			{
				iUKFlags |= UnusualKill_Penetrated;
			}

			if(hEvent.GetBool("noscope"))
			{
				iUKFlags |= UnusualKill_NoScope;
			}

			GetEntDataVector(iAttacker, m_vecVelocity, vecVelocity);

			if(vecVelocity[2])
			{
				iUKFlags |= UnusualKill_Jump;
				vecVelocity[2] = 0.0;
			}

			if(GetVectorDistance(NULL_VECTOR, vecVelocity) > g_flMinLenVelocity)
			{
				iUKFlags |= UnusualKill_Run;
			}

			if(hEvent.GetBool("attackerblind"))
			{
				iUKFlags |= UnusualKill_Flash;
			}

			if(hEvent.GetBool("thrusmoke"))
			{
				iUKFlags |= UnusualKill_Smoke;
			}

			if((g_flRotation[iAttacker] < 0.0 ? -g_flRotation[iAttacker] : g_flRotation[iAttacker]) > g_flWhirl)
			{
				iUKFlags |= UnusualKill_Whirl;
			}

			if(iActiveWeapon != -1 && GetEntData(iActiveWeapon, m_iClip1) == 1)
			{
				iUKFlags |= UnusualKill_LastClip;
			}

			if(iUKFlags)
			{
				char sColumns[MAX_UKTYPES * 18],
					 sQuery[MAX_UKTYPES * 18 + 64];

				for(int iType = 0; iType != MAX_UKTYPES; iType++)
				{
					if(iUKFlags & (1 << iType))
					{
						FormatEx(sColumns[strlen(sColumns)], sizeof(sColumns), "`%s` = %d, ", g_sNameUK[iType], ++g_iUK[iAttacker][iType]);

						if (g_iExpMode && g_iExp[iType] > 0)
						{
							if(g_iExpMode == 1)
							{
								FPS_PrintToChat(iAttacker, "%t", "AdditionalPointsPositive", float(g_iExp[iType]), g_sNameUK[iType]);
							}

							fAddPointsAttacker += float(g_iExp[iType]);
						}
					}
				}

				sColumns[strlen(sColumns)-2] = '\0';

				FormatEx(sQuery, sizeof(sQuery), SQL_SavePlayer, sColumns, g_iPlayerAccountID[iAttacker], FPS_GetID(FPS_SERVER_ID));
				g_hDatabase.Query(SQL_Default_Callback, sQuery, 3);

				return g_iExpMode ? Plugin_Changed : Plugin_Continue;
			}
		}
	}

	return Plugin_Continue;
}

public void OnPlayerRunCmdPost(int iClient, int iButtons, int iImpulse, const float flVel[3], const float flAngles[3], int iWeapon, int iSubType, int iCmdNum, int iTickCount, int iSeed, const int iMouse[2])
{
	static int iInterval[MAXPLAYERS+1];

	if(IsPlayerAlive(iClient) && (g_flRotation[iClient] += iMouse[0] / 50.0) && iInterval[iClient] - GetTime() < 1)
	{
		g_flRotation[iClient] = 0.0;
		iInterval[iClient] = GetTime() + g_iWhirlInterval;
	}
}

void UnusualKillMenu(int iClient)
{
	Panel hPanel = new Panel();
	SetGlobalTransTarget(iClient);

	int iKills = FPS_GetStatsData(iClient, KILLS);

	char sBuffer[512],
		 sTrans[48];

	FormatEx(sBuffer, sizeof(sBuffer), "[ %t ]\n ", "UnusualKillMenu");
	hPanel.SetTitle(sBuffer);

	sBuffer[0] = 0;
	if(!iKills)
	{
		iKills = 1;
	}

	for(int i = 0; i != MAX_UKTYPES; i++)
	{
		if(g_bShowItem[i])
		{
			FormatEx(sTrans, sizeof(sTrans), "Menu_%s", g_sNameUK[i]);
			Format(sBuffer, sizeof(sBuffer), "%s%t\n", sBuffer, sTrans, g_iUK[iClient][i], RoundToCeil(100.0 / iKills * g_iUK[iClient][i]));
		}
	}

	Format(sBuffer, sizeof(sBuffer), "%s\n ", sBuffer);
	hPanel.DrawText(sBuffer);

	hPanel.CurrentKey = 1;
	if (g_bResetModuleStats && g_iResetStatsTime)
	{
		int iPlayedTime = FPS_GetPlayedTime(iClient);
		if (iPlayedTime < g_iResetStatsTime)
		{
			float fResult = float(g_iResetStatsTime - iPlayedTime);
			FormatEx(SZF(sBuffer), "%t\n ", "ResetPlayerStatsLock", fResult > 0 ? (fResult / 60 / 60) : 0.0);
			hPanel.DrawText(sBuffer);
		}
		else
		{
			FormatEx(SZF(sBuffer), "%t\n ", "ResetPlayerStatsByUnusualKills");
			hPanel.DrawItem(sBuffer);
		}
	}

	FormatEx(sBuffer, sizeof(sBuffer), "%t", "Back");
	hPanel.CurrentKey = 7;
	hPanel.DrawItem(sBuffer);

	FormatEx(sBuffer, sizeof(sBuffer), "%t", "Exit");
	hPanel.CurrentKey = 9;
	hPanel.DrawItem(sBuffer);

	hPanel.Send(iClient, Handler_Panel, MENU_TIME_FOREVER);
	delete hPanel;
}

public int Handler_Panel(Menu hPanel, MenuAction action, int iClient, int iOption)
{
	if(g_iPlayerAccountID[iClient] && action == MenuAction_Select)
	{
		if (iOption == 1)
		{
			ResetPlayerStatsByUnusualKills(iClient);
			PlayItemSelectSound(iClient, false);
		}
		else
		{
			if (iOption == 7)
			{
				FPS_MoveToMenu(iClient, FPS_STATS_MENU);
			}
			PlayItemSelectSound(iClient, true);
		}
	}
}

void ResetPlayerStatsByUnusualKills(int iClient)
{
	char szBuffer[256];
	Panel hPanel = new Panel();
	SetGlobalTransTarget(iClient);

	FormatEx(SZF(szBuffer), "[ %t ]\n ", "ResetPlayerStatsByUnusualKills");
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
	if(g_iPlayerAccountID[iClient] && action == MenuAction_Select)
	{
		if (iOption != 7 && iOption != 9 && g_hDatabase)
		{
			ResetPlayerStats(iClient);
			FPS_PrintToChat(iClient, "%t", "YourStatsReset");
			PlayItemSelectSound(iClient, false);
		}
		else
		{
			if (iOption == 7)
			{
				UnusualKillMenu(iClient);
			}
			PlayItemSelectSound(iClient, true);
		}
	}
}

public void FPS_OnResetGeneralStats(int iClient)
{
	ResetPlayerStats(iClient);
}

void ResetPlayerStats(int iClient)
{
	if (g_hDatabase)
	{
		char sColumns[MAX_UKTYPES * 18],
			 sQuery[MAX_UKTYPES * 18 + 64];
		for (int i = MAX_UKTYPES; i--;)
		{
			g_iUK[iClient][i] = 0;
			FormatEx(sColumns[strlen(sColumns)], sizeof(sColumns), "`%s` = 0, ", g_sNameUK[i]);
		}
		sColumns[strlen(sColumns)-2] = '\0';
		FormatEx(sQuery, sizeof(sQuery), SQL_SavePlayer, sColumns, g_iPlayerAccountID[iClient], FPS_GetID(FPS_SERVER_ID));
		g_hDatabase.Query(SQL_Default_Callback, sQuery, 5);
	}
}

public void FPS_OnFPSResetAllStats()
{
	if (g_hDatabase)
	{
		for (int i = MaxClients + 1; --i;)
		{
			if (FPS_ClientLoaded(i))
			{
				for (int u = MAX_UKTYPES; u--;)
				{
					g_iUK[i][u] = 0;
				}
			}
		}

		char sQuery[128];
		FormatEx(sQuery, sizeof(sQuery), "DELETE FROM `fps_unusualkills` WHERE `server_id` = %i", FPS_GetID(FPS_SERVER_ID));
		g_hDatabase.Query(SQL_Default_Callback, sQuery, 6);
	}
}

void UnusualKillTop(int iClient)
{
	Menu hMenu = new Menu(Handler_ShowTopsMenu);
	SetGlobalTransTarget(iClient);
	hMenu.SetTitle("[ %t ]\n ", "UnusualKillsTop");

	static char sText[96],
		 		sTrans[32];

	for(int i = 0; i != MAX_UKTYPES; i++)
	{
		if(g_bShowItem[i])
		{
			FormatEx(sTrans, sizeof(sTrans), "Top_%s", g_sNameUK[i]);
			FormatEx(sText, sizeof(sText), "%t", sTrans);

			sTrans[0] = i;
			sTrans[1] = '\0';

			hMenu.AddItem(sTrans, sText);
		}
	}

	hMenu.ExitBackButton = true;
	hMenu.ExitButton = true;
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int Handler_ShowTopsMenu(Menu hMenu, MenuAction action, int iClient, int iItem)
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
			static char sInfo[2],
						sQuery[512];
			hMenu.GetItem(iItem, sInfo, sizeof(sInfo));

			FormatEx(sQuery, sizeof(sQuery), SQL_PrintTop, g_sNameUK[sInfo[0]], FPS_GetID(FPS_SERVER_ID), g_sNameUK[sInfo[0]]);
			g_hDatabase.Query(SQL_Callback_TopData, sQuery, GetClientUserId(iClient) << 4 | sInfo[0] + 1);
		}
	}
}

public void SQL_Callback_TopData(Database hDatabase, DBResultSet hResult, const char[] sError, int iIndex)
{
	if (!hResult || sError[0])
	{
		LogError("SQL_Callback_TopData: error when sending the request (%s)", sError);
		return;
	}

	int iClient = GetClientOfUserId(iIndex >> 4);
	if(iClient && (iIndex &= 0xF))
	{
		Panel hPanel = new Panel();
		SetGlobalTransTarget(iClient);

		char sText[768],
			 sName[32],
			 sTrans[48];

		FormatEx(sTrans, sizeof(sTrans), "Top_%s", g_sNameUK[iIndex - 1]);
		FormatEx(sText, sizeof(sText), "[ %t ]\n ", sTrans);
		hPanel.SetTitle(sText);

		sText[0] = 0;
		if(hResult.HasResults)
		{
			for(int j = 0; hResult.FetchRow();)
			{
				hResult.FetchString(0, sName, sizeof(sName));
				FormatEx(sText, sizeof(sText), "%s\n%t\n", sText, "Top_Open", ++j, hResult.FetchInt(1), sName);
			}
		}
		strcopy(sText[strlen(sText)], 4, "\n ");
		hPanel.DrawText(sText);
		
		FormatEx(sText, sizeof(sText), "%t", "Back");
		hPanel.CurrentKey = 7;
		hPanel.DrawItem(sText);

		FormatEx(sText, sizeof(sText), "%t", "Exit");
		hPanel.CurrentKey = 9;
		hPanel.DrawItem(sText);

		hPanel.Send(iClient, Handler_PanelTop, MENU_TIME_FOREVER);
		delete hPanel;
	}
}

public int Handler_PanelTop(Menu hPanel, MenuAction action, int iClient, int iOption)
{
	if(action == MenuAction_Select)
	{
		if (iOption == 7)
		{
			UnusualKillTop(iClient);
		}
		PlayItemSelectSound(iClient, true);
	}
}

Action CommandTopCallback(int iClient, const char[] szCommand, int iArgs)
{
	if (iArgs)
	{
		char szArg[4];
		GetCmdArg(1, SZF(szArg));
		if (!strcmp(szArg, "uk", false))
		{
			UnusualKillTop(iClient);
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

void PlayItemSelectSound(int iClient, bool bClose)
{
	ClientCommand(iClient, bClose ? "playgamesound *buttons/combine_button7.wav" : "playgamesound *buttons/button14.wav");
}
