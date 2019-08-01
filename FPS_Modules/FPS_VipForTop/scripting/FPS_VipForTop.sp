#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <vip_core>
#include <FirePlayersStats>

KeyValues	g_hConfig;

public Plugin myinfo =
{
	name	=	"FPS Vip For Top",
	author	=	"OkyHp",
	version	=	"1.0.0",
	url		=	"https://blackflash.ru/, https://dev-source.ru/, https://hlmod.ru/"
};

public void OnPluginStart()
{
	if(GetEngineVersion() != Engine_CSGO)
	{
		SetFailState("This plugin works only on CS:GO");
	}
}

public void OnMapStart()
{
	if (g_hConfig)
	{
		delete g_hConfig;
	}

	char szPath[256];
	g_hConfig = new KeyValues("Config");
	BuildPath(Path_SM, szPath, sizeof(szPath), "configs/FirePlayersStats/vip_for_top.ini");
	if(!g_hConfig.ImportFromFile(szPath))
	{
		SetFailState("No found file: '%s'.", szPath);
	}
}

public void FPS_PlayerPosition(int iClient, int iPosition, int iPlayersCount)
{
	if (!iPosition && !VIP_IsClientVIP(iClient))
	{
		char	szPos[4],
				szVipGroup[32];
		IntToString(iPosition, szPos, sizeof(szPos));
		g_hConfig.Rewind();
		g_hConfig.GetString(szPos, szVipGroup, sizeof(szVipGroup), NULL_STRING);
		if (szVipGroup[0])
		{
			VIP_GiveClientVIP(-1, iClient, 0, szVipGroup, false);
		}
	}
}
