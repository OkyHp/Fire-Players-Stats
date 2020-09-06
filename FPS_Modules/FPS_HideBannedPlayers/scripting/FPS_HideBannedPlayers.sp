#include <sourcemod>
#include <FirePlayersStats>

#undef REQUIRE_PLUGIN
#include <materialadmin>
#include <sourcebanspp>

#pragma semicolon 1
#pragma newdecls required

Database g_hDatabase;

public Plugin myinfo =
{
	name	=	"[FPS] Hide Banned Players",
	author	=	"OkyHp",
	version	=	"1.0.0",
	url		=	"OkyHek#2441"
};

public void OnPluginStart()
{
	if (FPS_StatsLoad())
	{
		FPS_OnDatabaseConnected();
	}
}

public void FPS_OnDatabaseConnected()
{
	g_hDatabase = FPS_GetDatabase();
}

public void FPS_OnDatabaseLostConnection()
{
	if (g_hDatabase)
	{
		delete g_hDatabase;
	}
}

public void MAOnClientBanned(int iClient, int iTarget, char[] sIp, char[] sSteamID, char[] sName, int iTime, char[] sReason)
{
	if (iTarget)
	{
		UpdatePlayerData(iTarget);
	}
}

public void SBPP_OnBanPlayer(int iAdmin, int iTarget, int iTime, const char[] sReason)
{
	UpdatePlayerData(iTarget);
}

void UpdatePlayerData(int iClient)
{
	if (g_hDatabase)
	{
		int iAccountID = GetSteamAccountID(iClient, true);
		if (iAccountID)
		{
			CreateTimer(1.0, TimerUpdatePlayerData, iAccountID);
		}
	}
}

Action TimerUpdatePlayerData(Handle hTimer, int iAccountID)
{
	char szQuery[512];
	g_hDatabase.Format(SZF(szQuery), "UPDATE `fps_servers_stats` SET `lastconnect` = -1 WHERE `server_id` = %i AND `account_id` = %u;", 
		FPS_GetID(FPS_SERVER_ID), iAccountID);
	g_hDatabase.Query(SQL_UpdatePlayerData_Callback, szQuery);

	return Plugin_Stop;
}

void SQL_UpdatePlayerData_Callback(Database hDatabase, DBResultSet hResult, const char[] szError, any aData)
{
	if (!hResult || szError[0])
	{
		LogError("SQL_UpdatePlayerData_Callback: %s", szError);
	}
}
