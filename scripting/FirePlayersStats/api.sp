// Forvards
static Handle	g_hGlobalForvard_OnFPSStatsLoaded,
				g_hGlobalForvard_OnFPSDatabaseConnected,
				g_hGlobalForvard_OnFPSDatabaseLostConnection,
				g_hGlobalForvard_OnFPSClientLoaded,
				g_hGlobalForvard_OnFPSPointsChangePre,
				g_hGlobalForvard_OnFPSPointsChange,
				g_hGlobalForvard_OnFPSPlayerPosition,
				g_hGlobalForvard_OnFPSSecondDataUpdated,
				g_hGlobalForvard_OnFPSLevelChange;

// For print natives
#define CSGO_COL_COUNT		16
static char g_sCsgoColorsBuff[2048];
static const char g_sColorsT[CSGO_COL_COUNT][] = {
	"{DEFAULT}", "{RED}", "{LIGHTPURPLE}", "{GREEN}", 
	"{LIME}", "{LIGHTGREEN}", "{LIGHTRED}", "{GRAY}", 
	"{LIGHTOLIVE}", "{OLIVE}", "{LIGHTBLUE}", "{BLUE}", 
	"{PURPLE}", "{GRAYBLUE}", "{PINK}", "{BRIGHTRED}"
};
static const char g_sColorsC[CSGO_COL_COUNT][] = {
	"\x01", "\x02", "\x03", "\x04", 
	"\x05", "\x06", "\x07", "\x08", 
	"\x09", "\x10", "\x0B", "\x0C", 
	"\x0E", "\x0A", "\x0E", "\x0F"
};

void CreateGlobalForwards()
{
	g_hGlobalForvard_OnFPSStatsLoaded				= CreateGlobalForward("FPS_OnFPSStatsLoaded",			ET_Ignore);
	g_hGlobalForvard_OnFPSDatabaseConnected			= CreateGlobalForward("FPS_OnDatabaseConnected",		ET_Ignore,	Param_Cell);
	g_hGlobalForvard_OnFPSDatabaseLostConnection	= CreateGlobalForward("FPS_OnDatabaseLostConnection",	ET_Ignore);
	g_hGlobalForvard_OnFPSClientLoaded				= CreateGlobalForward("FPS_OnClientLoaded",				ET_Ignore,	Param_Cell, Param_Cell);
	g_hGlobalForvard_OnFPSPointsChangePre			= CreateGlobalForward("FPS_OnPointsChangePre",			ET_Hook,	Param_Cell, Param_Cell, Param_Cell, Param_FloatByRef, Param_FloatByRef);
	g_hGlobalForvard_OnFPSPointsChange				= CreateGlobalForward("FPS_OnPointsChange",				ET_Ignore,	Param_Cell, Param_Cell, Param_Float, Param_Float);
	g_hGlobalForvard_OnFPSPlayerPosition			= CreateGlobalForward("FPS_PlayerPosition",				ET_Ignore,	Param_Cell, Param_Cell, Param_Cell);
	g_hGlobalForvard_OnFPSSecondDataUpdated			= CreateGlobalForward("FPS_OnSecondDataUpdated",		ET_Ignore);
	g_hGlobalForvard_OnFPSLevelChange				= CreateGlobalForward("FPS_OnLevelChange",				ET_Ignore,	Param_Cell, Param_Cell, Param_Cell);
}

void CallForward_OnFPSStatsLoaded()
{
	Call_StartForward(g_hGlobalForvard_OnFPSStatsLoaded);
	Call_Finish();
}

void CallForward_OnFPSDatabaseConnected()
{
	Call_StartForward(g_hGlobalForvard_OnFPSDatabaseConnected);
	Call_PushCell(g_hDatabase);
	Call_Finish();
}

void CallForward_OnFPSDatabaseLostConnection()
{
	Call_StartForward(g_hGlobalForvard_OnFPSDatabaseLostConnection);
	Call_Finish();
}

void CallForward_OnFPSClientLoaded(int iClient, float fPoints)
{
	Call_StartForward(g_hGlobalForvard_OnFPSClientLoaded);
	Call_PushCell(iClient);
	Call_PushCell(fPoints);
	Call_Finish();
}

Action CallForward_OnFPSPointsChangePre(int iAttacker, int iVictim, Event hEvent, float& fAddPointsAttacker, float& fAddPointsVictim)
{
	Action Result = Plugin_Continue;
	Call_StartForward(g_hGlobalForvard_OnFPSPointsChangePre);
	Call_PushCell(iAttacker);
	Call_PushCell(iVictim);
	Call_PushCell(hEvent);
	Call_PushFloatRef(fAddPointsAttacker);
	Call_PushFloatRef(fAddPointsVictim);
	Call_Finish(Result);
	return Result;
}

