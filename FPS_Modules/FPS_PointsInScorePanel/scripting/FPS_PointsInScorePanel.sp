#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <cstrike>
#include <FirePlayersStats>

public Plugin myinfo =
{
	name	=	"[FPS] Points In Score Panel",
	author	=	"OkyHp",
	version	=	"1.0.0",
	url		=	"OkyHek#2441"
};

public void OnMapStart()
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
