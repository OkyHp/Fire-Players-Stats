#if defined _fire_players_stats_included
 #endinput
#endif
#define _fire_players_stats_included

public SharedPlugin __pl_fire_players_stats= 
{
	name = "FirePlayersStats",
	file = "FirePlayersStats.smx",
	#if defined REQUIRE_PLUGIN
		required = 1
	#else
		required = 0
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_fire_players_stats_SetNTVOptional()
{
	MarkNativeAsOptional("FPS_StatsLoad");
	MarkNativeAsOptional("FPS_GetDatabase");
	MarkNativeAsOptional("FPS_ClientLoaded");
	MarkNativeAsOptional("FPS_ClientReloadData");
	MarkNativeAsOptional("FPS_DisableStatisPerRound");
	MarkNativeAsOptional("FPS_GetPlayedTime");
	MarkNativeAsOptional("FPS_GetPoints");
	MarkNativeAsOptional("FPS_GetLevel");
	MarkNativeAsOptional("FPS_GetRanks");
	MarkNativeAsOptional("FPS_GetMaxRanks");
	MarkNativeAsOptional("FPS_GetSessionData");
}
#endif

#define FPS_INC_VER		2


/****************** FORWARDS ******************/

/**
 *	Вызывается когда ядро/статистика загрузилась.
 *
 *	@noparams
 *	@noreturn
 */
forward void FPS_OnFPSStatsLoaded();

/**
 *	Вызывается когда было установлено сеединение с БД.
 *
 *	@param hDatabase	Хендл базы данных.
 *	@noreturn
 */
forward void FPS_OnDatabaseConnected(Database hDatabase);

/**
 *	Вызывается когда сеединение с БД было разорвано.
 *
 *	@noparams
 *	@noreturn
 */
forward void FPS_OnDatabaseLostConnection();

/**
 *	Вызывается когда данные игрока были загружены.
 *
 *	@param iClient		Индекс игрока.
 *	@param fPoints		Количество поинтов у игрока.
 *	@noreturn
 */
forward void FPS_OnClientLoaded(int iClient, float fPoints);

/**
 *	Вызывается перед установкой поинтов игроку.
 *
 *	@param iAttacker			Индекс убийцы.
 *	@param iVictim				Индекс жертвы.
 *	@param bHeadshot			Было ли убиство в голову.
 *	@param fAddPointsAttacker	Количество добавляемых поинтов у убийцы.
 *	@param fAddPointsVictim		Количество отнимаемых поинтов у жертвы.
 *	@return						Plugin_Stop или Plugin_Handled  - запретит выдачу опыта (не влияет на статистику по оружию и доп очки!);
 								Plugin_Continue  - разрешит выдачу опыта без изменений;
 								Plugin_Changed - разрешит переключение опыта на fAddPointsAttacker и fAddPointsVictim.

 */
forward Action FPS_OnPointsChangePre(int iAttacker, int iVictim, bool bHeadshot, float& fAddPointsAttacker, float& fAddPointsVictim);

/**
 *	Вызывается после установкой поинтов игроку.
 *
 *	@param iAttacker			Индекс убийцы.
 *	@param iVictim				Индекс жертвы.
 *	@param fPointsAttacker		Количество поинтов у убийцы (общее).
 *	@param fPointsVictim		Количество поинтов у жертвы (общее).
 *	@noreturn
 */
forward void FPS_OnPointsChange(int iAttacker, int iVictim, float fPointsAttacker, float fPointsVictim);

/**
 *	Вызывается после установкой поинтов игроку.
 *
 *	@param iClient		Индекс игрока.
 *	@param iOldLevel	Старый уровень игрока.
 *	@param iNewLevel	Новый уровень игрока.
 *	@noreturn
 */
forward void FPS_OnLevelChange(int iClient, int iOldLevel, int iNewLevel);


/****************** NATIVES ******************/

/**
 *	Получает статус ядра/статистики
 *
 *	@noparams
 *	@return				true - Загружено.
 * 						false - Не загружено.
 */
native bool FPS_StatsLoad();

/**
 *	Получает Handle базы данных. После работы необходимо закрыть с помощью CloseHandle() или delete.
 *
 *	@noparams
 *	@return				Хендл базы данных.
 */
native Database FPS_GetDatabase();

/**
 *	Получение статуса игрока.
 *
 *	@param iClient		Индекс игрока.
 *	@return				true - Данные игрока загружены.
 * 						false - Данные игрока не загружены.
 */
native bool FPS_ClientLoaded(int iClient);

/**
 *	Перезагрузить данные игрока.
 *
 *	@param iClient		Индекс игрока.
 *	@noreturn
 */
native void FPS_ClientReloadData(int iClient);

/**
 *	Отключить работу статистики на 1 раунд.
 *
 *	@noreturn
 */
native void FPS_DisableStatisPerRound();

/**
 *	Получить количетсво наигранного времени. 
 *
 *	@param iClient		Индекс игрока.
 *	@param bSession		Вывод наигранного времени за текущую сессию.
 *	@return				Наигранное время в секундах.
 */
native int FPS_GetPlayedTime(int iClient, bool bSession = false);

/**
 *	Получить количетсво поинтов/очков у игрока.
 *
 *	@param iClient		Индекс игрока.
 *	@param bSession		Количетсво поинтов за текущую сессию.
 *	@return				Количетсво поинтов/очков у игрока.
 */
native float FPS_GetPoints(int iClient, bool bSession = false);

/**
 *	Получить текущий уровень/ранг.
 *
 *	@param iClient				Индекс игрока.
 *	@return						Текущий ранг.
 */
native int FPS_GetLevel(int iClient);

/**
 *	Получить текущий ранг и/или название ранга.
 *
 *	@param iClient				Индекс игрока.
 *	@param szBufferLevelName	Буфер для записи названия ранга.
 *	@param iMaxLength			Максимальный размер буфера.
 *	@noreturn
 */
native void FPS_GetRanks(int iClient, char[] szBufferRank, int iMaxLength);

/**
 *	Получить количетсво всех рангов. Получает значение при старте карты.
 *
 *	@return						Количетсво всех рангов.
 */
native int FPS_GetMaxRanks();

/**
 *	Получить данные игрока за сессию.
 *
 *	@param iClient				Индекс игрока.
 *	@param iData				Индекс ячейки с данными:
 *								0 - Убиства.
 *								1 - Смерти.
 *								2 - Фссисты.
 *								4 - Количесво выиграных раундов.
 *								5 - Количесво проиграных раундов.
 *								6 - Время подключение игрока.
 *	@return
 */
native int FPS_GetSessionData(int iClient, int iData);