void CallForward_OnFPSPointsChange(int iAttacker, int iVictim, float fPointsAttacker, float fPointsVictim)
{
	Call_StartForward(g_hGlobalForvard_OnFPSPointsChange);
	Call_PushCell(iAttacker);
	Call_PushCell(iVictim);
	Call_PushFloat(fPointsAttacker);
	Call_PushFloat(fPointsVictim);
	Call_Finish();
}

void CallForward_OnFPSLevelChange(int iClient, int iOldLevel, int iNewLevel)
{
	Call_StartForward(g_hGlobalForvard_OnFPSLevelChange);
	Call_PushCell(iClient);
	Call_PushCell(iOldLevel);
	Call_PushCell(iNewLevel);
	Call_Finish();
}

void CallForward_OnFPSPlayerPosition(int iClient, int iPosition, int iPlayersCount)
{
	Call_StartForward(g_hGlobalForvard_OnFPSPlayerPosition);
	Call_PushCell(iClient);
	Call_PushCell(iPosition);
	Call_PushCell(iPlayersCount);
	Call_Finish();
}

void CallForward_OnFPSSecondDataUpdated()
{
	Call_StartForward(g_hGlobalForvard_OnFPSSecondDataUpdated);
	Call_Finish();
}

// Natives
public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] szError, int iErr_max)
{
	if(GetEngineVersion() != Engine_CSGO)
	{
		strcopy(szError, iErr_max, "This plugin works only on CS:GO!");
		return APLRes_SilentFailure;
	}

	// General
	CreateNative("FPS_StatsLoad",				Native_FPS_StatsLoad);
	CreateNative("FPS_GetDatabase",				Native_FPS_GetDatabase);
	CreateNative("FPS_GetID",					Native_FPS_GetID);
	CreateNative("FPS_ClientLoaded",			Native_FPS_ClientLoad);
	CreateNative("FPS_ClientReloadData",		Native_FPS_ClientReloadData);
	CreateNative("FPS_DisableStatisPerRound",	Native_FPS_DisableStatisPerRound);
	CreateNative("FPS_StatsActive",				Native_FPS_StatsActive);

	// Stats
	CreateNative("FPS_GetPlayedTime",			Native_FPS_GetPlayedTime);
	CreateNative("FPS_GetPoints",				Native_FPS_GetPoints);
	CreateNative("FPS_GetStatsData",			Native_FPS_GetStatsData);
	CreateNative("FPS_IsCalibration",			Native_FPS_IsCalibration);

	// Menu
	CreateNative("FPS_AddFeature",				Native_FPS_AddFeature);
	CreateNative("FPS_RemoveFeature",			Native_FPS_RemoveFeature);
	CreateNative("FPS_IsExistFeature",			Native_FPS_IsExistFeature);
	CreateNative("FPS_MoveToMenu",				Native_FPS_MoveToMenu);

	// Ranks
	CreateNative("FPS_GetLevel",				Native_FPS_GetLevel);
	CreateNative("FPS_GetRanks",				Native_FPS_GetRanks);
	CreateNative("FPS_GetMaxRanks",				Native_FPS_GetMaxRanks);

	// Chat
	CreateNative("FPS_PrintToChat",				Native_FPS_PrintToChat);
	CreateNative("FPS_PrintToChatAll",			Native_FPS_PrintToChatAll);

	RegPluginLibrary("FirePlayersStats");
	
	return APLRes_Success;
}

bool IsValidClient(int iClient)
{
	if (iClient < 1 || iClient > MaxClients)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "[FPS] Invalid client index '%i'.", iClient);
		return false;
	}
	return true;
}

// bool FPS_StatsLoad();
int Native_FPS_StatsLoad(Handle hPlugin, int iNumParams)
{
	return g_bStatsLoaded;
}

// Database FPS_GetDatabase();
int Native_FPS_GetDatabase(Handle hPlugin, int iNumParams)
{
	return g_hDatabase ? view_as<int>(CloneHandle(g_hDatabase, hPlugin)) : 0;
}

// bool FPS_ClientLoaded(int iClient);
int Native_FPS_ClientLoad(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	return (IsValidClient(iClient) && g_bStatsLoad[iClient]);
}

// void FPS_ClientReloadData(int iClient);
int Native_FPS_ClientReloadData(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	if (IsValidClient(iClient) && g_bStatsLoad[iClient])
	{
		FPS_Debug("Native_FPS_ClientReloadData >> LoadStats: %N", iClient)
		SavePlayerData(iClient);
		OnClientDisconnect(iClient);
		LoadPlayerData(iClient);
	}
}

