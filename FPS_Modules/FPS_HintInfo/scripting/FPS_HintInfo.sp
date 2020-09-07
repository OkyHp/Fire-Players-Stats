/**
 *	v1.1.4 -	Fixed display of information of the previous player.
 *	v1.1.5 -	Update to new API version.
 *				Player LVL changed to KDR.
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <clientprefs>
#include <FirePlayersStats>
#include <FPS_HintInfo>

#undef REQUIRE_PLUGIN
#include <mapchooser>

int		g_iHintType,
		g_iPlayerPosition[MAXPLAYERS+1],
		g_iPlayersCount,
		m_iObserverMode,
		m_hObserverTarget;
bool	g_bHintState[MAXPLAYERS+1],
		g_bMapChooser;
float	g_fPlayerPoints[MAXPLAYERS+1];
char	g_sPlayerRank[MAXPLAYERS+1][64];
Handle	g_hCookie;

static const char g_sFeature[] = "FPS_HintInfo";

public Plugin myinfo =
{
	name	=	"[FPS] Hint Info",
	author	=	"OkyHp",
	version	=	"1.1.5",
	url		=	"Discord: OkyHek#2441"
};

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] szError, int iErr_max)
{
	if(GetEngineVersion() != Engine_CSGO)
	{
		strcopy(szError, iErr_max, "This plugin works only on CS:GO!");
		return APLRes_SilentFailure;
	}

	CreateNative("FPS_HintInfo_GetState", Native_FPSHintInfo_GetState);
	CreateNative("FPS_HintInfo_SetState", Native_FPSHintInfo_SetState);
	RegPluginLibrary("FPS_HintInfo");
	return APLRes_Success;
}

// bool FPS_HintInfo_GetState(int iClient);
public int Native_FPSHintInfo_GetState(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	return (iClient > 0 && iClient <= MaxClients && g_bHintState[iClient]);
}

// void FPS_HintInfo_SetState(int iClient, bool bState);
public int Native_FPSHintInfo_SetState(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	if(iClient > 0 && iClient <= MaxClients)
	{
		g_bHintState[iClient] = GetNativeCell(2);
	}
}

public void OnPluginStart()
{
	m_iObserverMode = FindSendPropInfo("CBasePlayer", "m_iObserverMode");
	m_hObserverTarget = FindSendPropInfo("CBasePlayer", "m_hObserverTarget");

	g_hCookie = RegClientCookie("FPS_HintStatus", "FPS Hint Status", CookieAccess_Private);

	LoadTranslations("FPS_HintInfo.phrases");

	char szPath[256];
	BuildPath(Path_SM, SZF(szPath), "translations/FirePlayersStatsRanks.phrases.txt");
	if (FileExists(szPath, false, NULL_STRING))
	{
		LoadTranslations("FirePlayersStatsRanks.phrases");
	}

	if (FPS_StatsLoad())
	{
		FPS_OnFPSStatsLoaded();
	}

	AddCommandListener(UpdateSpec, "spec_player");

	ConVar Convar;
	(Convar = CreateConVar(
		"sm_fps_hint_type",	"1", 
		"Тип работы плагина. \n0 - Постоянно отображать информацию в хинте. \n1 - Отобразить информацию один раз, при переключении на игрока.", 
		_, true, 0.0, true, 1.0
	)).AddChangeHook(ChangeCvar_HintType);
	ChangeCvar_HintType(Convar, NULL_STRING, NULL_STRING);

	AutoExecConfig(true, "FPS_HintInfo");

	RegConsoleCmd("sm_fps_hint", CommandHintStatus);
}

void ChangeCvar_HintType(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	g_iHintType = Convar.IntValue;
}

void SetLibState(const char[] szName, bool bValue)
{
	if (!strcmp(szName, "mapchooser"))
	{
		g_bMapChooser = bValue;
	}
}

public void OnLibraryAdded(const char[] szName)
{
	SetLibState(szName, true);
}

public void OnLibraryRemoved(const char[] szName)
{
	SetLibState(szName, false);
}

public void OnMapStart()
{
	if (!g_iHintType)
	{
		CreateTimer(3.5, TimerUpdateHint, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public void OnClientCookiesCached(int iClient)
{
	if (IsClientSourceTV(iClient))
	{
		g_bHintState[iClient] = false;
		return;
	}

	char szBuffer[4];
	GetClientCookie(iClient, g_hCookie, SZF(szBuffer));
	g_bHintState[iClient] = szBuffer[0] ? view_as<bool>(StringToInt(szBuffer)) : true;
}

public Action CommandHintStatus(int iClient, int iArgs)
{
	if (FPS_ClientLoaded(iClient))
	{
		HintStatus(iClient);
		FPS_PrintToChat(iClient, "%t", "ChangeHintStatusChat", g_bHintState[iClient] ? "EnabledChat" : "DisabledChat");
	}
	return Plugin_Handled;
}

void HintStatus(int iClient)
{
	g_bHintState[iClient] = !g_bHintState[iClient];
	SetClientCookie(iClient, g_hCookie, g_bHintState[iClient] ? "1" : "0");
}

public void FPS_OnFPSStatsLoaded()
{
	FPS_AddFeature(g_sFeature, FPS_ADVANCED_MENU, OnItemSelect, OnItemDisplay);

	for (int i = 1; i <= MaxClients; ++i)
	{
		if (FPS_ClientLoaded(i))
		{
			FPS_OnClientLoaded(i, FPS_GetPoints(i));
		}
	}
}

public void OnPluginEnd()
{
	if (CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "FPS_RemoveFeature") == FeatureStatus_Available)
	{
		FPS_RemoveFeature(g_sFeature);
	}
}

public bool OnItemSelect(int iClient)
{
	HintStatus(iClient);
	return true;
}

public bool OnItemDisplay(int iClient, char[] szDisplay, int iMaxLength)
{
	FormatEx(szDisplay, iMaxLength, "%T", "ChangeHintStatusMenu", iClient, g_bHintState[iClient] ? "Enabled" : "Disabled");
	return true;
}

public void FPS_OnClientLoaded(int iClient, float fPoints)
{
	g_fPlayerPoints[iClient] = fPoints;
	GetPlayerLevel(iClient);
}

public void FPS_OnPointsChange(int iAttacker, int iVictim, float fPointsAttacker, float fPointsVictim)
{
	g_fPlayerPoints[iAttacker] = fPointsAttacker;
	g_fPlayerPoints[iVictim] = fPointsVictim;
}

public void FPS_OnLevelChange(int iClient, int iOldLevel, int iNewLevel)
{
	GetPlayerLevel(iClient);
}

public void FPS_OnPlayerPosition(int iClient, int iPosition, int iPlayersCount)
{
	g_iPlayerPosition[iClient] = iPosition;
	g_iPlayersCount = iPlayersCount;
}

void GetPlayerLevel(int iClient)
{
	FPS_GetRanks(iClient, g_sPlayerRank[iClient], sizeof(g_sPlayerRank[]));
}

void SendHintMessage(int iClient)
{
	if (g_bMapChooser && !CanMapChooserStartVote())
	{
		return;
	}

	if (FPS_ClientLoaded(iClient) && g_bHintState[iClient] && GetEntData(iClient, m_iObserverMode) != 6)
	{
		static int iTarget;
		iTarget = GetEntDataEnt2(iClient, m_hObserverTarget);
		if (iTarget > 0 && iTarget <= MaxClients && FPS_ClientLoaded(iTarget))
		{
			int iDeaths = FPS_GetStatsData(iTarget, DEATHS);
			PrintHintText(iClient, "%t", "HudMessage", 
				g_fPlayerPoints[iTarget], 
				g_iPlayerPosition[iTarget], g_iPlayersCount, 
				iDeaths ? (float(FPS_GetStatsData(iTarget, KILLS)) / float(iDeaths)) : 0.0, 
				FindTranslationRank(iClient, g_sPlayerRank[iTarget])
			);
		}
	}
}

Action UpdateSpec(int iClient, const char[] szCommand, int iArg)
{
	if (iClient)
	{
		RequestFrame(UpdateSpecNext, GetClientUserId(iClient));
	}
	return Plugin_Continue;
}

void UpdateSpecNext(any iUserID)
{
	int iClient = GetClientOfUserId(iUserID);
	if (iClient)
	{
		SendHintMessage(iClient);
	}
}

Action TimerUpdateHint(Handle hTimer)
{
	for (int i = MaxClients + 1; --i;)
	{
		SendHintMessage(i);
	}
	return Plugin_Continue;
}
