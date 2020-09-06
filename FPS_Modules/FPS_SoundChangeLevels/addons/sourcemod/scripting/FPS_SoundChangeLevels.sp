#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <FirePlayersStats>

char g_sSounds[2][256];

#define LVL_UP		0
#define LVL_DOWN	1

public Plugin myinfo =
{
	name	=	"[FPS] Sound Change Levels",
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

	ConVar Convar;
	(Convar = CreateConVar(
		"sm_fpsm_sound_up",		"fps/level_up.mp3", 
		"Звук воспроизводимый при повышении уровня без папки sound"
	)).AddChangeHook(ChangeCvar_SoundUp);
	ChangeCvar_SoundUp(Convar, NULL_STRING, NULL_STRING);

	(Convar = CreateConVar(
		"sm_fpsm_sound_down",	"fps/level_down.mp3", 
		"Звук воспроизводимый при понижении уровня без папки sound"
	)).AddChangeHook(ChangeCvar_SoundDown);
	ChangeCvar_SoundDown(Convar, NULL_STRING, NULL_STRING);

	AutoExecConfig(true, "FPS_SoundChangeLevels");
}

public void ChangeCvar_SoundUp(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	Convar.GetString(g_sSounds[LVL_UP], sizeof(g_sSounds[]));
}

public void ChangeCvar_SoundDown(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	Convar.GetString(g_sSounds[LVL_DOWN], sizeof(g_sSounds[]));
}

public void OnMapStart()
{
	for (int i = 0; i < sizeof(g_sSounds); ++i)
	{
		char szBuffer[256];
		FormatEx(szBuffer, sizeof(szBuffer), "sound/%s", g_sSounds[i]);
		AddFileToDownloadsTable(szBuffer);
	}
}

public void FPS_OnLevelChange(int iClient, int iOldLevel, int iNewLevel)
{
	char szBuffer[256];
	FormatEx(szBuffer, sizeof(szBuffer), "playgamesound *%s", iNewLevel > iOldLevel ? g_sSounds[LVL_UP] : g_sSounds[LVL_DOWN]);
	ClientCommand(iClient, szBuffer);
}
