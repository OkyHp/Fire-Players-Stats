#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <FirePlayersStats>

float		g_flExp[2];

public Plugin myinfo =
{
	name	=	"[FPS] Exp Mode",
	author	=	"OkyHp",
	version	=	"1.0.1",
	url		=	"OkyHek#2441"
};

public void OnPluginStart()
{
	ConVar Convar;

	(Convar = CreateConVar(
		"sm_fps_exp_mode_kill", "5.0", "Количество выдаваемых поинтов игроку при убийстве",
		_, true, 0.0
	)).AddChangeHook(ChangeCvar_ExpKill);
	ChangeCvar_ExpKill(Convar, NULL_STRING, NULL_STRING);

	(Convar = CreateConVar(
		"sm_fps_exp_mode_death", "5.0", "Количество забераемых поинтов у игрока при смерти",
		_, true, 0.0
	)).AddChangeHook(ChangeCvar_ExpDeath);
	ChangeCvar_ExpDeath(Convar, NULL_STRING, NULL_STRING);

	AutoExecConfig(true, "FPS_ExpMode");
}

public void ChangeCvar_ExpKill(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	g_flExp[0] = Convar.FloatValue;
}

public void ChangeCvar_ExpDeath(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	g_flExp[1] = Convar.FloatValue;
}

public Action FPS_OnPointsChangePre(int iAttacker, int iVictim, Event hEvent, float &fAddPointsAttacker, float &fAddPointsVictim)
{
	fAddPointsAttacker = g_flExp[0];
	fAddPointsVictim = g_flExp[1];

	return Plugin_Changed;
}
