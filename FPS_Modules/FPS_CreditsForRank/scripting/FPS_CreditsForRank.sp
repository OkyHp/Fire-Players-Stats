#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <clientprefs>
#include <FirePlayersStats>
#include <shop>

public Plugin myinfo =
{
	name	=	"FPS Credits For Rank",
	author	=	"OkyHp",
	version	=	"1.0.1",
	url		=	"https://dev-source.ru/, https://hlmod.ru/"
};

int			g_iLastRank[MAXPLAYERS+1];
Handle		g_hCookie;
KeyValues	g_hConfig;

public void OnPluginStart()
{
	if(GetEngineVersion() != Engine_CSGO)
	{
		SetFailState("This plugin works only on CS:GO");
	}

	g_hCookie = RegClientCookie("FPS_CreditsForRank", "FPS Shop For Rank - Player last rank", CookieAccess_Private);

	LoadTranslations("FPS_CreditsForRank.phrases");

	LoadConfig();

	RegAdminCmd("sm_fps_sfr_reload", CommandConfigReload, ADMFLAG_ROOT);
}

public Action CommandConfigReload(int iClient, int iArgs)
{
	LoadConfig();
	return Plugin_Handled;
}

public void OnClientCookiesCached(int iClient)
{
	char szBuffer[4];
	GetClientCookie(iClient, g_hCookie, SZF(szBuffer));
	g_iLastRank[iClient] = StringToInt(szBuffer);
}

void LoadConfig()
{
	if (g_hConfig)
	{
		delete g_hConfig;
	}

	char szPath[256];
	g_hConfig = new KeyValues("Config");
	BuildPath(Path_SM, szPath, sizeof(szPath), "configs/FirePlayersStats/credits_for_ranks.ini");
	if(!g_hConfig.ImportFromFile(szPath))
	{
		SetFailState("No found file: '%s'.", szPath);
	}
}

public void FPS_OnLevelChange(int iClient, int iOldLevel, int iNewLevel)
{
	if (g_hConfig && iNewLevel > g_iLastRank[iClient])
	{
		g_iLastRank[iClient] = iNewLevel;

		char szBuffer[4];
		IntToString(g_iLastRank[iClient], SZF(szBuffer));

		int iCredits = g_hConfig.GetNum(szBuffer, 0);
		if (iCredits)
		{
			SetClientCookie(iClient, g_hCookie, szBuffer);

			Shop_GiveClientCredits(iClient, iCredits, IGNORE_FORWARD_HOOK);
			FPS_PrintToChat(iClient, "%t", "BonusMessage", g_iLastRank[iClient]);
		}
	}
}
