// Conf vars
int			g_iServerID,
			g_iRanksID,
			g_iMinPlayers,
			g_iResetStatsTime,
			g_iDeletePlayersTime,
			g_iCalibrationFixTime,
			g_iSaveInterval,
			g_iInfoMessage;
bool		g_bShowStatsEveryone,
			g_bBlockStatsOnWarmup,
			g_bIgnoreNewPlayers;
float		g_fDBRetryConnTime,
			g_fCoeff,
			g_fExtraPoints[18];
char		g_sPrefix[64];

enum
{
	CFG_HEADSHOT = 0,
	CFG_ASSIST,
	CFG_SUICIDE,
	CFG_TEAMKILL,
	CFG_WIN_ROUND,
	CFG_LOSE_ROUND,
	CFG_MVP_PLAYER,
	CFG_BOMB_PLANTED,
	CFG_BOMB_DEFUSED,
	CFG_BOMB_DROPPED,
	CFG_BOMB_PICK_UP,
	CFG_HOSTAGE_KILLED,
	CFG_HOSTAGE_RESCUED,
}

void LoadConfigKV()
{
	if (g_hWeaponsConfigKV)
	{
		delete g_hWeaponsConfigKV;
	}

	char szPath[256];
	g_hWeaponsConfigKV = new KeyValues("Config");
	BuildPath(Path_SM, SZF(szPath), "configs/FirePlayersStats/settings.ini");
	if(!g_hWeaponsConfigKV.ImportFromFile(szPath))
	{
		SetFailState("No found file: '%s'.", szPath);
	}

	g_hWeaponsConfigKV.Rewind();
	if (g_hWeaponsConfigKV.JumpToKey("ExtraPoints") && g_hWeaponsConfigKV.GotoFirstSubKey(false))
	{
		int i;
		do {
			g_fExtraPoints[i] = g_hWeaponsConfigKV.GetFloat(NULL_STRING, 0.0);
			#if DEBUG >= 3
				static char szBuffer[32];
				g_hWeaponsConfigKV.GetSectionName(SZF(szBuffer));
				FPS_Debug(3, "LoadConfigKV", "%s #%i: %f", szBuffer, i, g_fExtraPoints[i]);
			#endif
			i++;
		} while (g_hWeaponsConfigKV.GotoNextKey(false));
	}
}

void GetMapExtraPoints()
{
	g_hWeaponExtraPoints.Clear();

	if (g_hWeaponsConfigKV)
	{
		g_hWeaponsConfigKV.Rewind();
		if (!g_hWeaponsConfigKV.JumpToKey("WeaponCoeff"))
		{
			LogError("Section 'WeaponCoeff' not found!");
			return;
		}

		WriteExtraPointsToArray("default");
		if (g_sMap[0])
		{
			WriteExtraPointsToArray(g_sMap);
		}
	}
}

void WriteExtraPointsToArray(const char[] szSection)
{
	FPS_Debug(2, "WriteExtraPointsToArray", "Try jump to '%s'", szSection);
	if (g_hWeaponsConfigKV.JumpToKey(szSection) && g_hWeaponsConfigKV.GotoFirstSubKey(false))
	{
		char szWeapon[32];
		do {
			float fPoints = g_hWeaponsConfigKV.GetFloat(NULL_STRING, 0.0);
			if (fPoints)
			{
				g_hWeaponsConfigKV.GetSectionName(SZF(szWeapon));
				g_hWeaponExtraPoints.SetValue(szWeapon, fPoints, true);
				FPS_Debug(2, "WriteExtraPointsToArray", "%s -> %f", szWeapon, fPoints);
			}
		} while (g_hWeaponsConfigKV.GotoNextKey(false));

		g_hWeaponsConfigKV.GoBack();
		g_hWeaponsConfigKV.GoBack();
	}
}

