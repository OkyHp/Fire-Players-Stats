/**
 *	v1.3.1 -	Optimization of work. Possible load reduced.
 *				Now when deleting key "0" in "custom_ranks" calibration icon will not be set.
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <FirePlayersStats>

#undef REQUIRE_PLUGIN
#include <vip_core>

int			m_iCompetitiveRanking,
			g_iPlayerRanks[MAXPLAYERS+1],
			g_iRanksType,
			g_iVipStatus[MAXPLAYERS+1];
bool		g_bVipLoaded;
KeyValues	g_hConfig;

static int g_iRanksIndex[] = {0, 50, 70, 90, 92, 94, 18, 18, 15};
static char g_sFeature[] = "FakeRanks";

public Plugin myinfo =
{
	name	=	"FPS Tab Fake Ranks",
	author	=	"OkyHp, Wend4r",
	version	=	"1.3.1",
	url		=	"https://blackflash.ru/, https://dev-source.ru/, https://hlmod.ru/"
};

public void OnPluginStart()
{
	if(GetEngineVersion() != Engine_CSGO)
	{
		SetFailState("This plugin works only on CS:GO");
	}

	m_iCompetitiveRanking = FindSendPropInfo("CCSPlayerResource", "m_iCompetitiveRanking");

	HookEvent("round_prestart",			view_as<EventHook>(UpdateRanks), EventHookMode_PostNoCopy);
	HookEvent("player_connect_full",	view_as<EventHook>(UpdateRanks), EventHookMode_PostNoCopy);

	if (FPS_StatsLoad())
	{
		FPS_OnFPSStatsLoaded();
	}
}

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

public void VIP_OnVIPClientLoaded(int iClient)
{
	g_iVipStatus[iClient] = view_as<int>(VIP_GetClientFeatureStatus(iClient, g_sFeature));
}

public void VIP_OnVIPClientAdded(int iClient, int iAdmin)
{
	g_iVipStatus[iClient] = view_as<int>(VIP_GetClientFeatureStatus(iClient, g_sFeature));
}

public void OnClientDisconnect(int iClient)
{
	g_iVipStatus[iClient] = 0;
}

public Action VIP_OnFeatureToggle(int iClient, const char[] szFeature, VIP_ToggleState eOldStatus, VIP_ToggleState &eNewStatus)
{
	if(!strcmp(szFeature, g_sFeature, false)) 
	{
		g_iVipStatus[iClient] = view_as<int>(eNewStatus);
	}
}

public void FPS_OnFPSStatsLoaded()
{
	for (int i = MaxClients + 1; --i;)
	{
		if (FPS_ClientLoaded(i))
		{
			GetPlayerData(i, FPS_GetLevel(i));
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
	if (g_iRanksType > 2 && g_hConfig)
	{
		g_hConfig.Rewind();
		if (g_hConfig.JumpToKey("custom_ranks"))
		{
			if (!FPS_IsCalibration(iClient))
			{
				char szBuffer[4];
				IntToString(iLevel, szBuffer, sizeof(szBuffer));
				g_iPlayerRanks[iClient] = g_hConfig.GetNum(szBuffer);
				return;
			}
			g_iPlayerRanks[iClient] = g_hConfig.GetNum("0", 0);
		}
		return;
	}

	g_iPlayerRanks[iClient] = !FPS_IsCalibration(iClient) ? (iLevel + g_iRanksIndex[g_iRanksType]) : g_iRanksIndex[g_iRanksType + 3];
}

public void OnMapStart()
{
	SDKHook(FindEntityByClassname(-1, "cs_player_manager"), SDKHook_ThinkPost, OnThinkPost);

	if (g_hConfig)
	{
		delete g_hConfig;
	}

	char szPath[256];
	g_hConfig = new KeyValues("Config");
	BuildPath(Path_SM, szPath, sizeof(szPath), "configs/FirePlayersStats/fake_ranks.ini");
	if(!g_hConfig.ImportFromFile(szPath))
	{
		SetFailState("No found file: '%s'.", szPath);
	}

	g_hConfig.Rewind();
	g_iRanksType = g_hConfig.GetNum("ranks_type", 0);

	// Custom download
	if (g_iRanksType > 2)
	{
		if (g_hConfig.JumpToKey("custom_ranks") && g_hConfig.GotoFirstSubKey(false))
		{
			do {
				RanksAddToDownloads(g_hConfig.GetNum(NULL_STRING));
			} while (g_hConfig.GotoNextKey(false));
		}
		return;
	}

	// Default download
	RanksAddToDownloads(g_iRanksIndex[g_iRanksType + 3]);
	if (g_iRanksType)
	{
		int i = g_iRanksIndex[g_iRanksType],
			iMax = g_iRanksIndex[g_iRanksType] + g_iRanksIndex[g_iRanksType + 6] + 1;
		while(i < iMax)
		{
			RanksAddToDownloads(i++);
		}
	}
}

void RanksAddToDownloads(const int iRanks)
{
	char szBuffer[256];
	FormatEx(szBuffer, sizeof(szBuffer), "materials/panorama/images/icons/skillgroups/skillgroup%i.svg", iRanks);
	if(FileExists(szBuffer))
	{
		AddFileToDownloadsTable(szBuffer);
	}
}

public void OnThinkPost(int iEntity)
{
	for (int i = MaxClients + 1; --i;)
	{
		if(FPS_ClientLoaded(i))
		{
			if (g_bVipLoaded && g_iVipStatus[i] == 1)
			{
				continue;
			}
			SetEntData(iEntity, m_iCompetitiveRanking + i * 4, g_iPlayerRanks[i]);
		}
	}
}

void UpdateRanks()
{
	int iPlayersCount,
		iPlayers[MAXPLAYERS+1];
	for (int i = MaxClients + 1; --i;)
	{
		if(FPS_ClientLoaded(i))
		{
			iPlayers[iPlayersCount++] = i;
		}
	}

	StartMessage("ServerRankRevealAll", iPlayers, iPlayersCount, USERMSG_BLOCKHOOKS);
	EndMessage();
}
