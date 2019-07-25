#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <FirePlayersStats>

/**************************************************************************
 * При использовании модуля с ВИП-кой необходимо закинуть на сервер перевод
 * и добавить groups.ini параметр: "FakeRanks"	"1"
 **************************************************************************/
#define VIP_SUPPORT		1

int m_iCompetitiveRanking,
	g_iPlayerRanks[MAXPLAYERS+1];

#if VIP_SUPPORT == 1
	#define VIP_SUPPORTED	" (VIP supported)"

	#include <clientprefs>
	#include <vip_core>

	int		g_iVipFakeRanks[MAXPLAYERS+1],
			g_iVipStatus[MAXPLAYERS+1],
			g_iRandomRank;
	Handle	g_hCookie;
	static const char g_sFeature[][] = {"FakeRanks", "FakeRanksMenu"};
	static const char g_sRanks[][] = {
		"Silver I", "Silver II", "Silver III", "Silver IV", "Silver Elite", "Silver Elite Master",
		"Gold Nova I", "Gold Nova II", "Gold Nova III", "Gold Nova Master",
		"Master Guardian I", "Master Guardian II", "Master Guardian Elite", "Distinguished Master Guardian",
		"Legendary Eagle", "Legandary Eagle Master", "Supreme Master First Class", "The Global Elite"
	};
#else
	#define VIP_SUPPORTED	" (VIP not supported)"
#endif

public Plugin myinfo =
{
	name	=	"FPS Tab Fake Ranks" ... VIP_SUPPORTED,
	author	=	"OkyHp, Wend4r",
	version	=	"1.1.0",
	url		=	"https://blackflash.ru/, https://dev-source.ru/, https://hlmod.ru/"
};

public void OnPluginStart()
{
	if(GetEngineVersion() != Engine_CSGO)
	{
		SetFailState("This plugin works only on CS:GO");
	}

	m_iCompetitiveRanking = FindSendPropInfo("CCSPlayerResource", "m_iCompetitiveRanking");

	if (FPS_StatsLoad())
	{
		FPS_OnFPSStatsLoaded();
	}

	#if VIP_SUPPORT == 1
		g_hCookie = RegClientCookie("FPS_TabFakeRanks", "Ranks id for vip FPS_TabFakeRanks", CookieAccess_Private);

		LoadTranslations("FPS_TabFakeRanks.phrases");

		if(VIP_IsVIPLoaded())
		{
			VIP_OnVIPLoaded();
		}

		CreateTimer(0.5, view_as<Timer>(Timer_GetRandomInt), _, TIMER_REPEAT);
	#endif
}

#if VIP_SUPPORT == 1
public void OnClientCookiesCached(int iClient)
{
	char szBuffer[2];
	GetClientCookie(iClient, g_hCookie, szBuffer, sizeof(szBuffer));
	g_iVipFakeRanks[iClient] = view_as<int>(szBuffer[0]);
}

public void VIP_OnVIPLoaded()
{
	VIP_RegisterFeature(g_sFeature[0],	BOOL,		TOGGLABLE,	_,				OnDisplayItem,	_,			DISABLED);
	VIP_RegisterFeature(g_sFeature[1],	VIP_NULL,	SELECTABLE,	OnItemSelect,	OnDisplayItem,	OnItemDraw);
}

public void OnPluginEnd()
{
	if(CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "VIP_UnregisterFeature") == FeatureStatus_Available)
	{
		VIP_UnregisterFeature(g_sFeature[0]);
		VIP_UnregisterFeature(g_sFeature[1]);
	}
}

public void VIP_OnVIPClientLoaded(int iClient)
{
	g_iVipStatus[iClient] = view_as<int>(VIP_GetClientFeatureStatus(iClient, g_sFeature[0]));
}

public Action VIP_OnFeatureToggle(int iClient, const char[] szFeature, VIP_ToggleState eOldStatus, VIP_ToggleState &eNewStatus)
{
	if(!strcmp(szFeature, g_sFeature[0], false)) 
	{
		g_iVipStatus[iClient] = view_as<int>(eNewStatus);
	}
}

public bool OnDisplayItem(int iClient, const char[] szFeature, char[] szDisplay, int iMaxLength)
{
	if (!strcmp(szFeature, g_sFeature[1]))
	{
		FormatEx(szDisplay, iMaxLength, "%T", szFeature, iClient);
	}
	else
	{
		static const char szState[][] = {"Disabled", "Enabled", "No_Access"};
		SetGlobalTransTarget(iClient);
		FormatEx(szDisplay, iMaxLength, "%t [%t]", szFeature, szState[g_iVipStatus[iClient]]);
	}
	return true;
}