void SetCvars()
{
	ConVar Convar;
	(Convar = CreateConVar(
		"sm_fps_db_lost_conn_retry_time",	"15", 
		"Через сколько секунд повторить попытку коннекта к БД, если соединение будет потеряно?", 
		_, true, 5.0, true, 120.0
	)).AddChangeHook(ChangeCvar_DBRetryConnTime);
	ChangeCvar_DBRetryConnTime(Convar, NULL_STRING, NULL_STRING);

	(Convar = CreateConVar(
		"sm_fps_server_id",					"1", 
		"ID сервера. Позволит использовать одну БД для многих серверов",
		_, true, 0.0
	)).AddChangeHook(ChangeCvar_ServerID);
	ChangeCvar_ServerID(Convar, NULL_STRING, NULL_STRING);

	(Convar = CreateConVar(
		"sm_fps_ranks_id",					"1", 
		"ID настройки рангов. \
		\nПозволит использовать одну и туже настройку рангов для некоторых серверов, \
		\nпри этом можно сделать уникальную для других серверов",
		_, true, 0.0
	)).AddChangeHook(ChangeCvar_RanksID);
	ChangeCvar_RanksID(Convar, NULL_STRING, NULL_STRING);

	(Convar = CreateConVar(
		"sm_fps_min_players",				"4", 
		"Минимальное количество игроков для работы статистики", 
		_, true, 2.0
	)).AddChangeHook(ChangeCvar_MinPlayers);
	ChangeCvar_MinPlayers(Convar, NULL_STRING, NULL_STRING);

	(Convar = CreateConVar(
		"sm_fps_reset_stats_time",			"90000", 
		"Минимальное наиграное время в секундах, через которое можно обнулить статистику (0 - Выключить возможность обнуления)", 
		_, true, 0.0
	)).AddChangeHook(ChangeCvar_ResetStatsTime);
	ChangeCvar_ResetStatsTime(Convar, NULL_STRING, NULL_STRING);

	Convar = CreateConVar(
		"sm_fps_reset_modules_stats",		"0", 
		"Разрешить модулям дополнительной статистики обнулять только свои данные, независимо от основной статистики", 
		_, true, 0.0, true, 1.0
	);

	(Convar = CreateConVar(
		"sm_fps_show_stats_everyone",		"1", 
		"Показывать статистику игрока всем при использовании команд просмотра позиции (sm_pos) (1 - Да / 0 - Нет)", 
		_, true, 0.0, true, 1.0
	)).AddChangeHook(ChangeCvar_ShowStatsEveryone);
	ChangeCvar_ShowStatsEveryone(Convar, NULL_STRING, NULL_STRING);

	(Convar = CreateConVar(
		"sm_fps_block_stats_on_warmup",		"1", 
		"Блокировать работу статистики на разминке (1 - Да / 0 - Нет)", 
		_, true, 0.0, true, 1.0
	)).AddChangeHook(ChangeCvar_BlockStatsOnWarmup);
	ChangeCvar_BlockStatsOnWarmup(Convar, NULL_STRING, NULL_STRING);

	(Convar = CreateConVar(
		"sm_fps_clean_players_time",		"30", 
		"Через сколько дней удалить данные игрока. 0 - Отключить"
	)).AddChangeHook(ChangeCvar_DeletePlayersTime);
	ChangeCvar_DeletePlayersTime(Convar, NULL_STRING, NULL_STRING);

	(Convar = CreateConVar(
		"sm_fps_poins_coeff",	"1.0", 
		"Коэффициент расчета очков.\
		\n1.9 - Игрок теряет на 90% больше, чем получает за него убийца \
		\n1.0 - Игрок теряет столько же очков опыта, сколько получает убийца \
		\n0.1 - Игрок теряет только 10% очков опыта, чем получает за него убийца", 
		_, true, 0.1, true, 1.9
	)).AddChangeHook(ChangeCvar_EloCoeff);
	ChangeCvar_EloCoeff(Convar, NULL_STRING, NULL_STRING);

	(Convar = CreateConVar(
		"sm_fps_calibration_time",	"1800", 
		"Время калибровки игрока. Снижает ущерб полученным всем, кого убил калибрующийся, \
		\nесли присутствует значительная разница в поинтах, в течение времени в сек. 0 - Отключить.", 
		_, true, 0.0, true, 3600.0
	)).AddChangeHook(ChangeCvar_CalibrationFix);
	ChangeCvar_CalibrationFix(Convar, NULL_STRING, NULL_STRING);

	(Convar = CreateConVar(
		"sm_fps_save_period",	"5", 
		"Интервал раундов сохранения статистики. 1 - каждый раунд, 2 - каждый второй раунд, ... \
		Если режим сервера DM - будет использоваться как время в мин. для сохранения статистики. \
		0 - Сохранение будет производится только при отключении игрока.", 
		_, true, 0.0, true, 10.0
	)).AddChangeHook(ChangeCvar_SaveInterval);
	ChangeCvar_SaveInterval(Convar, NULL_STRING, NULL_STRING);

	(Convar = CreateConVar(
		"sm_fps_chat_prefix",	"{GREEN}[ {RED}FPS {GREEN}] {DEFAULT}", 
		"Префикс в чате. Поддерживает '{GREEN}' и т.д."
	)).AddChangeHook(ChangeCvar_ChatPrefix);
	ChangeCvar_ChatPrefix(Convar, NULL_STRING, NULL_STRING);

	(Convar = CreateConVar(
		"sm_fps_info_message",	"1", 
		"Уведомление от статистики об итогах получаемых поинтов. \
		\n0 - Выключить \
		\n1 - Уведомление в конце раунда \
		\n2 - Уведомление при каждой смерти",
		_, true, 0.0, true, 2.0
	)).AddChangeHook(ChangeCvar_InfoMessage);
	ChangeCvar_InfoMessage(Convar, NULL_STRING, NULL_STRING);

	(Convar = CreateConVar(
		"sm_fps_ignore_new_players",	"1", 
		"Не выводить неоткалиброванных игроков в списки ТОП-ов. 0 - Отключить",
		_, true, 0.0, true, 1.0
	)).AddChangeHook(ChangeCvar_IgnoreNewPlayers);
	ChangeCvar_IgnoreNewPlayers(Convar, NULL_STRING, NULL_STRING);

	AutoExecConfig(true, "FirePlayersStats");

	LoadConfigKV();
}

