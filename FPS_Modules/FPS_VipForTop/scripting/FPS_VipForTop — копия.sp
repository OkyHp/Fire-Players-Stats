#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <vip_core>
#include <FirePlayersStats>

#define DEFAULT 0
#define STATS	1

int			g_iVipQuota;
bool		g_bIsVip[MAXPLAYERS+1][2];
KeyValues	g_hConfig;

public Plugin myinfo =
{
	name	=	"FPS Vip For Top",
	author	=	"OkyHp",
	version	=	"1.1.0",
	url		=	"https://blackflash.ru/, https://dev-source.ru/, https://hlmod.ru/"
};

public void OnPluginStart()
{
	if(GetEngineVersion() != Engine_CSGO)
	{
		SetFailState("This plugin works only on CS:GO");
	}

	char szPath[256];
	g_hConfig = new KeyValues("Config");
	BuildPath(Path_SM, szPath, sizeof(szPath), "configs/FirePlayersStats/vip_for_top.ini");
	if(!g_hConfig.ImportFromFile(szPath))
	{
		SetFailState("No found file: '%s'.", szPath);
	}

	g_hConfig.Rewind();
	if (g_hConfig.GotoFirstSubKey(false))
	{
		do {
			++g_iVipQuota;
		} while (g_hConfig.GotoNextKey(false));
	}
}

public void VIP_OnClientLoaded(int iClient, bool bIsVIP)
{
	g_bIsVip[iClient][DEFAULT] = bIsVIP;
}

public void VIP_OnVIPClientAdded(int iClient, int iAdmin)
{
	g_bIsVip[iClient][DEFAULT] = true;
}

public void VIP_OnVIPClientRemoved(int iClient, const char[] szReason, int iAdmin)
{
	g_bIsVip[iClient][DEFAULT] = false;
}

public void OnClientDisconnect(int iClient)
{
	for (int i = 0; i < 2; ++i)
	{
		g_bIsVip[iClient][i] = false;
	}
}

public void FPS_PlayerPosition(int iClient, int iPosition, int iPlayersCount)
{
	static int iPos[MAXPLAYERS+1];
	if (!g_bIsVip[iClient][DEFAULT] && !FPS_IsCalibration(iClient) && iPos[iClient] != iPosition)
	{
		if (g_bIsVip[iClient][STATS])
		{
			g_bIsVip[iClient][STATS] = false;
			// VIP_RemoveClientVIP(iClient, false, false);
			VIP_RemoveClientVIP2(-1, iClient, false, false);
			PrintToServer("[FPS_PlayerPosition] >> Игроку %N удалена вип группа %i", iClient, iPosition);
		}

		if(iPosition <= g_iVipQuota)
		{
			char	szPos[4],
					szVipGroup[32];
			IntToString(iPosition, szPos, sizeof(szPos));

			g_hConfig.Rewind();
			g_hConfig.GetString(szPos, szVipGroup, sizeof(szVipGroup), NULL_STRING);
			if (szVipGroup[0])
			{
				g_bIsVip[iClient][STATS] = true;
				// VIP_SetClientVIP(iClient, 0, 0, szVipGroup, false);
				VIP_GiveClientVIP(-1, iClient, 0, szVipGroup, false);
				PrintToServer("[FPS_PlayerPosition] >> Игроку %N за %i место установлена вип группа: %s", iClient, iPosition, szVipGroup);
			}
		}
	}
	iPos[iClient] = iPosition;
}
