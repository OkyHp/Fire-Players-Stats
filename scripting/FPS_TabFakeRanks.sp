#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <FirePlayersStats>

int m_iCompetitiveRanking,
	g_iPlayerRanks[MAXPLAYERS+1];

public Plugin myinfo =
{
	name	=	"FPS Tab Fake Ranks",
	author	=	"OkyHp",
	version	=	"0.0.1",
	url		=	"https://blackflash.ru/, https://dev-source.ru/, https://hlmod.ru/"
};

public void OnPluginStart()
{
	if(GetEngineVersion() != Engine_CSGO || FPS_GetMaxRanks() != 18)
	{
		SetFailState("Game is not CS: GO or the number of ranks is not equal to 18");
	}

	m_iCompetitiveRanking = FindSendPropInfo("CCSPlayerResource", "m_iCompetitiveRanking");

	HookEvent("begin_new_match", Event_GameStart, EventHookMode_PostNoCopy);
}

public void OnMapStart()
{
	SDKHook(FindEntityByClassname(MaxClients + 1, "cs_player_manager"), SDKHook_ThinkPost, OnThinkPost);
}

public void OnMapEnd()
{
	SDKUnhook(FindEntityByClassname(MaxClients + 1, "cs_player_manager"), SDKHook_ThinkPost, OnThinkPost);
}

public void OnThinkPost(int iEntity)
{
	SetEntDataArray(iEntity, m_iCompetitiveRanking, g_iPlayerRanks, sizeof(g_iPlayerRanks));
}

public void Event_GameStart(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	UpdateFakeRanks();
}

public void FPS_OnClientLoaded(int iClient, float fPoints)
{
	g_iPlayerRanks[iClient] = FPS_GetLevel(iClient);
	UpdateFakeRanks();
}

public void FPS_OnLevelChange(int iClient, int iOldLevel, int iNewLevel)
{
	g_iPlayerRanks[iClient] = iNewLevel;
	UpdateFakeRanks();
}

void UpdateFakeRanks()
{
	CreateTimer(0.5, Timer_UpdateFakeRanks, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_UpdateFakeRanks(Handle hTimer)
{
	StartMessageAll("ServerRankRevealAll") ? EndMessage() : UpdateFakeRanks();
	return Plugin_Stop;
}