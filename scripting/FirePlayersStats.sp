#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <FirePlayersStats>

#undef REQUIRE_EXTENSIONS
#include <SteamWorks>

#if FPS_INC_VER != 155
	#error "FirePlayersStats.inc is outdated and not suitable for compilation! Version required: 155"
#endif

/////////////////////////////////////// PRECOMPILATION SETTINGS ///////////////////////////////////////

#define DEBUG					0		// 0 - Disable debug;
										// 1 - SQL query debug;
										// 2 - Action debug;
										// 3 - Full debug;
#define USE_STREAK_POINTS		1		// Use streak points in stats
#define UPDATE_SERVER_DATA		0		// 0 - Disable. It is necessary if you use domain instead of IP. 
#define DEFAULT_POINTS			1000.0	// Not recommended change

///////////////////////////////////////////////////////////////////////////////////////////////////////

#define PLUGIN_VERSION		"1.6.0-DEV"

#if DEBUG != 0
	char	g_sLogPath[PLATFORM_MAX_PATH];
	int		g_iBlockWarning;
	#define FPS_Debug(%0,%1,%2,%3);	g_iBlockWarning = %0; \
				if(g_iBlockWarning <= DEBUG){ \
					LogToFile(g_sLogPath, "[VER:%s][LINE:%d][LVL:%i][FUNC:%s] " ... %2, PLUGIN_VERSION, __LINE__, g_iBlockWarning, %1, %3); \
				}
#else
	#define FPS_Debug(%0);
#endif

// Others vars
int			g_iPlayerData[MAXPLAYERS+1][7],
			g_iPlayerSessionData[MAXPLAYERS+1][7],
			g_iPlayerAccountID[MAXPLAYERS+1],
			g_iPlayerPosition[MAXPLAYERS+1],
			g_iPlayersCount,
			g_iGameType[2],
			g_iServerIP,
			g_iServerPort;
float		g_fPlayerPoints[MAXPLAYERS+1],
			g_fPlayerSessionPoints[MAXPLAYERS+1];
bool		g_bStatsLoaded,
			g_bStatsLoad[MAXPLAYERS+1],
			g_bStatsActive,
			g_bDisableStatisPerRound,
			g_bTeammatesAreEnemies;
char		g_sMap[256];

// Points config
KeyValues	g_hWeaponsConfigKV;

// Extra points for map
StringMap	g_hWeaponExtraPoints;

// Features
enum
{
	F_MENU_TYPE = 1,
	F_PLUGIN,
	F_SELECT,
	F_DISPLAY,
	F_DRAW,
	F_COUNT
}

ArrayList	g_hItems;

// Ranks settings
int			g_iRanksCount,
			g_iPlayerRanks[MAXPLAYERS+1];
char		g_sRankName[MAXPLAYERS+1][64];
ArrayList	g_hRanks;

// Weapons stats vars
enum
{
	W_ID = 0,
	W_KILLS,
	W_SHOOTS,
	W_HITS_HEAD,
	W_HITS_CHEST,
	W_HITS_STOMACH,
	W_HITS_LEFT_ARM,
	W_HITS_RIGHT_ARM,
	W_HITS_LEFT_LEG,
	W_HITS_RIGHT_LEG,
	W_HITS_NECK,
	W_HEADSHOTS,
	W_SIZE
}

int			g_iDefinitionIndex,
			g_iPlayerWeaponData[MAXPLAYERS+1][W_SIZE];
CSWeaponID	g_iPlayerActiveWeapon[MAXPLAYERS+1];
ArrayList	g_hWeaponsData[MAXPLAYERS+1];

// Database vars
Database	g_hDatabase;

// Top Data
float		g_fTopData[10][4];
char		g_sTopData[10][4][64];

#include "FirePlayersStats/config.sp"
#include "FirePlayersStats/database.sp"
#include "FirePlayersStats/api.sp"
#include "FirePlayersStats/events.sp"
#include "FirePlayersStats/menu.sp"
#include "FirePlayersStats/others.sp"

public Plugin myinfo =
{
	name	=	"Fire Players Stats",
	author	=	"OkyHp, Someone",
	version	=	PLUGIN_VERSION,
	url		=	"https://blackflash.ru/, https://discord.gg/M82xN4y"
};

public void OnPluginStart()
{
	#if DEBUG != 0
		BuildPath(Path_SM, SZF(g_sLogPath), "logs/FirePlayersStats.log");
		FPS_Debug(2, "OnPluginStart", "%s", "Start plugin");
	#endif

	g_iDefinitionIndex = FindSendPropInfo("CEconEntity", "m_iItemDefinitionIndex");

	g_hItems = new ArrayList(ByteCountToCells(64));
	g_hRanks = new ArrayList(ByteCountToCells(64));
	g_hWeaponExtraPoints = new StringMap();

	LoadTranslations("FirePlayersStats.phrases");
	char szPath[256];
	BuildPath(Path_SM, SZF(szPath), "translations/FirePlayersStatsRanks.phrases.txt");
	if (FileExists(szPath, false, NULL_STRING))
	{
		LoadTranslations("FirePlayersStatsRanks.phrases");
	}

	RegAdminCmd("sm_fps_create_default_ranks", CommandCreateRanks, ADMFLAG_ROOT, "Создание настройки рангов. \
	\n0 - Стандартные ранги (18 lvl). 1 - Ранги опасной зоны (15 lvl). 2 - Фейсит ранги (10 lvl).");
	RegAdminCmd("sm_fps_reset_all_stats", CommandResetAllStats, ADMFLAG_ROOT, "Сбросить всю статистику для текущего сервера.");


	ConVar Convar;
	(Convar = FindConVar("mp_teammates_are_enemies")).AddChangeHook(ChangeCvar_TeammatesAreEnemies);
	ChangeCvar_TeammatesAreEnemies(Convar, NULL_STRING, NULL_STRING);
	(Convar = FindConVar("game_type")).AddChangeHook(ChangeCvar_GameType);
	ChangeCvar_GameType(Convar, NULL_STRING, NULL_STRING);
	(Convar = FindConVar("game_mode")).AddChangeHook(ChangeCvar_GameMode);
	ChangeCvar_GameMode(Convar, NULL_STRING, NULL_STRING);

	g_iServerIP		= FindConVar("hostip").IntValue;
	g_iServerPort	= FindConVar("hostport").IntValue;

	SetCvars();
	CreateGlobalForwards();
	HookEvents();
	SetCommands();
	DatabaseConnect();
}

