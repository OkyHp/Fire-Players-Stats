#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <vip_core>
#include <FirePlayersStats>

public Plugin myinfo = 
{
	name = "[FPS] Vip Boost",
	author = "Designed (Discord: .Designed#7985)",
	version = "1.0.0",
}

static const char g_szFeature[] = "StatsBoost";

public void OnPluginStart() 
{
	if(GetEngineVersion() != Engine_CSGO)
	{
		SetFailState("This plugin works only on CS:GO");
	}

	if(VIP_IsVIPLoaded())
	{
		VIP_OnVIPLoaded();
	}
}

public void VIP_OnVIPLoaded()
{
	VIP_RegisterFeature(g_szFeature, FLOAT, HIDE);
}

public Action FPS_OnPointsChangePre(int iAttacker, int iVictim, Event hEvent, float &fAddPointsAttacker, float &fAddPointsVictim)
{
	if(VIP_IsClientVIP(iAttacker) && VIP_IsClientFeatureUse(iAttacker, g_szFeature))
	{
		fAddPointsAttacker *= VIP_GetClientFeatureFloat(iAttacker, g_szFeature);
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public void OnPluginEnd() 
{
	if(CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "VIP_UnregisterFeature") == FeatureStatus_Available)
	{
		VIP_UnregisterFeature(g_szFeature);
	}
}
