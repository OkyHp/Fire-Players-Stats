#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <FirePlayersStats>

#if FPS_INC_VER < 13
	#error "FirePlayersStats.inc is outdated and not suitable for compilation!"
#endif

#define Crash(%0) SetFailState("[FPS] Unusual Kills: " ... %0)

#define MAX_UKTYPES 9
#define UnusualKill_None 0
#define UnusualKill_OpenFrag (1 << 1)
#define UnusualKill_Penetrated (1 << 2)
#define UnusualKill_NoScope (1 << 3)
#define UnusualKill_Run (1 << 4)
#define UnusualKill_Jump (1 << 5)
#define UnusualKill_Flash (1 << 6)
#define UnusualKill_Smoke (1 << 7)
#define UnusualKill_Whirl (1 << 8)
#define UnusualKill_LastClip (1 << 9)

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
#define SQL_LoadPlayer "SELECT `op`, `penetrated`, `no_scope`, `run`, `jump`, `flash`, `smoke`, `whirl`, `last_clip` FROM `fps_unusualkills` WHERE `account_id` = '%i' AND `server_id` = '%i';"
#define SQL_SavePlayer "UPDATE `fps_unusualkills` SET %s WHERE `account_id` = '%i' AND `server_id` = '%i';"

#define RadiusSmoke 100.0

enum ArrayListBuffer
{
	ArrayList:ChatCommands = 0,
	ArrayList:ProhibitedWeapons,
	ArrayList:NoScope_Weapons
};

bool  	  g_bOPKill,
		  g_bShowItem[MAX_UKTYPES];

int 	  g_iPlayerAccountID[MAXPLAYERS+1],
		  g_iExp[MAX_UKTYPES],
		  g_iExpMode,
		  g_iMinSmokes,
		  g_iMouceX[MAXPLAYERS+1],
		  g_iWhirlInterval = 1,
		  g_iUK[MAXPLAYERS+1][MAX_UKTYPES],
		  g_iWhirl = 300,
		  m_bIsScoped,
		  m_iClip1,
		  m_hActiveWeapon,
		  m_flFlashDuration,
		  m_vecOrigin,
		  m_vecVelocity;

float	  g_flMinFlash = 5.0,
		  g_flMinLenVelocity = 100.0;

static const char
		  g_sNameUK[][] = {"op", "penetrated", "no_scope", "run", "jump", "flash", "smoke", "whirl", "last_clip"};

static const char g_sFeature[] = "FPS_UnusualKills";

EngineVersion
		  g_iEngine;

Database  g_hDatabase;

ArrayList g_hBuffer[ArrayListBuffer],
		  g_hSmokeEnt;

public Plugin myinfo = 
{
	name = "FPS Unusual Kills", 
	author = "Wend4r, OkyHp", 
	version = "1.0.0", 
	url = "Discord: Wend4r#0001 | VK: vk.com/wend4r"
}

public void OnPluginStart()
{
	m_bIsScoped = FindSendPropInfo("CCSPlayer", "m_bIsScoped");
	m_iClip1 = FindSendPropInfo("CBaseCombatWeapon", "m_iClip1");
	m_hActiveWeapon = FindSendPropInfo("CBasePlayer", "m_hActiveWeapon");
	m_flFlashDuration = FindSendPropInfo("CCSPlayer", "m_flFlashDuration");
	m_vecOrigin = FindSendPropInfo("CBaseEntity", "m_vecOrigin");
	m_vecVelocity = FindSendPropInfo("CBasePlayer", "m_vecVelocity[0]");

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
	FPS_AddFeature(g_sFeature, FPS_STATS_MENU, OnItemSelect, OnItemDisplay);

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
		FPS_RemoveFeature(g_sFeature);
	}
}

public bool OnItemSelect(int iClient)
{
	UnusualKillMenu(iClient);
	return false;
}

