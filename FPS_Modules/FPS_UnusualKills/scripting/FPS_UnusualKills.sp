#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <FirePlayersStats>

#if SOURCEMOD_V_MINOR < 10
	#error This plugin can only compile on SourceMod 1.10!
#endif

#if FPS_INC_VER < 13
	#error "FirePlayersStats.inc is outdated and not suitable for compilation!"
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

#define SQL_CreateTable "\
CREATE TABLE IF NOT EXISTS `fps_unusualkills` \
(\
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
#define SQL_PrintTop \
"SELECT `p`.`nickname`, `u`.`%s` \
FROM \
	`fps_unusualkills` AS `u` \
	INNER JOIN `fps_players` AS `p` ON `p`.`account_id` = `u`.`account_id` \
WHERE `u`.`server_id` = %i ORDER BY `u`.`%s` DESC LIMIT 10;"

#define RadiusSmoke 100.0

enum struct UK_Settings
{
	ArrayList ChatCommands;
	ArrayList ProhibitedWeapons;
	ArrayList NoScopeWeapons;
}

bool  	  g_bOPKill,
		  g_bShowItem[MAX_UKTYPES];

int 	  g_iPlayerAccountID[MAXPLAYERS+1],
		  g_iExp[MAX_UKTYPES],
		  g_iExpMode,
		  g_iMinSmokes,
		  g_iWhirlInterval = 2,
		  g_iUK[MAXPLAYERS+1][MAX_UKTYPES],
		  m_bIsScoped,
		  m_iClip1,
		  m_hActiveWeapon,
		  m_flFlashDuration,
		  m_vecOrigin,
		  m_vecVelocity;

float	  g_flRotation[MAXPLAYERS+1],
		  g_flMinFlash = 5.0,
		  g_flMinLenVelocity = 100.0,
		  g_flWhirl = 200.0;

static const char	g_sNameUK[][] = {"op", "penetrated", "no_scope", "run", "jump", "flash", "smoke", "whirl", "last_clip"},
					g_sFeature[][] = {"FPS_UnusualKills_Menu", "FPS_UnusualKills_Top"};

Database	g_hDatabase;

UK_Settings	g_hSettings;

ArrayList	g_hSmokeEnt;

public Plugin myinfo = 
{
	name = "FPS Unusual Kills", 
	author = "Wend4r, OkyHp", 
	version = "1.0.0", 
	url = "Discord: Wend4r#0001 | VK: vk.com/wend4r"
}

public void OnPluginStart()
{
	if(GetEngineVersion() != Engine_CSGO)
	{
		SetFailState("[FPS] Unusual Kills: This plugin works only on CS:GO");
	}

	m_bIsScoped			= FindSendPropInfo("CCSPlayer",			"m_bIsScoped");
	m_iClip1			= FindSendPropInfo("CBaseCombatWeapon",	"m_iClip1");
	m_hActiveWeapon		= FindSendPropInfo("CBasePlayer",		"m_hActiveWeapon");
	m_flFlashDuration	= FindSendPropInfo("CCSPlayer",			"m_flFlashDuration");
	m_vecOrigin			= FindSendPropInfo("CBaseEntity",		"m_vecOrigin");
	m_vecVelocity		= FindSendPropInfo("CBasePlayer",		"m_vecVelocity[0]");

	g_hSmokeEnt = new ArrayList();

	LoadSettings();

	HookEvent("round_start",			view_as<EventHook>(OnRoundStart));
	HookEvent("smokegrenade_detonate",	view_as<EventHook>(OnSmokeEvent));
	HookEventEx("smokegrenade_expired",	view_as<EventHook>(OnSmokeEvent));

	if (FPS_StatsLoad())
	{
		FPS_OnDatabaseConnected(FPS_GetDatabase());
		FPS_OnFPSStatsLoaded();
	}

	LoadTranslations("FPS_UnusualKills.phrases");
	LoadTranslations("FirePlayersStats.phrases");
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
			SQL_LockDatabase(g_hDatabase);
			g_hDatabase.Query(SQL_Callback_CreateTable, SQL_CreateTable);
			SQL_UnlockDatabase(g_hDatabase);
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

	for (int i = 1; i <= MaxClients; ++i)
	{
		if (FPS_ClientLoaded(i))
		{
			FPS_OnClientLoaded(i, 0.0);
		}
	}
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
		g_hSettings.ChatCommands.Clear();
		g_hSettings.ProhibitedWeapons.Clear();
		g_hSettings.NoScopeWeapons.Clear();
	}
	else
	{
		g_hSettings.ChatCommands = new ArrayList(64);
		g_hSettings.ProhibitedWeapons = new ArrayList(64);
		g_hSettings.NoScopeWeapons = new ArrayList(64);

		BuildPath(Path_SM, sPath, sizeof(sPath), "configs/FirePlayersStats/unusual_kills.ini");
	}

	if(!hKv.ImportFromFile(sPath))
	{
		SetFailState("[FPS] Unusual Kills: LoadSettings: %s - not found!", sPath);
	}
	hKv.GotoFirstSubKey();

	hKv.Rewind();
	hKv.JumpToKey("Settings");	/**/

	g_iExpMode = hKv.GetNum("Exp_Mode", 1);

	hKv.GetString("ChatCommands", sBuffer, sizeof(sBuffer), "!uk,!ukstats,!unusualkills");
	ExplodeInArrayList(sBuffer, g_hSettings.ChatCommands);

	hKv.GetString("ProhibitedWeapons", sBuffer, sizeof(sBuffer), "hegrenade,molotov,incgrenade");
	ExplodeInArrayList(sBuffer, g_hSettings.ProhibitedWeapons);

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
			case 2:
			{
				hKv.GetString("weapons", sBuffer, sizeof(sBuffer));
				ExplodeInArrayList(sBuffer, g_hSettings.NoScopeWeapons);
			}
			case 3:
			{
				g_flMinLenVelocity = hKv.GetFloat("minspeed", 100.0);
			}
			case 5:
			{
				g_flMinFlash = hKv.GetFloat("degree") * 10.0;
			}
			case 7:
			{
				g_flWhirl = hKv.GetFloat("whirl", 200.0);
				g_iWhirlInterval = hKv.GetNum("interval", 2);
			}
		}

		g_iExp[iUKType] = g_iExpMode ? hKv.GetNum("exp") : 0;
		g_bShowItem[iUKType] = view_as<bool>(hKv.GetNum("menu", 1));
	}
	while(hKv.GotoNextKey());

	delete hKv;
}

