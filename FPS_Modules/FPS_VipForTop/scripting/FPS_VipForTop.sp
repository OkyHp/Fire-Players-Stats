#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <vip_core>
#include <FirePlayersStats>

#define DEFAULT 0
#define STATS	1

int			g_iVipQuota,
			g_iPos[MAXPLAYERS+1];
KeyValues	g_hConfig;

public Plugin myinfo =
{
	name	=	"FPS Vip For Top",
	author	=	"OkyHp",
	version	=	"1.3.0",
	url		=	"https://blackflash.ru/, https://dev-source.ru/, https://hlmod.ru/"
};

public void OnMapStart()
{
	char szPath[256];
	g_hConfig = new KeyValues("Config");
	BuildPath(Path_SM, szPath, sizeof(szPath), "configs/FirePlayersStats/vip_for_top.ini");
	if(!g_hConfig.ImportFromFile(szPath))
	{
		SetFailState("No found file: '%s'.", szPath);
	}

	g_iVipQuota = 0;
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
	CreateTimer(3.0, TimerCheckVip, (view_as<int>(bIsVIP) << 16) | GetClientUserId(iClient), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

Action TimerCheckVip(Handle hTimer, any aData)
{
	int iClient = GetClientOfUserId(aData & 0x0000FFFF);
	aData >>= 16;
	if (iClient && !aData)
	{
		if (g_iPos[iClient] != -1)
		{
			if(g_iPos[iClient] <= g_iVipQuota)
			{
				char	szPos[4],
						szVipGroup[32];
				IntToString(g_iPos[iClient], szPos, sizeof(szPos));

				g_hConfig.Rewind();
				g_hConfig.GetString(szPos, szVipGroup, sizeof(szVipGroup), NULL_STRING);
				if (szVipGroup[0])
				{
					// VIP_SetClientVIP(iClient, 0, 0, szVipGroup, false);
					VIP_GiveClientVIP(-1, iClient, 0, szVipGroup, false);

					switch(GetClientLanguage(iClient))
					{
						case 22: FPS_PrintToChat(iClient, "Вы получили привилегию {GREEN}%s {DEFAULT}за {OLIVE}%s {DEFAULT}место на сервере!", szVipGroup, szPos);
						case 30: FPS_PrintToChat(iClient, "Ви отримали привілей {GREEN}%s {DEFAULT}за {OLIVE}%s {DEFAULT}місце на сервері!", szVipGroup, szPos);
						default: FPS_PrintToChat(iClient, "You got {GREEN}%s {DEFAULT}privilege for {OLIVE}%s {DEFAULT}place on the server!", szVipGroup, szPos);
					}

					PrintToServer("[FPS_VipForTop] >> Игроку %N за %i место установлена вип группа (Период: сессия): %s", iClient, g_iPos[iClient], szVipGroup);
				}
			}

			return Plugin_Stop;
		}
		return Plugin_Continue;
	}
	return Plugin_Stop;
}

public void OnClientDisconnect(int iClient)
{
	g_iPos[iClient] = -1;
}

public void FPS_PlayerPosition(int iClient, int iPosition, int iPlayersCount)
{
	g_iPos[iClient] = iPosition;
}