void ChangeCvar_TeammatesAreEnemies(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	g_bTeammatesAreEnemies = Convar.BoolValue;
}

void ChangeCvar_GameType(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	g_iGameType[0] = Convar.IntValue;
}

void ChangeCvar_GameMode(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	g_iGameType[1] = Convar.IntValue;
}

public void OnMapStart()
{
	GetMapExtraPoints();
	LoadRanksSettings();
	LoadTopData();
	UpdateServerData();

	GetCurrentMapEx(SZF(g_sMap));
	
	if (g_iGameType[0] == 1 && g_iGameType[1] == 2 && g_iSaveInterval)
	{
		CreateTimer(float(g_iSaveInterval * 60), TimerSaveStats, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}

	if (CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "SteamWorks_CreateHTTPRequest") == FeatureStatus_Available)
	{
		SteamWorks_SteamServersConnected();
	}

	DeleteInactivePlayers();
}

Action TimerSaveStats(Handle hTimer)
{
	if (g_iGameType[0] != 1 && g_iGameType[1] != 2)
	{
		return Plugin_Stop;
	}

	for (int i = MaxClients + 1; --i;)
	{
		if (g_bStatsLoad[i])
		{
			FPS_Debug(2, "TimerSaveStats", "Call Save Function (TimerSaveStats) >> %N", i);
			SavePlayerData(i);
		}
	}

	LoadTopData();
	for (int i = MaxClients + 1; --i;)
	{
		if (g_bStatsLoad[i])
		{
			GetPlayerPosition(i);
		}
	}
	CallForward_OnFPSSecondDataUpdated();
	
	return Plugin_Continue;
}

public void SteamWorks_SteamServersConnected()
{
	int iIP[4];
	if (SteamWorks_GetPublicIP(iIP))
	{
		char szBuffer[256];
		Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, "https://stats.tibari.ru/api/v1/add_server");
		FormatEx(SZF(szBuffer), "key=c30facaa6f64ce25357e7c5ed1685afd&ip=%i.%i.%i.%i&port=%i&version=%s&sm=%s", 
			iIP[0], iIP[1], iIP[2], iIP[3], g_iServerPort, PLUGIN_VERSION, SOURCEMOD_VERSION
		);
		SteamWorks_SetHTTPRequestRawPostBody(hRequest, "application/x-www-form-urlencoded", SZF(szBuffer));
		SteamWorks_SetHTTPCallbacks(hRequest, OnTransferComplete);
		SteamWorks_SendHTTPRequest(hRequest);
	}
}

int OnTransferComplete(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode)
{
	delete hRequest;
	int iStatus = view_as<int>(eStatusCode);
	if (iStatus < 500)
	{
		switch(iStatus)
		{
			case 200:	LogAction(-1, -1, "[FPS Stats] >> Сервер успешно добавлен/обновлен");
			case 400:	PrintToServer("[FPS Stats] >> Не верный запрос");
			case 403:	PrintToServer("[FPS Stats] >> Не верный IP:PORT");
			case 404:	PrintToServer("[FPS Stats] >> Сервер или версия не найдены в базе данных");
			case 406:	PrintToServer("[FPS Stats] >> Не верный API KEY");
			case 410:	PrintToServer("[FPS Stats] >> Ваша версия Fire Players Stats не поддерживается!");
			case 413:	PrintToServer("[FPS Stats] >> Не верный размер аргументов");
			case 429:	return;
			default:	PrintToServer("[FPS Stats] >> Не известная ошибка: %i", iStatus);
		}
	}
}

public void OnClientPutInServer(int iClient)
{
	if (iClient && !IsFakeClient(iClient) && !IsClientSourceTV(iClient))
	{
		int iAccountID = GetSteamAccountID(iClient, true);
		if (iAccountID)
		{
			FPS_Debug(2, "OnClientPutInServer", "Client connected >> %N", iClient);

			g_iPlayerAccountID[iClient] = iAccountID;
			g_iPlayerSessionData[iClient][MAX_ROUNDS_KILLS] = 0; // (not used var) for blocked accrual of experience to connected player
			g_hWeaponsData[iClient] = new ArrayList(W_SIZE);
			SDKHook(iClient, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);

			LoadPlayerData(iClient);
		}
	}
}

public void OnClientDisconnect(int iClient)
{
	CallForward_OnFPSClientDisconnect(iClient);
	
	if (g_bStatsLoad[iClient])
	{
		SavePlayerData(iClient);
	}

	ResetData(iClient);
}
