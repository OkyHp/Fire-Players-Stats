#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <vip_core>
#include <FirePlayersStats>

char	g_sVipGroupe[32];

public Plugin myinfo =
{
	name	=	"FPS Vip For Top",
	author	=	"OkyHp",
	version	=	"1.0.0",
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
		"sm_fpsm_vip_groupe",		"vip", 
		"Звук воспроизводимый при повышении уровня без папки sound"
	)).AddChangeHook(ChangeCvar_VipGroupe);
	ChangeCvar_VipGroupe(Convar, NULL_STRING, NULL_STRING);

	AutoExecConfig(true, "FPS_VipForTop");
}

public void ChangeCvar_VipGroupe(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	Convar.GetString(g_sVipGroupe, sizeof(g_sVipGroupe));
}

public void FPS_PlayerPosition(int iClient, int iPosition, int iPlayersCount)
{
	if (iPosition == 1 && !VIP_IsClientVIP(iClient))
	{
		VIP_GiveClientVIP(-1, iClient, 10800, g_sVipGroupe, false);
	}
}
