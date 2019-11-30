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
	MarkNativeAsOptional("FPS_GetStatsData");
	MarkNativeAsOptional("FPS_IsCalibration");
	MarkNativeAsOptional("FPS_AddFeature");
	MarkNativeAsOptional("FPS_RemoveFeature");
	MarkNativeAsOptional("FPS_IsExistFeature");
	MarkNativeAsOptional("FPS_MoveToMenu");
	MarkNativeAsOptional("FPS_StatsActive");
	MarkNativeAsOptional("FPS_GetID");
}
#endif

#define FPS_INC_VER				15
#define UID(%0)					GetClientUserId(%0)
#define CID(%0)					GetClientOfUserId(%0)
#define SZF(%0)					%0, sizeof(%0)
#define FPS_CHAT_PREFIX			" \x04[ \x02FPS \x04] \x01"
#define FPS_PrintToChat(%0,%1)	FPS_CGOPrintToChat(%0, FPS_CHAT_PREFIX ... %1)
#define FPS_PrintToChatAll(%0)	FPS_CGOPrintToChatAll(FPS_CHAT_PREFIX ... %0)

enum StatsData
{
	KILLS = 0,
	DEATHS,
	ASSISTS,
	MAX_ROUNDS_KILLS,
	ROUND_WIN,
	ROUND_LOSE,
	PLAYTIME
};

enum FeatureMenus
{
	FPS_STATS_MENU = 0,	// Секция меню статистики
	FPS_TOP_MENU,		// Секция меню списка топов
	FPS_ADVANCED_MENU	// Секция дополнительного меню
};

enum StatsID
{
	FPS_SERVER_ID = 0,
	FPS_RANK_ID
};

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
 *	@param hEvent				Хендл события.
 *	@param fAddPointsAttacker	Количество добавляемых поинтов у убийцы.
 *	@param fAddPointsVictim		Количество отнимаемых поинтов у жертвы.
 *	@return						Plugin_Stop или Plugin_Handled  - запретит выдачу опыта (не влияет на статистику по оружию и доп очки!);
 								Plugin_Continue  - разрешит выдачу опыта без изменений;
 								Plugin_Changed - разрешит переключение опыта на fAddPointsAttacker и fAddPointsVictim.

*/
forward Action FPS_OnPointsChangePre(int iAttacker, int iVictim, Event hEvent, float& fAddPointsAttacker, float& fAddPointsVictim);

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
 *	Вызывается после изменения уровня.
 *
 *	@param iClient		Индекс игрока.
 *	@param iOldLevel	Старый уровень игрока.
 *	@param iNewLevel	Новый уровень игрока.
 *	@noreturn
*/
forward void FPS_OnLevelChange(int iClient, int iOldLevel, int iNewLevel);

/**
 *	Вызывается после получения позиции игрока.
 *
 *	@param iClient			Индекс игрока.
 *	@param iPosition		Текущая позиция игрока.
 *	@param iPlayersCount	Всего игроков.
 *	@noreturn
*/
forward void FPS_PlayerPosition(int iClient, int iPosition, int iPlayersCount);

/**
 *	Вызывается при обновлении данных в топе и т.д., после сохранения статистики.
 *
 *	@noparams
 *	@noreturn
*/
forward void FPS_OnSecondDataUpdated();


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
 *  Используйте только после события конца раунда и не позже события начала нового раунда.
 *
 *	@noreturn
*/
native void FPS_DisableStatisPerRound();

/**
 *	Получить количетсво наигранного времени. 
 *
 *	@param iClient		Индекс игрока.
 *	@return				Наигранное время в секундах.
*/
native int FPS_GetPlayedTime(int iClient);

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
 *	Получить данные игрока
 *
 *	@param iClient				Индекс игрока.
 *	@param eData				Тип получаемых данных. Примичание, данные MAX_ROUNDS_KILLS за сессию не 
 								имеет смысла хранить, из-за чего, ядро хранит в нем свои данные!
 *	@param bSession				Получить данные за сессию.
 *	@return						Запрашиваемые данные.
*/
native int FPS_GetStatsData(int iClient, StatsData eData, bool bSession = false);

/**
 *	Получить стату калибровки.
 *
 *	@param iClient		Индекс игрока.
 *	@return				true - Игрок калибруется.
 * 						false - Игрок уже откалиброван.
*/
native bool FPS_IsCalibration(int iClient);

/////////////////////////////////////////////////////////////////////////////////

/**
 *	Вызывается, при нажатии пункта.
 *
 *	@param iClient			Индекс игрока.
 *	@return					true - Вернет обратно в секцию.
*/
typedef FPS_ItemSelectCallback		= function bool (int iClient);

/**
 *	Вызывается, при отображении пункта.
 *
 *	@param iClient			Индекс игрока.
 *	@param szDisplay		Буфер с названием пункта.
 *	@param iMaxLength		Размер буфера.
 *	@return					true - Установит новое название с szDisplay.
*/
typedef FPS_ItemDisplayCallback		= function bool (int iClient, char[] szDisplay, int iMaxLength);

