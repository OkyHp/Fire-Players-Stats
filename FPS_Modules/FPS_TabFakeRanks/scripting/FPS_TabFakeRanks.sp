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

	int		g_iVipFakeRanks[MAXPLAYERS+1];
	Handle	g_hCookie;
	static const char g_sFeature[][] = {"FakeRanks", "FakeRanksMenu"};
#else
	#define VIP_SUPPORTED	" (VIP not supported)"
#endif

public Plugin myinfo =
{
	name	=	"FPS Tab Fake Ranks" ... VIP_SUPPORTED,
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

	m_iCompetitiveRanking = FindSendPropInfo("CCSPlayerResource", "m_iCompetitiveRanking");

	HookEvent("begin_new_match", Event_GameStart, EventHookMode_PostNoCopy);

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
	#endif
}

#if VIP_SUPPORT == 1
public void OnClientCookiesCached(int iClient)
{
	char szBuffer[4];
	GetClientCookie(iClient, g_hCookie, szBuffer, sizeof(szBuffer));
	g_iPlayerRanks[iClient] = szBuffer[0] ? StringToInt(szBuffer) : 0;
}

public void VIP_OnVIPLoaded()
{
	VIP_RegisterFeature(g_sFeature[0],	BOOL,		TOGGLABLE,	_,				OnDisplayItem);
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
	g_iVipFakeRanks[iClient] = view_as<int>(VIP_GetClientFeatureStatus(iClient, g_sFeature[0]));
}

public Action VIP_OnFeatureToggle(int iClient, const char[] szFeature, VIP_ToggleState eOldStatus, VIP_ToggleState &eNewStatus)
{
	if(!strcmp(szFeature, g_sFeature[0], false)) 
	{
		g_iVipFakeRanks[iClient] = view_as<int>(eNewStatus);
	}
	return Plugin_Continue;
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
		FormatEx(szDisplay, iMaxLength, "%t [%t]", szFeature, szState[g_iVipFakeRanks[iClient]]);
	}
	return true;
}

public int OnItemDraw(int iClient, const char[] szFeature, int iStyle)
{
	switch(g_iVipFakeRanks[iClient])
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
	FormatEx(szBuffer, sizeof(szBuffer), "%t", "StatsRank");
	hMenu.AddItem("0", szBuffer);

	hMenu.AddItem("1", "Silver I");
	hMenu.AddItem("2", "Silver II");
	hMenu.AddItem("3", "Silver III");
	hMenu.AddItem("4", "Silver IV");
	hMenu.AddItem("5", "Silver Elite");
	hMenu.AddItem("6", "Silver Elite Master");
	hMenu.AddItem("7", "Gold Nova I");
	hMenu.AddItem("8", "Gold Nova II");
	hMenu.AddItem("9", "Gold Nova III");
	hMenu.AddItem("10", "Gold Nova Master");
	hMenu.AddItem("11", "Master Guardian I");
	hMenu.AddItem("12", "Master Guardian II");
	hMenu.AddItem("13", "Master Guardian Elite");
	hMenu.AddItem("14", "Distinguished Master Guardian");
	hMenu.AddItem("15", "Legendary Eagle");
	hMenu.AddItem("16", "Legandary Eagle Master");
	hMenu.AddItem("17", "Supreme Master First Class");
	hMenu.AddItem("18", "The Global Elite");

	hMenu.ExitBackButton = true;
	hMenu.ExitButton = true;
	hMenu.Display(iClient, MENU_TIME_FOREVER);
	return false;
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
			g_iPlayerRanks[iClient] = iItem;

			char	szRank[4],
					szRankName[32];
			GetMenuItem(hMenu, iItem, szRank, sizeof(szRank), _, szRankName, sizeof(szRankName));
			SetClientCookie(iClient, g_hCookie, szRank);
			PrintToChat(iClient, " \x04[ \x02VIP \x04] \x01%t: \x04%s", "SelectedFakeRank", szRankName);
			OnItemSelect(iClient, NULL_STRING);
		}
	}
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
	SDKHook(FindEntityByClassname(MaxClients + 1, "cs_player_manager"), SDKHook_ThinkPost, OnThinkPost);
}

public void OnThinkPost(int iEntity)
{
	for (int i = 1; i <= MaxClients; ++i)
	{
		if(FPS_ClientLoaded(i) && !FPS_IsCalibration(i))
		{
			SetEntData(iEntity, m_iCompetitiveRanking + i * 4, g_iPlayerRanks[i]);
		}
	}
}

public void Event_GameStart(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	UpdateFakeRanks();
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
	#if VIP_SUPPORT == 1
		if (!(g_iVipFakeRanks[iClient] == 1 && g_iPlayerRanks[iClient]))
		{
			g_iPlayerRanks[iClient] = iLevel;
		}
	#else
		g_iPlayerRanks[iClient] = iLevel;
	#endif

	UpdateFakeRanks();
}

void UpdateFakeRanks()
{
	CreateTimer(0.5, Timer_UpdateFakeRanks, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_UpdateFakeRanks(Handle hTimer)
{
	if (StartMessageAll("ServerRankRevealAll"))
	{
		EndMessage();
	}
	else
	{
		UpdateFakeRanks();
	}
	return Plugin_Stop;
}