// void FPS_DisableStatisPerRound();
int Native_FPS_DisableStatisPerRound(Handle hPlugin, int iNumParams)
{
	g_bDisableStatisPerRound = true;
}

// int FPS_GetPlayedTime(int iClient);
int Native_FPS_GetPlayedTime(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	if (IsValidClient(iClient) && g_bStatsLoad[iClient] && g_iPlayerSessionData[iClient][PLAYTIME])
	{
		return (GetTime() - g_iPlayerSessionData[iClient][PLAYTIME]) + g_iPlayerData[iClient][PLAYTIME];
	}
	return 0;
}

// float FPS_GetPoints(int iClient, bool bSession = false);
int Native_FPS_GetPoints(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	return view_as<int>(IsValidClient(iClient) && g_bStatsLoad[iClient] ? (!GetNativeCell(2) ? g_fPlayerPoints[iClient] : (g_fPlayerPoints[iClient] - g_fPlayerSessionPoints[iClient])) : DEFAULT_POINTS);
}

// int FPS_GetLevel(int iClient);
int Native_FPS_GetLevel(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	if (IsValidClient(iClient) && g_bStatsLoad[iClient])
	{
		return g_iPlayerRanks[iClient];
	}
	return 0;
}

// void FPS_GetRanks(int iClient, char[] szBufferRank, int iMaxLength);
int Native_FPS_GetRanks(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	if (IsValidClient(iClient) && g_bStatsLoad[iClient])
	{
		SetNativeString(2, g_sRankName[iClient], GetNativeCell(3), true);
	}
}

// int FPS_GetMaxRanks();
int Native_FPS_GetMaxRanks(Handle hPlugin, int iNumParams)
{
	return g_iRanksCount;
}

// int FPS_GetStatsData(int iClient, StatsData eData, bool bSession = false);
int Native_FPS_GetStatsData(Handle hPlugin, int iNumParams)
{
	int	iClient	= GetNativeCell(1),
		iData	= GetNativeCell(2);
	if (iData < 0 || iData > 6)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "[FPS] Invalid data type index '%i'.", iData);
		return 0;
	}

	if (IsValidClient(iClient) && g_bStatsLoad[iClient])
	{
		return GetNativeCell(3) ? g_iPlayerData[iClient][iData] : g_iPlayerSessionData[iClient][iData];
	}
	return 0;
}

// bool FPS_IsCalibration(int iClient);
int Native_FPS_IsCalibration(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	return (IsValidClient(iClient) && g_bStatsLoad[iClient] && FPS_GetPlayedTime(iClient) < g_iCalibrationFixTime);
}

// void FPS_AddFeature(const char[]				szFeature,
// 							FeatureMenus			eType,
// 							ItemSelectCallback		OnItemSelect	= INVALID_FUNCTION,
// 							ItemDisplayCallback		OnItemDisplay	= INVALID_FUNCTION,
// 							ItemDrawCallback		OnItemDraw		= INVALID_FUNCTION);
int Native_FPS_AddFeature(Handle hPlugin, int iNumParams)
{
	char szFeature[128];
	GetNativeString(1, SZF(szFeature));
	if(szFeature[0])
	{
		if(g_hItems.FindString(szFeature) == -1)
		{
			g_hItems.PushString(szFeature);
			g_hItems.Push(GetNativeCell(2));
			g_hItems.Push(hPlugin);
			g_hItems.Push(GetNativeCell(3));
			g_hItems.Push(GetNativeCell(4));
			g_hItems.Push(GetNativeCell(5));
			return 0;
		}

		ThrowNativeError(SP_ERROR_NATIVE, "[FPS] Feature '%s' already exists.", szFeature);
	}
	else
	{
		ThrowNativeError(SP_ERROR_NATIVE, "[FPS] Empty feature name.");
	}

	return 0;
}

// void FPS_RemoveFeature(const char[] szFeature);
int Native_FPS_RemoveFeature(Handle hPlugin, int iNumParams)
{
	char szFeature[128];
	GetNativeString(1, SZF(szFeature));
	if (szFeature[0])
	{
		int iIndex = g_hItems.FindString(szFeature);
		if(iIndex != -1)
		{
			for (int i = 0; i < F_COUNT; ++i)
			{
				g_hItems.Erase(iIndex);
			}
			return 0;
		}
		
		ThrowNativeError(SP_ERROR_NATIVE, "[FPS] Feature '%s' not found.", szFeature);
	}
	else
	{
		ThrowNativeError(SP_ERROR_NATIVE, "[FPS] Empty feature name.");
	}
	return 0;
}