/**
 *	Вызывается, при обращении к пункту.
 *
 *	@param iClient			Индекс игрока.
 *	@param iStyle			Текущий стиль пункта.
 *	@return					Новый стиль для пункта (ITEMDRAW_DEFAULT, ITEMDRAW_DISABLED, ITEMDRAW_RAWLINE).
*/
typedef FPS_ItemDrawCallback		= function int (int iClient, int iStyle);

/**
 *	Добавляет новую функцию
 *
 *	@param szFeature		Название функции.
 *	@param eType			Секция меню для добавления.
 *	@param OnItemSelect		Обратный вызов при нажатии пункта.
 *	@param OnItemDisplay	Обратный вызов при отображении пункта.
 *	@param OnItemDraw		Обратный вызов при обращении к пункту.
 *	@noreturn
*/
native void FPS_AddFeature(const char[]					szFeature,
							FeatureMenus				eType,
							FPS_ItemSelectCallback		OnItemSelect	= INVALID_FUNCTION,
							FPS_ItemDisplayCallback		OnItemDisplay	= INVALID_FUNCTION,
							FPS_ItemDrawCallback		OnItemDraw		= INVALID_FUNCTION);

/**
 *	Удаляет функцию
 *
 *	@param szFeature		Название функции.
 *	@noreturn
*/
native void FPS_RemoveFeature(const char[] szFeature);

/**
 *	Получает статус функции
 *
 *	@param szFeature		Название функции.
 *	@return					true - Существует.
 * 							false - Не существует.
*/
native bool FPS_IsExistFeature(const char[] szFeature);

/**
 *	Открывает секцию статистики
 *
 *	@param iClient			Индекс игрока.
 *	@param eType			Секция меню. -1 - Откроет главное меню статистики (Относится толкьо к этому нативу!).
 *	@param iPage			Страница меню для открытия (GetMenuSelectionPosition()).
 *	@noreturn
*/
native void FPS_MoveToMenu(int iClient, FeatureMenus eType, int iPage = 0);

/**
 *	Получает статус, работает ли статистика (Ведет сбор данных и начисляет ли поинты).
 *
 *	@return					true - Работает.
 * 							false - Отключена в данный момент.
*/
native bool FPS_StatsActive();

/**
 *	Получает ID.
 *
 *	@param eType			Тип получаемого ID.
 *	@return					ID.
*/
native int FPS_GetID(StatsID eType);

/////////////////////////////////////////////////////////////////////////////////

// Find translation rank
stock char[] FindTranslationRank(int iClient, char[] szRank = NULL_STRING)
{
	static char szRankName[128];
	
	if (!szRank[0])
	{
		FPS_GetRanks(iClient, SZF(szRankName));
	}
	else
	{
		strcopy(SZF(szRankName), szRank);
	}
	
	if (TranslationPhraseExists(szRankName))
	{
		Format(SZF(szRankName), "%T", szRankName, iClient);
	}

	return szRankName;
}

// Taken from CS:GO COLORS by Феникс(komashchenko)

#define CSGO_COL_COUNT		14
static char g_sCsgoColorsBuff[2048];

static const char g_sColorsT[CSGO_COL_COUNT][] = {
	"{DEFAULT}", "{RED}", "{LIGHTPURPLE}", "{GREEN}", "{LIME}", 
	"{LIGHTGREEN}", "{LIGHTRED}", "{GRAY}", "{LIGHTOLIVE}", "{OLIVE}", 
	"{LIGHTBLUE}", "{BLUE}", "{PURPLE}", "{GRAYBLUE}"
};
static const char g_sColorsC[CSGO_COL_COUNT][] = {
	"\x01", "\x02", "\x03", "\x04", "\x05", 
	"\x06", "\x07", "\x08", "\x09", "\x10", 
	"\x0B", "\x0C", "\x0E", "\x0A"
};


stock void FPS_CGOPrintToChat(int iClient, const char[] message, any ...)
{
	SetGlobalTransTarget(iClient);
	VFormat(g_sCsgoColorsBuff, sizeof g_sCsgoColorsBuff, message, 3);
	
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
			PrintToChat(iClient, " %s", g_sCsgoColorsBuff[iLastStart]);
			iLastStart = i+1;
		}
		
		i++;
	}
	
	PrintToChat(iClient, " %s", g_sCsgoColorsBuff[iLastStart]);
}

stock void FPS_CGOPrintToChatAll(const char[] message, any ...)
{
	int iLastStart = 0, i = 0;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++) if(IsClientInGame(iClient) && !IsFakeClient(iClient))
	{
		SetGlobalTransTarget(iClient);
		VFormat(g_sCsgoColorsBuff, sizeof g_sCsgoColorsBuff, message, 2);
		
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
				PrintToChat(iClient, " %s", g_sCsgoColorsBuff[iLastStart]);
				iLastStart = i+1;
			}
			
			i++;
		}
		
		PrintToChat(iClient, " %s", g_sCsgoColorsBuff[iLastStart]);
	}
}