public bool OnItemDisplay(int iClient, char[] szDisplay, int iMaxLength)
{
	FormatEx(szDisplay, iMaxLength, "%T", "UnusualKill", iClient);
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
	if(iClient > 0)
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

	if(!sPath[0])
	{
		for(ArrayListBuffer i; i != ArrayListBuffer; i++)
		{
			g_hBuffer[i] = new ArrayList(64);
		}

		BuildPath(Path_SM, sPath, sizeof(sPath), "configs/FirePlayersStats/unusual_kills.ini");
	}

	if(!hKv.ImportFromFile(sPath))
	{
		Crash("LoadSettings: %s - not found!", sPath);
	}
	hKv.GotoFirstSubKey();

	hKv.Rewind();
	hKv.JumpToKey("Settings");	/**/

	g_iExpMode = hKv.GetNum("Exp_Mode", 1);

	hKv.GetString("ChatCommands", sBuffer, sizeof(sBuffer), "!uk,!ukstats,!unusualkills");
	ExplodeInArrayList(sBuffer, ChatCommands);

	hKv.GetString("ProhibitedWeapons", sBuffer, sizeof(sBuffer), "hegrenade,molotov,incgrenade");
	ExplodeInArrayList(sBuffer, ProhibitedWeapons);

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
				continue;
			}
			case 2:
			{
				hKv.GetString("weapons", sBuffer, sizeof(sBuffer));
				ExplodeInArrayList(sBuffer, NoScope_Weapons);
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
				g_iWhirl = hKv.GetNum("whirl", 300);
				g_iWhirlInterval = hKv.GetNum("interval", 1);
			}
		}

		g_iExp[iUKType] = g_iExpMode ? hKv.GetNum("exp") : 0;
		g_bShowItem[iUKType] = view_as<bool>(hKv.GetNum("menu", 1));
	}
	while(hKv.GotoNextKey());

	delete hKv;
}

void ExplodeInArrayList(const char[] sText, ArrayListBuffer Array)
{
	int  iLastSize = 0;

	for(int i = 0, iLen = strlen(sText)+1; i != iLen;)
	{
		if(iLen == ++i || sText[i-1] == ',')
		{
			char sBuf[64];

			strcopy(sBuf, i-iLastSize, sText[iLastSize]);
			g_hBuffer[Array].PushString(sBuf);

			iLastSize = i;
		}
	}

	if(!iLastSize)
	{
		PrintToServer(sText);
		g_hBuffer[Array].PushString(sText);
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

		if(g_hBuffer[ProhibitedWeapons].FindString(sWeapon) == -1)
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

			if(g_iEngine == Engine_CSGO && !GetEntData(iAttacker, m_bIsScoped) && g_hBuffer[NoScope_Weapons].FindString(sWeapon) != -1)
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

			if((g_iMouceX[iAttacker] < 0 ? -g_iMouceX[iAttacker] : g_iMouceX[iAttacker]) > g_iWhirl)
			{
				iUKFlags |= UnusualKill_Whirl;
			}

			if(iActiveWeapon != -1 && !GetEntData(iActiveWeapon, m_iClip1))
			{
				iUKFlags |= UnusualKill_LastClip;
			}

			if(iUKFlags)
			{
				char sColumns[MAX_UKTYPES * 16],
					 sQuery[256];

				for(int iType = 0; iType != MAX_UKTYPES; iType++)
				{
					if(iUKFlags & (1 << iType + 1))
					{
						FormatEx(sColumns, sizeof(sColumns), "%s`%s` = %d, ", sColumns, g_sNameUK[iType], ++g_iUK[iAttacker][iType]);

						if(g_iExp[iType])
						{
							if(g_iExpMode == 1 && g_iExp[iType] > 0)
							{
								FPS_PrintToChat(iAttacker, "%T: \x04+%i.0", g_sNameUK[iType], iAttacker, g_iExp[iType]);
							}

							fAddPointsAttacker += float(g_iExp[iType]);
						}
					}
				}

				sColumns[strlen(sColumns)-2] = '\0';

				FormatEx(sQuery, sizeof(sQuery), SQL_SavePlayer, sColumns, g_iPlayerAccountID[iAttacker], FPS_GetID(FPS_SERVER_ID));
				g_hDatabase.Query(SQL_Default_Callback, sQuery, 3);

				return Plugin_Changed;
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

	if((g_iMouceX[iClient] += iMouse[0]) && iInterval[iClient] - GetTime() <= 0)
	{
		g_iMouceX[iClient] = 0;
		iInterval[iClient] = GetTime() + g_iWhirlInterval;
	}
}

public void OnClientSayCommand_Post(int iClient, const char[] sCommand, const char[] sArgs)
{
	if(g_hBuffer[ChatCommands].FindString(sArgs) != -1)
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

	FormatEx(sBuffer, sizeof(sBuffer), "[ %t ]\n ", "UnusualKill");
	hPanel.SetTitle(sBuffer);

	sBuffer[0] = 0;
	if(iKills)
	{
		for(int i = 0; i != MAX_UKTYPES; i++)
		{
			if(g_bShowItem[i])
			{
				int iPercent = 100 * g_iUK[iClient][i] / iKills;

				FormatEx(sTrans, sizeof(sTrans), "Menu_%s", g_sNameUK[i]);
				Format(sBuffer, sizeof(sBuffer), "%s%t\n", sBuffer, sTrans, g_iUK[iClient][i], iPercent || !g_iUK[iClient][i] ? iPercent : 1);
			}
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
