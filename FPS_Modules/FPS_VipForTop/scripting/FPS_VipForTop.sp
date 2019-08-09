#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <vip_core>
#include <FirePlayersStats>

int			g_iVipQuota;
bool		g_bIsVip[MAXPLAYERS+1];
KeyValues	g_hConfig;

public Plugin myinfo =
{
	name	=	"FPS Vip For Top",
	author	=	"OkyHp",
	version	=	"1.0.1",
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

// public void VIP_OnClientLoaded(int iClient, bool bIsVIP)
// {
// 	g_bIsVip[iClient] = bIsVIP;
// 	LogError("[VIP_OnClientLoaded] >> %s", g_bIsVip[iClient] ? "TRUE" : "FASLE");
// }

// public void VIP_OnVIPClientAdded(int iClient, int iAdmin)
// {
// 	g_bIsVip[iClient] = true;
// 	LogError("[VIP_OnVIPClientAdded] >> %s", g_bIsVip[iClient] ? "TRUE" : "FASLE");
// }

public void VIP_OnVIPClientLoaded(int iClient)
{
	g_bIsVip[iClient] = true;
}

public void VIP_OnVIPClientAdded(int iClient, int iAdmin)
{
	LogError("[VIP_OnVIPClientAdded] >> %s | %i", g_bIsVip[iClient] ? "TRUE" : "FASLE", iAdmin);
	g_bIsVip[iClient] = true;
}

public void OnClientDisconnect(int iClient)
{
	g_bIsVip[iClient] = false;
}

public void FPS_PlayerPosition(int iClient, int iPosition, int iPlayersCount)
{
	static int iPos[MAXPLAYERS+1];
	if (!g_bIsVip[iClient] && iPos[iClient] != iPosition)
	{
		if (iPosition > g_iVipQuota)
		{
			VIP_RemoveClientVIP2(-1, iClient, false, false);
			LogError("[FPS_PlayerPosition] >> Игроку %N удалена вип группа %i", iClient, iPosition);
		}
		else
		{
			char	szPos[4],
					szVipGroup[32];
			IntToString(iPosition, szPos, sizeof(szPos));

			g_hConfig.Rewind();
			g_hConfig.GetString(szPos, szVipGroup, sizeof(szVipGroup), NULL_STRING);
			if (szVipGroup[0])
			{
				VIP_GiveClientVIP(-1, iClient, 0, szVipGroup, false);
				LogError("[FPS_PlayerPosition] >> Игроку %N за %i место установлена вип группа: %s", iClient, iPosition, szVipGroup);
			}
		}
	}
	iPos[iClient] = iPosition;
}
