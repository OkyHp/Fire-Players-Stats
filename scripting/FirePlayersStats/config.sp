// Conf vars
int			g_iServerID,
			g_iRanksID,
			g_iMinPlayers,
			g_iResetStatsTime,
			g_iDeletePlayersTime,
			g_iCalibrationFixTime,
			g_iSaveInterval;
bool		g_bShowStatsEveryone,
			g_bBlockStatsOnWarmup;
float		g_fDBRetryConnTime,
			g_fCoeff,
			g_fExtraPoints[18];
char		g_sPrefix[32];
KeyValues	g_hWeaponsConfigKV;

#define	CFG_HEADSHOT			0
#define	CFG_ASSIST				1
#define	CFG_SUICIDE				2
#define	CFG_TEAMKILL			3
#define	CFG_WIN_ROUND			4
#define	CFG_LOSE_ROUND			5
#define	CFG_MVP_PLAYER			6
#define	CFG_BOMB_PLANTED		7
#define	CFG_BOMB_DEFUSED		8
#define	CFG_BOMB_DROPPED		9
#define	CFG_BOMB_PICK_UP		10
#define	CFG_HOSTAGE_KILLED		11
#define	CFG_HOSTAGE_RESCUED		12

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
			#if DEBUG == 1
				static char szBuffer[32];
				g_hWeaponsConfigKV.GetSectionName(SZF(szBuffer));
				FPS_Debug("LoadConfigKV >> %s #%i: %f", szBuffer, i, g_fExtraPoints[i])
			#endif
			i++;
		} while (g_hWeaponsConfigKV.GotoNextKey(false));
	}
}

void SetCvars()
{
	ConVar Convar;
	(Convar = CreateConVar(
		"sm_fps_db_lost_conn_retry_time",	"15", 
		"Через сколько секунд повторить попытку коннекта к БД", 
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
		"ID настройки рангов. Позволит использовать одну и туже настройку \
		\nрангов для некоторых серверов, при этом можно сделать уникальную для других",
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
		"Минимальное наиграное время в секундах, через которое можно \
		\nобнулить статистику (0 - Выключить возможность обнуления)", 
		_, true, 0.0
	)).AddChangeHook(ChangeCvar_ResetStatsTime);
	ChangeCvar_ResetStatsTime(Convar, NULL_STRING, NULL_STRING);

	(Convar = CreateConVar(
		"sm_fps_show_stats_everyone",		"1", 
		"Показывать статиститку игрока всем при использовании команд \
		\nпросмотра позиции (sm_pos) (1 - Да / 0 - Нет)", 
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
		"sm_fps_clean_players_time",		"14", 
		"Через сколько дней удалить данные игрока", 
		_, true, 7.0, true, 90.0
	)).AddChangeHook(ChangeCvar_DeletePlayersTime);
	ChangeCvar_DeletePlayersTime(Convar, NULL_STRING, NULL_STRING);

	(Convar = CreateConVar(
		"sm_fps_poins_coeff",	"1.0", 
		"Коэффициент расчета очков.\
		\n1.9 - Игрок теряет на 90% больше, чем получает за него убийца \
		\n1.0 - Игрок теряет столько же очков опыта, сколько получает убийца \
		\n0.1 - Игрок теряет только 10% очков опыта от реального значения", 
		_, true, 0.1, true, 1.9
	)).AddChangeHook(ChangeCvar_EloCoeff);
	ChangeCvar_EloCoeff(Convar, NULL_STRING, NULL_STRING);

	(Convar = CreateConVar(
		"sm_fps_calibration_time",	"1800", 
		"Время калибровки игрока. Снижает ущерб всем кого убил калибрующийся \
		\nв течение времени в сек, если доля делимых очек менее 0.5. 0 - Отключить.", 
		_, true, 0.0, true, 7200.0
	)).AddChangeHook(ChangeCvar_CalibrationFix);
	ChangeCvar_CalibrationFix(Convar, NULL_STRING, NULL_STRING);

	(Convar = CreateConVar(
		"sm_fps_save_period",	"5", 
		"Интервал раундов сохранения статистики. 1 - каждый раунд, 2 - каждый второй, ... \
		Если mp_randomspawn 1 - будет использоваться как время в мин. для сохранения статистики.", 
		_, true, 1.0, true, 10.0
	)).AddChangeHook(ChangeCvar_SaveInterval);
	ChangeCvar_SaveInterval(Convar, NULL_STRING, NULL_STRING);

	(Convar = CreateConVar(
		"sm_fps_chat_prefix",	"\x04[ \x02FPS \x04] \x01", 
		"Префикс в чате. Поддерживает '{GREEN}' и т.д."
	)).AddChangeHook(ChangeCvar_SaveInterval);
	ChangeCvar_ChatPrefix(Convar, NULL_STRING, NULL_STRING);

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
	g_iDeletePlayersTime = Convar.IntValue * 24 * 60 * 60;
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
