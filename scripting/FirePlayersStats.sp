/**
 * TODO:
 * - Перекинуть конфиг для юзания с под БД.
 * ----------------------------------------------------------------------------------------------
 * Информация/особенности (в сравнении с Levels Ranks) статистики:
 * - Поддержка только CS:GO.
 * - Статистики работает на основе формулы ELO Levels Ranks (за основу бралась именно она).
 * - Статистика работает только с MySQL и расчитана на работу с ВЕБом.
 * - Количетсво рангов неограничено. Натройка произвордися напрямую с БД или через ВЕБ.
 * - Совмещенная база данных на нескольких серверов (по принципу випки от Рико).
 * - Статистика по оружию хранится в отдельной таблице, из-за чего при выходе нового 
 		оружия изменять плагин и БД не прийдется.
 * - Попытка исправить превосходство новых игроков перед старыми в получении поинтов.
 * - Начисление срика возможно только в течении 10 сек после убийства, после чего идет обнуление.
 * - Можно установить лимит обнуления статистики по времени для пользователя.
 * ----------------------------------------------------------------------------------------------
 * Ranks settings query: 
		INSERT INTO `fps_test`.`fps_ranks` (`rank_id`, `rank_name`, `points`) 
		VALUES 
			('1', 'Silver I', '650'),
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
//#include <sdkhooks>
#include <FirePlayersStats>
#include <csgo_colors>

#if FPS_INC_VER < 1
	#error "FirePlayersStats.inc is outdated and not suitable for compilation!"
#endif

#define UID(%0)				GetClientUserId(%0)
#define CID(%0)				GetClientOfUserId(%0)
#define SZF(%0)				%0, sizeof(%0)

#define DEFAULT_POINTS		1000.0
#define DEBUG				1	// Enable/Disable debug mod
#define LOAD_TYPE			0	// Use forvard for load player stats:	0 - OnClientPostAdminCheck 
								//										1 - OnClientAuthorized
#define FPS_CHAT_PREFIX			" \x04[ \x02FPS \x04] \x01"
#define FPS_PrintToChat(%0,%1)	CGOPrintToChat(%0, FPS_CHAT_PREFIX ... %1)
#define FPS_PrintToChatAll(%0)	CGOPrintToChatAll(FPS_CHAT_PREFIX ... %0)

#if DEBUG == 1
	char g_sLogPath[256];
	#define FPS_Log(%0)		LogToFile(g_sLogPath, %0);
#endif

// Others vars
int			g_iPlayerData[MAXPLAYERS+1][7],
			g_iPlayerSessionData[MAXPLAYERS+1][7],
			g_iPlayerAccountID[MAXPLAYERS+1],
			g_iPlayerPosition[MAXPLAYERS+1],
			g_iPlayersCount;
float		g_fPlayerPoints[MAXPLAYERS+1],
			g_fPlayerSessionPoints[MAXPLAYERS+1];
bool		g_bStatsLoaded,
			g_bStatsLoad[MAXPLAYERS+1],
			g_bStatsActive,
			g_bLateLoad;
// Ranks settings
int			g_iRanksCount,
			g_iPlayerRanks[MAXPLAYERS+1];
char		g_sRankName[MAXPLAYERS+1][64];
KeyValues	g_hRanksConfigKV;
// Weapons stats wars
KeyValues	g_hWeaponsKV;
// Database vars
Database	g_hDatabase;
// Top Data
int			g_iTopData[10][2];
float		g_fTopData[10][2];
char		g_sTopData[10][2][64];

enum
{
	KILLS = 0,
	DEATHS,
	ASSISTS,
	MAX_ROUNDS_KILLS,
	ROUND_WIN,
	ROUND_LOSE,
	PLAYTIME
};

#include "FirePlayersStats/config.sp"
#include "FirePlayersStats/api.sp"
#include "FirePlayersStats/database.sp"
#include "FirePlayersStats/events.sp"
#include "FirePlayersStats/menu.sp"
#include "FirePlayersStats/others.sp"

public Plugin myinfo =
{
	name	=	"Fire Players Stats",
	author	=	"OkyHp",
	version	=	"0.0.1 BETA",
	url		=	"https://blackflash.ru/, https://dev-source.ru/, https://hlmod.ru/"
};

public void OnPluginStart()
{
	if(GetEngineVersion() != Engine_CSGO)
	{
		SetFailState("This plugin works only on CS:GO");
	}

	#if DEBUG == 1
		BuildPath(Path_SM, SZF(g_sLogPath), "logs/FirePlayersStats.log");
	#endif

	SetCvars();
	CreateGlobalForwards();
	DatabaseConnect();
	HookEvents();

	g_hWeaponsKV = new KeyValues("Weapons_Stats");

	LoadTranslations("FirePlayersStats.phrases");

	g_bStatsLoaded = true;
	CallForward_OnFPSStatsLoaded();

	if (g_bLateLoad)
	{
		for (int i = 1; i <= MaxClients; ++i)
		{
			if (IsClientInGame(i) && !IsFakeClient(i) && IsClientSourceTV(i))
			{
				OnClientDisconnect(i);
				LoadPlayerData(i);
			}
		}
	}
}

public void OnMapStart()
{
	LoadRanksSettings();
	LoadTopData();
}

public void OnMapEnd()
{
	DeleteInactivePlayers();
}

#if LOAD_TYPE == 0
public void OnClientPostAdminCheck(int iClient)
#else
public void OnClientAuthorized(int iClient)
#endif
{
	if (iClient && !IsFakeClient(iClient) && !IsClientSourceTV(iClient))
	{
		#if DEBUG == 1
			FPS_Log("Client connected (Type: %i) >> LoadStats: %N", LOAD_TYPE, iClient)
		#endif

		int iAccountID = GetSteamAccountID(iClient, true);
		if (iAccountID)
		{
			g_iPlayerAccountID[iClient] = iAccountID;
			LoadPlayerData(iClient);
		}
		#if DEBUG == 1
		else
		{
			FPS_Log("GetSteamAccountID >> %N: AccountID not valid %i", iClient, iAccountID)
		}
		#endif
	}
}

public void OnClientDisconnect(int iClient)
{
	if (g_bStatsLoad[iClient])
	{
		SavePlayerData(iClient);
	}
	
	ResetData(iClient);
}