void ExplodeInArrayList(const char[] sText, ArrayList hArray)
{
	int iLastSize = 0;

	for(int i = 0, iLen = strlen(sText) + 1; i != iLen;)
	{
		if(iLen == ++i || sText[i - 1] == ',')
		{
			char sBuf[64];

			strcopy(sBuf, i - iLastSize, sText[iLastSize]);
			hArray.PushString(sBuf);

			iLastSize = i;
		}
	}

	if(!iLastSize)
	{
		PrintToServer(sText);
		hArray.PushString(sText);
	}
}

void OnRoundStart()
{
	g_bOPKill = false;
	g_hSmokeEnt.Clear();
	g_iMinSmokes = 0;
}

public Action FPS_OnPointsChangePre(int iAttacker, int iVictim, Event hEvent, float& fAddPointsAttacker, float& fAddPointsVictim)
{
	if (FPS_StatsActive())
	{
		static char sWeapon[32];
		hEvent.GetString("weapon", sWeapon, sizeof(sWeapon));

		if(g_hSettings.ProhibitedWeapons.FindString(sWeapon) == -1 && sWeapon[0] != 'k' && sWeapon[2] != 'y')
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

			if(!GetEntData(iAttacker, m_bIsScoped) && g_hSettings.NoScopeWeapons.FindString(sWeapon) != -1)
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

			if(g_flMinFlash < GetEntDataFloat(iAttacker, m_flFlashDuration))
			{
				iUKFlags |= UnusualKill_Flash;
			}

			for(int i = g_iMinSmokes, iSmokeEntity; i != g_hSmokeEnt.Length;)
			{
				if(IsValidEntity((iSmokeEntity = g_hSmokeEnt.Get(i++))))
				{
					static float vecClient[3], 
								vecAttacker[3], 
								vecSmoke[3],

								flDistance,
								flDistance2,
								flDistance3;

					GetEntDataVector(iVictim, m_vecOrigin, vecClient);
					GetEntDataVector(iAttacker, m_vecOrigin, vecAttacker);
					GetEntDataVector(iSmokeEntity, m_vecOrigin, vecSmoke);

					vecClient[2] -= 64.0;

					flDistance = GetVectorDistance(vecClient, vecSmoke);
					flDistance2 = GetVectorDistance(vecAttacker, vecSmoke);
					flDistance3 = GetVectorDistance(vecClient, vecAttacker);

					if((flDistance + flDistance2) * 0.7 <= flDistance3 + RadiusSmoke)
					{
						float flHalfPerimeter = (flDistance + flDistance2 + flDistance3) / 2.0;

						if((2.0 * SquareRoot(flHalfPerimeter * (flHalfPerimeter - flDistance) * (flHalfPerimeter - flDistance2) * (flHalfPerimeter - flDistance3))) / flDistance3 < RadiusSmoke)
						{
							iUKFlags |= UnusualKill_Smoke;
							break;
						}
					}
				}
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
				char sColumns[MAX_UKTYPES * 16],
					 sQuery[256];

				for(int iType = 0; iType != MAX_UKTYPES; iType++)
				{
					if(iUKFlags & (1 << iType))
					{
						FormatEx(sColumns, sizeof(sColumns), "%s`%s` = %d, ", sColumns, g_sNameUK[iType], ++g_iUK[iAttacker][iType]);

						if(g_iExp[iType])
						{
							if(g_iExpMode == 1 && g_iExp[iType] > 0)
							{
								FPS_PrintToChat(iAttacker, "%T: \x04+%i.0", g_sNameUK[iType], iAttacker, g_iExp[iType]);
							}

							if (g_iExpMode)
							{
								fAddPointsAttacker += float(g_iExp[iType]);
							}
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

void OnSmokeEvent(Event hEvent, const char[] sName)
{
	if(sName[13] == 'd')
	{
		g_hSmokeEnt.Push(hEvent.GetInt("entityid"));
		return;
	}

	if(++g_iMinSmokes == g_hSmokeEnt.Length)
	{
		g_hSmokeEnt.Clear();
		g_iMinSmokes = 0;
	}
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

public void OnClientSayCommand_Post(int iClient, const char[] sCommand, const char[] sArgs)
{
	if(g_hSettings.ChatCommands.FindString(sArgs) != -1)
	{
		UnusualKillMenu(iClient);
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
	if(action == MenuAction_Select)
	{
		if (iOption == 7)
		{
			FPS_MoveToMenu(iClient, FPS_STATS_MENU);
		}
		ClientCommand(iClient, "playgamesound *buttons/combine_button7.wav");
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
		ClientCommand(iClient, "playgamesound *buttons/combine_button7.wav");
	}
}
