#pragma semicolon 1
#pragma newdecls required

/**
 *	v1.0.1 -	Change OnMapStart to OnPluginStart.
 */

#include <sourcemod>
#include <cstrike>
#include <FirePlayersStats>

public Plugin myinfo =
{
	name	=	"[FPS] Points In Scoreboard",
	author	=	"OkyHp",
	version	=	"1.0.1",
	url		=	"OkyHek#2441"
};

public void OnPluginStart()
{
	if (FPS_StatsLoad())
	{
		FPS_OnFPSStatsLoaded();
	}
}

public void FPS_OnFPSStatsLoaded()
{
	for (int i = MaxClients + 1; --i;)
	{
		if (FPS_ClientLoaded(i))
		{
			FPS_OnClientLoaded(i, FPS_GetPoints(i));
		}
	}
}

public void FPS_OnClientLoaded(int iClient, float fPoints)
{
	SetScore(iClient, fPoints);
}

public void FPS_OnPointsChange(int iAttacker, int iVictim, float fPointsAttacker, float fPointsVictim)
{
	SetScore(iAttacker, fPointsAttacker);
	SetScore(iVictim, fPointsVictim);
}

void SetScore(int iClient, float fPoints)
{
	CS_SetClientContributionScore(iClient, RoundToFloor(fPoints));
}
