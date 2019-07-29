#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <cstrike>
#include <FirePlayersStats>

#undef REQUIRE_PLUGIN
#include <vip_core>

int		g_iType,
		g_iPlayerPosition[MAXPLAYERS+1];
bool	g_bVipLoaded;

public Plugin myinfo =
{
	name	=	"FPS Top Clan Tag",
	author	=	"OkyHp",
	version	=	"1.0.0",
	url		=	"https://blackflash.ru/, https://dev-source.ru/, https://hlmod.ru/"
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
		"sm_fpsm_top_clan_tag_type",		"0", 
		"0 - просто заменять клантег. 1 - Сохранять текущий тег и добавлять к нему.",
		_, true, 0.0, true, 1.0
	)).AddChangeHook(ChangeCvar_WorkType);
	ChangeCvar_WorkType(Convar, NULL_STRING, NULL_STRING);

	AutoExecConfig(true, "FPS_TopClanTag");

	CreateTimer(5.0, view_as<Timer>(Timer_GetRandomInt), _, TIMER_REPEAT);
}

public void ChangeCvar_WorkType(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	g_iType = Convar.IntValue;
}

void Timer_GetRandomInt()
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
	while(i <= 100)
	{
		if (g_iPlayerPosition[iClient] <= i)
		{
			return i;
		}

		switch(i)
		{
			case 10: i = 19;
			case 20: i = 29;
			case 30: i = 39;
			case 40: i = 49;
			case 50: i = 99;
		}
		++i;
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
	switch(g_iType)
	{
		case 0:
		{
			char szTag[16];
			CS_GetClientClanTag(iClient, szTag, sizeof(szTag));
			FormatEx(szBuffer, sizeof(szBuffer), "[TOP %i] %s", iPos, szTag);
		}
		case 1: FormatEx(szBuffer, sizeof(szBuffer), "[TOP %i]", iPos);
	}
	CS_SetClientClanTag(iClient, szBuffer);
}

public void FPS_PlayerPosition(int iClient, int iPosition, int iPlayersCount)
{
	g_iPlayerPosition[iClient] = iPosition;
	SetClanTag(iClient);
}
