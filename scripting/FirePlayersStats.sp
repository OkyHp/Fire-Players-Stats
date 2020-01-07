/**
 * TODO:
 * - Перекинуть конфиг для юзания с под БД.
 * ------------------------------------------------------------------------------------------------
 * Ranks settings query: 
		INSERT INTO `fps_ranks` (`rank_id`, `rank_name`, `points`) 
		VALUES 
			('1', 'Silver I', '0'),
			('1', 'Silver II', '700'), 
			('1', 'Silver III', '800'), 
			('1', 'Silver IV', '850'), 
			('1', 'Silver Elite', '900'), 
			('1', 'Silver Elite Master', '925'), 
			('1', 'Gold Nova I', '950'), 
			('1', 'Gold Nova II', '975'), 
			('1', 'Gold Nova III', '1000'), 
			('1', 'Gold Nova Master', '1100'), 
			('1', 'Master Guardian I', '1250'), 
			('1', 'Master Guardian II', '1400'), 
			('1', 'Master Guardian Elite', '1600'), 
			('1', 'Distinguished Master Guardian', '1800'), 
			('1', 'Legendary Eagle', '2100'), 
			('1', 'Legendary Eagle Master', '2400'), 
			('1', 'Supreme Master First Class', '3000'), 
			('1', 'The Global Elite', '4000')
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <FirePlayersStats>
#include <SteamWorks>

#if FPS_INC_VER != 152
	#error "FirePlayersStats.inc is outdated and not suitable for compilation! Version required: 152"
#endif

/////////////////////////////////////// PRECOMPILATION SETTINGS ///////////////////////////////////////

#define UPDATE_SERVER_IP		0		// 0 - Disable. It is necessary if you use domain instead of IP. 
#define DEFAULT_POINTS			1000.0	// Not recommended change
#define DEBUG					0		// Enable/Disable debug mod
#define USE_STREAK_POINTS		1		// Use streak points in stats
#define LOAD_TYPE				0		// Use forvard for load player stats:	0 - OnClientPostAdminCheck 
										//										1 - OnClientPutInServer
#define COLOR_POINTS_ADDED		"{GREEN}+"
#define COLOR_POINTS_REDUCED	"{RED}"

///////////////////////////////////////////////////////////////////////////////////////////////////////

#define PLUGIN_VERSION		"1.5.2"

#if DEBUG == 1
	char g_sLogPath[256];
	#define FPS_Debug(%0)	LogToFile(g_sLogPath, %0);
#else
	#define FPS_Debug(%0)
#endif

// Others vars
int			g_iPlayerData[MAXPLAYERS+1][7],
			g_iPlayerSessionData[MAXPLAYERS+1][7],
			g_iPlayerAccountID[MAXPLAYERS+1],
			g_iPlayerPosition[MAXPLAYERS+1],
			g_iPlayersCount,
			g_iGameType[2];
float		g_fPlayerPoints[MAXPLAYERS+1],
			g_fPlayerSessionPoints[MAXPLAYERS+1];
bool		g_bStatsLoaded,
			g_bStatsLoad[MAXPLAYERS+1],
			g_bStatsActive,
			g_bDisableStatisPerRound,
			g_bTeammatesAreEnemies;
char		g_sMap[256];

// Features
ArrayList	g_hItems;

#define	F_MENU_TYPE			1
#define	F_PLUGIN			2
#define	F_SELECT			3
#define	F_DISPLAY			4
#define	F_DRAW				5
#define	F_COUNT				6

// Ranks settings
int			g_iRanksCount,
			g_iPlayerRanks[MAXPLAYERS+1];
char		g_sRankName[MAXPLAYERS+1][64];
ArrayList	g_hRanks;

// Weapons stats vars
ArrayList	g_hWeaponsData[MAXPLAYERS+1];

#define	W_KILLS				0
#define	W_SHOOTS			1
#define	W_HITS_HEAD			2
#define	W_HITS_NECK			3
#define	W_HITS_CHEST		4
#define	W_HITS_STOMACH		5
#define	W_HITS_LEFT_ARM		6
#define	W_HITS_RIGHT_ARM	7
#define	W_HITS_LEFT_LEG		8
#define	W_HITS_RIGHT_LEG	9
#define	W_HEADSHOTS			10
#define W_SIZE				11

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
	author	=	"OkyHp",
	version	=	PLUGIN_VERSION,
	url		=	"https://blackflash.ru/, https://dev-source.ru/, https://hlmod.ru/"
};

public void OnPluginStart()
{
	#if DEBUG == 1
		BuildPath(Path_SM, SZF(g_sLogPath), "logs/FirePlayersStats.log");
	#endif

	SetCvars();
	CreateGlobalForwards();
	DatabaseConnect();
	HookEvents();
	SetCommands();

	g_hItems = new ArrayList(ByteCountToCells(128));
	g_hRanks = new ArrayList(ByteCountToCells(64));

	LoadTranslations("FirePlayersStats.phrases");
	char szPath[256];
	BuildPath(Path_SM, SZF(szPath), "translations/FirePlayersStatsRanks.phrases.txt");
	if (FileExists(szPath, false, NULL_STRING))
	{
		LoadTranslations("FirePlayersStatsRanks.phrases");
	}

	RegAdminCmd("sm_fps_create_default_ranks", CommandCreateRanks, ADMFLAG_ROOT, "Создание настройки рангов. \
	\n0 - Стандартные ранги (18 lvl). 1 - Ранги опасной зоны (15 lvl). 2 - Фейсит ранги (10 lvl).");


	ConVar Convar;
	(Convar = FindConVar("mp_teammates_are_enemies")).AddChangeHook(ChangeCvar_TeammatesAreEnemies);
	ChangeCvar_TeammatesAreEnemies(Convar, NULL_STRING, NULL_STRING);
	(Convar = FindConVar("game_type")).AddChangeHook(ChangeCvar_GameType);
	ChangeCvar_GameType(Convar, NULL_STRING, NULL_STRING);
	(Convar = FindConVar("game_mode")).AddChangeHook(ChangeCvar_GameMode);
	ChangeCvar_GameMode(Convar, NULL_STRING, NULL_STRING);

	LoadTopData();
	LoadRanksSettings();
		
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && !IsClientSourceTV(i))
		{
			OnClientDisconnect(i);
			LoadPlayerData(i);
		}
	}

	g_bStatsLoaded = true;
	CallForward_OnFPSStatsLoaded();
}

public void ChangeCvar_TeammatesAreEnemies(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	g_bTeammatesAreEnemies = Convar.BoolValue;
}

public void ChangeCvar_GameType(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	g_iGameType[0] = Convar.IntValue;
}

public void ChangeCvar_GameMode(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	g_iGameType[1] = Convar.IntValue;
}

public void OnMapStart()
{
	LoadTopData();
	LoadRanksSettings();

	if (CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "SteamWorks_CreateHTTPRequest") == FeatureStatus_Available)
	{
		SteamWorks_SteamServersConnected();
	}

	GetCurrentMapEx(SZF(g_sMap));

	if (g_iGameType[0] == 1 && g_iGameType[1] == 2)
	{
		CreateTimer(float(g_iSaveInterval * 60), TimerSaveStats, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action TimerSaveStats(Handle hTimer)
{
	if (g_iGameType[0] != 1 && g_iGameType[1] != 2)
	{
		return Plugin_Stop;
	}

	for (int i = 1; i <= MaxClients; ++i)
	{
		if (g_bStatsLoad[i])
		{
			FPS_Debug("Call Save Function (TimerSaveStats) >> %N", i)
			SavePlayerData(i);
		}
	}

	LoadTopData();
	for (int i = 1; i <= MaxClients; ++i)
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
	if (SteamWorks_GetPublicIP(iIP)) // && iIP[0] && iIP[1] && iIP[2] && iIP[3]
	{
		int		iPort = FindConVar("hostport").IntValue;
		char	szIP[24],
				szBuffer[256];
		FormatEx(SZF(szIP), "%i.%i.%i.%i", iIP[0], iIP[1], iIP[2], iIP[3]);
		Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, "http://stats.tibari.ru/api/v1/add_server");
		FormatEx(SZF(szBuffer), "key=c30facaa6f64ce25357e7c5ed1685afd&ip=%s&port=%i&version=%s&sm=%s", szIP, iPort, PLUGIN_VERSION, SOURCEMOD_VERSION);
		SteamWorks_SetHTTPRequestRawPostBody(hRequest, "application/x-www-form-urlencoded", SZF(szBuffer));
		SteamWorks_SetHTTPCallbacks(hRequest, OnTransferComplete);
		SteamWorks_SendHTTPRequest(hRequest);

		UpdateServerData(szIP, iPort);
	}
}

public int OnTransferComplete(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode)
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

public void OnMapEnd()
{
	DeleteInactivePlayers();
}

#if LOAD_TYPE == 0
public void OnClientPostAdminCheck(int iClient)
#else
public void OnClientPutInServer(int iClient)
#endif
{
	if (iClient && !IsFakeClient(iClient) && !IsClientSourceTV(iClient))
	{
		FPS_Debug("Client connected (Type: %i) >> LoadStats: %N", LOAD_TYPE, iClient)

		int iAccountID = GetSteamAccountID(iClient, true);
		if (iAccountID)
		{
			g_iPlayerAccountID[iClient] = iAccountID;
			g_hWeaponsData[iClient] = new ArrayList(64);
			LoadPlayerData(iClient);
		}
		else
		{
			LogError("GetSteamAccountID >> %N: AccountID not valid %i", iClient, iAccountID);
		}
	}
}

public void OnClientDisconnect(int iClient)
{
	if (g_bStatsLoad[iClient])
	{
		SavePlayerData(iClient);
	}

	if (g_hWeaponsData[iClient])
	{
		delete g_hWeaponsData[iClient];
	}

	ResetData(iClient);
}
