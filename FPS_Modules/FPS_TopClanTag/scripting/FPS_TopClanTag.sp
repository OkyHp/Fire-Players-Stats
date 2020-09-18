/**
 *	v1.0.1 -	Update to new API version.
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <cstrike>
#include <FirePlayersStats>

#undef REQUIRE_PLUGIN
#include <vip_core>

int		g_iTopMax,
		g_iPlayerPosition[MAXPLAYERS+1];
bool	g_bVipLoaded;

public Plugin myinfo =
{
	name	=	"[FPS] Top Clan Tag",
	author	=	"OkyHp",
	version	=	"1.0.1",
	url		=	"https://dev-source.ru/, https://hlmod.ru/"
};

public void OnLibraryAdded(const char[] szName)
{
	if (!strcmp(szName, "vip_core"))
	{
		g_bVipLoaded = true;
	}
}

public void OnLibraryRemoved(const char[] szName)
{
	if (!strcmp(szName, "vip_core"))
	{
		g_bVipLoaded = false;
	}
}

public void OnPluginStart()
{
	if(GetEngineVersion() != Engine_CSGO)
	{
		SetFailState("This plugin works only on CS:GO");
	}

	ConVar Convar;
	(Convar = CreateConVar(
		"sm_fpsm_max_top", "100", "Максимальный уровень игрока, для установки клантега",
		_, true, 3.0
	)).AddChangeHook(ChangeCvar_MaxTop);
	ChangeCvar_MaxTop(Convar, NULL_STRING, NULL_STRING);

	AutoExecConfig(true, "FPS_TopClanTag");

	CreateTimer(5.0, view_as<Timer>(Timer_UpdateTag), _, TIMER_REPEAT);
}

public void ChangeCvar_MaxTop(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	g_iTopMax = Convar.IntValue;
}

void Timer_UpdateTag()
{
	for (int i = 1; i < MaxClients; ++i)
	{
		if (FPS_ClientLoaded(i))
		{
			SetClanTag(i);
		}
	}
}

int GetTopPos(int iClient)
{
	int i;
	while(i <= g_iTopMax)
	{
		if (g_iPlayerPosition[iClient] <= i)
		{
			return i;
		}

		i += (i > 9) ? 10 : 1;
	}
	return 0;
}

void SetClanTag(int iClient)
{
	int iPos = GetTopPos(iClient);
	if (!iPos || GetUserFlagBits(iClient) || (g_bVipLoaded && VIP_IsClientVIP(iClient)))
	{
		return;
	}

	char szBuffer[32];
	FormatEx(szBuffer, sizeof(szBuffer), "[TOP %i]", iPos);
	CS_SetClientClanTag(iClient, szBuffer);
}

public void FPS_OnPlayerPosition(int iClient, int iPosition, int iPlayersCount)
{
	g_iPlayerPosition[iClient] = iPosition;
	SetClanTag(iClient);
}