void ChangeCvar_DBRetryConnTime(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	g_fDBRetryConnTime = Convar.FloatValue;
}

void ChangeCvar_ServerID(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	g_iServerID = Convar.IntValue;
}

void ChangeCvar_RanksID(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	g_iRanksID = Convar.IntValue;
}

void ChangeCvar_MinPlayers(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	g_iMinPlayers = Convar.IntValue;
}

void ChangeCvar_ResetStatsTime(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	g_iResetStatsTime = Convar.IntValue;
}

void ChangeCvar_ShowStatsEveryone(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	g_bShowStatsEveryone = Convar.BoolValue;
}

void ChangeCvar_BlockStatsOnWarmup(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	g_bBlockStatsOnWarmup = Convar.BoolValue;
}

void ChangeCvar_DeletePlayersTime(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	g_iDeletePlayersTime = Convar.IntValue * 86400;
}

void ChangeCvar_EloCoeff(ConVar Convar, const char[] oldValue, const char[] newValue)
{	
	g_fCoeff = Convar.FloatValue;
}

void ChangeCvar_CalibrationFix(ConVar Convar, const char[] oldValue, const char[] newValue)
{	
	g_iCalibrationFixTime = Convar.IntValue;
}

void ChangeCvar_SaveInterval(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	g_iSaveInterval = Convar.IntValue;
}

void ChangeCvar_ChatPrefix(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	Convar.GetString(g_sPrefix, sizeof(g_sPrefix));
}

void ChangeCvar_InfoMessage(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	g_iInfoMessage = Convar.IntValue;
}

void ChangeCvar_IgnoreNewPlayers(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	g_bIgnoreNewPlayers = Convar.BoolValue;
}
