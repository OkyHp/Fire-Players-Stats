#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <FirePlayersStats>

int		g_iPlayerLevel[MAXPLAYERS+1],
		g_iPlayerPosition[MAXPLAYERS+1],
		g_iPlayersCount;
float	g_fPlayerPoints[MAXPLAYERS+1];
char	g_sPlayerRank[MAXPLAYERS+1][256];

public Plugin myinfo =
{
	name	=	"FPS Hud Info",
	author	=	"OkyHp",
	version	=	"1.0.0",
	url		=	"https://blackflash.ru/, https://dev-source.ru/, https://hlmod.ru/"
};

public void OnPluginStart()
{
	LoadTranslations("FPS_HudInfo.phrases");

	if (FPS_StatsLoad())
	{
		FPS_OnFPSStatsLoaded();
	}
}

public void FPS_OnFPSStatsLoaded()
{
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (FPS_ClientLoaded(i))
		{
			FPS_OnClientLoaded(i, FPS_GetPoints(i));
		}
	}
}

public void FPS_OnClientLoaded(int iClient, float fPoints)
{
	g_fPlayerPoints[iClient] = fPoints;
	GetPlayerLevel(iClient, FPS_GetLevel(iClient));
}

public void FPS_OnPointsChange(int iAttacker, int iVictim, float fPointsAttacker, float fPointsVictim)
{
	g_fPlayerPoints[iAttacker] = fPointsAttacker;
	g_fPlayerPoints[iVictim] = fPointsVictim;
}

public void FPS_OnLevelChange(int iClient, int iOldLevel, int iNewLevel)
{
	GetPlayerLevel(iClient, iNewLevel);
}

public void FPS_PlayerPosition(int iClient, int iPosition, int iPlayersCount)
{
	g_iPlayerPosition[iClient] = iPosition;
	g_iPlayersCount = iPlayersCount;
}

void GetPlayerLevel(int iClient, int iLevel)
{
	g_iPlayerLevel[iClient] = iLevel;
	FPS_GetRanks(iClient, g_sPlayerRank[iClient], sizeof(g_sPlayerRank[]));
}

int GetSuspect(int iClient)
{
    if(GetEntProp(iClient, Prop_Send, "m_iObserverMode")==6 || !(GetUserFlagBits(iClient) & ADMFLAG_BAN || GetUserFlagBits(iClient) & ADMFLAG_ROOT)) return -1;
    
    int iTarget = GetEntPropEnt(iClient, Prop_Send, "m_hObserverTarget");
    if(iTarget < 65) return iTarget;
    return -1;
}

public void OnPlayerRunCmdPost(int iClient)
{
	if (GetEntProp(iClient, Prop_Send, "m_iObserverMode") != 6)
	{
		int iTarget = GetSuspect(iClient);
		if (iTarget != -1 && FPS_ClientLoaded(iTarget))
		{
			PrintHintText(iClient, "%t", "HudMessage", g_fPlayerPoints[iTarget], g_iPlayerLevel[iTarget], g_iPlayerPosition[iTarget], g_iPlayersCount, g_sPlayerRank[iTarget]);
		}
	}
}

public void OnClientDisconnect(int iClient)
{
	g_iPlayerLevel[iClient] = 0;
	g_iPlayerPosition[iClient] = 0;
	g_fPlayerPoints[iClient] = 0.0;
	g_sPlayerRank[iClient][0] = 0;
}