public int OnItemDraw(int iClient, const char[] szFeature, int iStyle)
{
	switch(g_iVipStatus[iClient])
	{
		case ENABLED: return ITEMDRAW_DEFAULT;
		case DISABLED: return ITEMDRAW_DISABLED;
		case NO_ACCESS: return ITEMDRAW_RAWLINE;
	}
	return iStyle;
}

public bool OnItemSelect(int iClient, const char[] szFeature)
{
	SetGlobalTransTarget(iClient);
	Menu hMenu = new Menu(Handler_FakeRankMenu);
	hMenu.SetTitle("[ %t ]\n ", "FakeRankMenuTitle");

	char szBuffer[64];
	FormatEx(szBuffer, sizeof(szBuffer), "%t", "RandomRank");
	hMenu.AddItem(NULL_STRING, szBuffer);

	for (int i = 0; i < sizeof(g_sRanks); ++i)
	{
		hMenu.AddItem(NULL_STRING, g_sRanks[i]);
	}

	hMenu.ExitBackButton = true;
	hMenu.ExitButton = true;
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int Handler_FakeRankMenu(Menu hMenu, MenuAction action, int iClient, int iItem)
{
	switch(action)
	{
		case MenuAction_End: delete hMenu;
		case MenuAction_Cancel:
		{
			if(iItem == MenuCancel_ExitBack)
			{
				VIP_SendClientVIPMenu(iClient);
			}
		}
		case MenuAction_Select:
		{
			char	szRank[2];
			szRank[0] = view_as<char>(g_iVipFakeRanks[iClient] = iItem);
			SetClientCookie(iClient, g_hCookie, szRank);
			OnItemSelect(iClient, NULL_STRING);
			
			if (!iItem)
			{
				PrintToChat(iClient, " \x04[ \x02VIP \x04] \x01%t: \x04%t", "SelectedFakeRank", "RandomRank");
			}
			else
			{
				PrintToChat(iClient, " \x04[ \x02VIP \x04] \x01%t: \x04%s", "SelectedFakeRank", g_sRanks[iItem-1]);
			}
		}
	}
}

void Timer_GetRandomInt()
{
	g_iRandomRank = GetRandomInt(1, 18);
}
#endif

public void FPS_OnFPSStatsLoaded()
{
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (FPS_ClientLoaded(i))
		{
			GetPlayerData(i, FPS_GetLevel(i));
		}
	}
}

public void OnMapStart()
{
	SDKHook(FindEntityByClassname(-1, "cs_player_manager"), SDKHook_ThinkPost, OnThinkPost);
}

public void OnThinkPost(int iEntity)
{
	for (int i = 1; i <= MaxClients; ++i)
	{
		if(FPS_ClientLoaded(i))
		{
			#if VIP_SUPPORT == 1
				SetEntData(iEntity, m_iCompetitiveRanking + i * 4, g_iVipStatus[i] != 1 ? g_iPlayerRanks[i] : (g_iVipFakeRanks[i] ? g_iVipFakeRanks[i] : g_iRandomRank));
			#else
				SetEntData(iEntity, m_iCompetitiveRanking + i * 4, g_iPlayerRanks[i]);
			#endif
		}
	}
}

public void FPS_OnClientLoaded(int iClient, float fPoints)
{
	GetPlayerData(iClient, FPS_GetLevel(iClient));
}

public void FPS_OnLevelChange(int iClient, int iOldLevel, int iNewLevel)
{
	GetPlayerData(iClient, iNewLevel);
}

void GetPlayerData(int iClient, int iLevel)
{
	g_iPlayerRanks[iClient] = !FPS_IsCalibration(iClient) ? iLevel : 0;
}

public void OnPlayerRunCmdPost(int iClient, int iButtons)
{
	static int iOldButtons[MAXPLAYERS+1];

	if(iButtons & IN_SCORE && !(iOldButtons[iClient] & IN_SCORE))
	{
		StartMessageOne("ServerRankRevealAll", iClient, USERMSG_BLOCKHOOKS);
		EndMessage();
	}

	iOldButtons[iClient] = iButtons;
}