// bool FPS_IsExistFeature(const char[] szFeature);
int Native_FPS_IsExistFeature(Handle hPlugin, int iNumParams)
{
	char szFeature[128];
	GetNativeString(1, SZF(szFeature));
	if (szFeature[0])
	{
		return (g_hItems.FindString(szFeature) != -1);
	}

	ThrowNativeError(SP_ERROR_NATIVE, "[FPS] Empty feature name.");
	return 0;
}

// void FPS_MoveToMenu(int iClient, FeatureMenus eType, int iPage = 0);
int Native_FPS_MoveToMenu(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	if (IsValidClient(iClient) && g_bStatsLoad[iClient])
	{
		switch(GetNativeCell(2))
		{
			case -1:				ShowFpsMenu(iClient);
			case FPS_STATS_MENU:	ShowMainStatsMenu(iClient,		GetNativeCell(3));
			case FPS_TOP_MENU:		ShowMainTopMenu(iClient,		GetNativeCell(3));
			case FPS_ADVANCED_MENU:	ShowMainAdditionalMenu(iClient,	GetNativeCell(3));
			default: ThrowNativeError(SP_ERROR_NATIVE, "[FPS] Invalid FeatureMenus type!");
		}
	}
}

// bool FPS_StatsActive();
int Native_FPS_StatsActive(Handle hPlugin, int iNumParams)
{
	return g_bStatsActive;
}

// int FPS_GetID(StatsID eType)
int Native_FPS_GetID(Handle hPlugin, int iNumParams)
{
	switch(GetNativeCell(1))
	{
		case FPS_SERVER_ID:	return g_iServerID;
		case FPS_RANK_ID:	return g_iRanksID;
		default: ThrowNativeError(SP_ERROR_NATIVE, "[FPS] Invalid StatsID type!");
	}
	return 0;
}

// void FPS_PrintToChat(int iClient, const char[] szMessage, any ...)
int Native_FPS_PrintToChat(Handle hPlugin, int iNumParams)
{
	int	iClient	= GetNativeCell(1);
	if (IsValidClient(iClient) && g_bStatsLoad[iClient])
	{
		SetGlobalTransTarget(iClient);
		FormatNativeString(0, 2, 3, sizeof(g_sCsgoColorsBuff), _, g_sCsgoColorsBuff);
		Format(SZF(g_sCsgoColorsBuff), " %s%s", g_sPrefix, g_sCsgoColorsBuff);
		
		int iLastStart = 0, i = 0;
		for(; i < CSGO_COL_COUNT; i++)
		{
			ReplaceString(g_sCsgoColorsBuff, sizeof g_sCsgoColorsBuff, g_sColorsT[i], g_sColorsC[i], false);
		}
		
		i = 0;
		
		while(g_sCsgoColorsBuff[i])
		{
			if(g_sCsgoColorsBuff[i] == '\n')
			{
				g_sCsgoColorsBuff[i] = 0;
				PrintToChat(iClient, g_sCsgoColorsBuff[iLastStart]);
				iLastStart = i+1;
			}
			
			i++;
		}
		
		PrintToChat(iClient, g_sCsgoColorsBuff[iLastStart]);
	}
}

// void FPS_PrintToChatAll(const char[] szMessage, any ...)
int Native_FPS_PrintToChatAll(Handle hPlugin, int iNumParams)
{
	int iLastStart = 0, i = 0;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++) if(IsValidClient(iClient) && g_bStatsLoad[iClient])
	{
		SetGlobalTransTarget(iClient);
		FormatNativeString(0, 1, 2, sizeof(g_sCsgoColorsBuff), _, g_sCsgoColorsBuff);
		Format(SZF(g_sCsgoColorsBuff), " %s%s", g_sPrefix, g_sCsgoColorsBuff);
		
		for(i = 0; i < CSGO_COL_COUNT; i++)
		{
			ReplaceString(g_sCsgoColorsBuff, sizeof g_sCsgoColorsBuff, g_sColorsT[i], g_sColorsC[i], false);
		}
		
		iLastStart = 0, i = 0;
		
		while(g_sCsgoColorsBuff[i])
		{
			if(g_sCsgoColorsBuff[i] == '\n')
			{
				g_sCsgoColorsBuff[i] = 0;
				PrintToChat(iClient, g_sCsgoColorsBuff[iLastStart]);
				iLastStart = i+1;
			}
			
			i++;
		}
		
		PrintToChat(iClient, g_sCsgoColorsBuff[iLastStart]);
	}
}
