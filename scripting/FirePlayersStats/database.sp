void DatabaseConnect()
{
	FPS_Debug("DatabaseConnect >> %s", !g_hDatabase ? "Connect database" : "Error! Handle is valid")
	
	if (!g_hDatabase)
	{
		static const char szSection[] = "fire_players_stats";
		if (SQL_CheckConfig(szSection))
		{
			Database.Connect(OnDatabaseConnect, szSection);
			return;
		}

		SetFailState("DatabaseConnect: Section \"%s\" not found in \"/addons/sourcemod/configs/database.cfg\". Use only MySQL!", szSection);
	}
}

Action Timer_DatabaseRetryConn(Handle hTimer)
{
	DatabaseConnect();
	return Plugin_Stop;
}

bool CheckDatabaseConnection(const char[] szErrorTag, const char[] szError, Handle hResult = view_as<Handle>(1))
{
	if (!hResult || szError[0])
	{
		LogError("%s: %s", szErrorTag, szError);
		if (StrContains(szError, "Lost connection to MySQL", false) != -1)
		{
			FPS_Debug("%s >> Lost connection to MySQL", szErrorTag)

			delete g_hDatabase;
			CallForward_OnFPSDatabaseLostConnection();
			CreateTimer(g_fDBRetryConnTime, Timer_DatabaseRetryConn, _, TIMER_FLAG_NO_MAPCHANGE);
		}
		return false;
	}
	return true;
}

void OnDatabaseConnect(Database hDatabase, const char[] szError, any Data)
{
	if (!hDatabase || szError[0])
	{
		LogError("OnDatabaseConnect: %s", szError);
		if (StrContains(szError, "Can't connect to MySQL server", false) != -1)
		{
			FPS_Debug("OnDatabaseConnect >> Can't connect to MySQL server")
			CreateTimer(g_fDBRetryConnTime, Timer_DatabaseRetryConn, _, TIMER_FLAG_NO_MAPCHANGE);
		}
		return;
	}

	FPS_Debug("OnDatabaseConnect >> Database connected")

	g_hDatabase = hDatabase;
	CallForward_OnFPSDatabaseConnected();

	static bool bFirstConnect;
	if (!bFirstConnect)
	{
		bFirstConnect = true;

		Transaction hTxn = new Transaction();
		hTxn.AddQuery("CREATE TABLE IF NOT EXISTS `fps_players` ( \
				`account_id`	int				NOT NULL, \
				`steam_id`		varchar(64)		NOT NULL, \
				`nickname`		varchar(256)	NOT NULL, \
				`ip`			varchar(24)		NOT NULL, \
				PRIMARY KEY (`account_id`) \
			) ENGINE = InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;");
		hTxn.AddQuery("CREATE TABLE IF NOT EXISTS `fps_servers_stats` ( \
				`id`				int 		NOT NULL AUTO_INCREMENT, \
				`account_id`		int			NOT NULL, \
				`server_id`			int			NOT NULL, \
				`points`			float		UNSIGNED NOT NULL, \
				`rank`				int			NOT NULL DEFAULT '0', \
				`kills`				int			NOT NULL DEFAULT '0', \
				`deaths`			int			NOT NULL DEFAULT '0', \
				`assists`			int			NOT NULL DEFAULT '0', \
				`round_max_kills`	int			NOT NULL DEFAULT '0', \
				`round_win`			int			NOT NULL DEFAULT '0', \
				`round_lose`		int			NOT NULL DEFAULT '0', \
				`playtime`			int			NOT NULL DEFAULT '0', \
				`lastconnect`		int			NOT NULL DEFAULT '0', \
				PRIMARY KEY (`id`), \
				UNIQUE(`account_id`, `server_id`) \
			) ENGINE = InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;");
		hTxn.AddQuery("CREATE TABLE IF NOT EXISTS `fps_weapons_stats` ( \
				`id`				int 			NOT NULL AUTO_INCREMENT, \
				`account_id`		int				NOT NULL, \
				`server_id`			int				NOT NULL, \
				`weapon`			varchar(64)		NOT NULL, \
				`kills`				int				NOT NULL DEFAULT '0', \
				`shoots`			int				NOT NULL DEFAULT '0', \
				`hits_head`			int				NOT NULL DEFAULT '0', \
				`hits_neck`			int				NOT NULL DEFAULT '0', \
				`hits_chest`		int				NOT NULL DEFAULT '0', \
				`hits_stomach`		int				NOT NULL DEFAULT '0', \
				`hits_left_arm`		int				NOT NULL DEFAULT '0', \
				`hits_right_arm`	int				NOT NULL DEFAULT '0', \
				`hits_left_leg`		int				NOT NULL DEFAULT '0', \
				`hits_right_leg`	int				NOT NULL DEFAULT '0', \
				`headshots`			int				NOT NULL DEFAULT '0', \
				PRIMARY KEY (`id`), \
				UNIQUE(`account_id`, `server_id`, `weapon`) \
			) ENGINE = InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;");
		hTxn.AddQuery("CREATE TABLE IF NOT EXISTS `fps_servers` ( \
				`id`					int 			NOT NULL, \
				`server_name`			varchar(256)	NOT NULL, \
				`settings_rank_id`		int 			NOT NULL, \
				`settings_points_id`	int 			NOT NULL, \
				`server_ip`				varchar(32)		NOT NULL, \
				PRIMARY KEY (`id`) \
			) ENGINE = InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;");
		hTxn.AddQuery("CREATE TABLE IF NOT EXISTS `fps_ranks` ( \
				`id`			int 			NOT NULL AUTO_INCREMENT, \
				`rank_id`		int 			NOT NULL, \
				`rank_name`		varchar(128)	NOT NULL, \
				`points`		float			UNSIGNED NOT NULL, \
				PRIMARY KEY (`id`) \
			) ENGINE = InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;");
		g_hDatabase.Execute(hTxn, SQL_TxnSuccess_CreateTable, SQL_TxnFailure_CreateTable);

		LoadTopData();
		LoadRanksSettings();

		for (int i = MaxClients + 1; --i;)
		{
			if (IsClientInGame(i) && !IsFakeClient(i) && !IsClientSourceTV(i))
			{
				OnClientDisconnect(i);
				LoadPlayerData(i);
			}
		}
	}
}

void SQL_Default_Callback(Database hDatabase, DBResultSet hResult, const char[] szError, any QueryID)
{
	char szBuffer[128];
	FormatEx(SZF(szBuffer), "SQL_Default_Callback #%i", QueryID);
	CheckDatabaseConnection(szBuffer, szError, hResult);
}

void SQL_TxnSuccess_CreateTable(Database hDatabase, any Data, int iNumQueries, DBResultSet[] results, any[] QueryData)
{
	if (g_hDatabase)
	{
		g_hDatabase.Query(SQL_Default_Callback, "SET NAMES 'utf8mb4'", 1);
		g_hDatabase.Query(SQL_Default_Callback, "SET CHARSET 'utf8mb4'", 2);
		g_hDatabase.SetCharset("utf8mb4");
	}
}

void SQL_TxnFailure_CreateTable(Database hDatabase, any Data, int iNumQueries, const char[] szError, int iFailIndex, any[] QueryData)
{
	SetFailState("SQL_TxnFailure_CreateTable #%i: %s", iFailIndex, szError);
}

Action CommandCreateRanks(int iClient, int iArgs) 
{ 
	if (g_hDatabase)
	{
		char	szQuery[1024],
				szArg[2];
		GetCmdArg(1, SZF(szArg));

		switch(szArg[0])
		{
			case '0':
			{
				g_hDatabase.Format(SZF(szQuery), "INSERT INTO `fps_ranks` (`rank_id`, `rank_name`, `points`) \
					VALUES \
						(%i, 'Silver I',						'0'), \
						(%i, 'Silver II',						'700'), \
						(%i, 'Silver III',						'800'), \
						(%i, 'Silver IV',						'850'), \
						(%i, 'Silver Elite',					'900'), \
						(%i, 'Silver Elite Master',				'925'), \
						(%i, 'Gold Nova I',						'950'), \
						(%i, 'Gold Nova II',					'975'), \
						(%i, 'Gold Nova III',					'1000'), \
						(%i, 'Gold Nova Master',				'1100'), \
						(%i, 'Master Guardian I',				'1250'), \
						(%i, 'Master Guardian II',				'1400'), \
						(%i, 'Master Guardian Elite',			'1600'), \
						(%i, 'Distinguished Master Guardian',	'1800'), \
						(%i, 'Legendary Eagle',					'2100'), \
						(%i, 'Legendary Eagle Master',			'2400'), \
						(%i, 'Supreme Master First Class',		'3000'), \
						(%i, 'The Global Elite',				'4000')", g_iRanksID, g_iRanksID, g_iRanksID, 
						g_iRanksID, g_iRanksID, g_iRanksID, g_iRanksID, g_iRanksID, g_iRanksID, g_iRanksID, 
						g_iRanksID, g_iRanksID, g_iRanksID, g_iRanksID, g_iRanksID, g_iRanksID, g_iRanksID, g_iRanksID);
			}
			case '1':
			{
				g_hDatabase.Format(SZF(szQuery), "INSERT INTO `fps_ranks` (`rank_id`, `rank_name`, `points`) \
					VALUES \
						(%i, 'Lab Rat I',			'0'), \
						(%i, 'Lab Rat II',			'600'), \
						(%i, 'Sprinting Hare I',	'785'), \
						(%i, 'Sprinting Hare II',	'900'), \
						(%i, 'Wild Scout I',		'950'), \
						(%i, 'Wild Scout II',		'1000'), \
						(%i, 'Wild Scout Elite',	'1050'), \
						(%i, 'Hunter Fox I',		'1250'), \
						(%i, 'Hunter Fox II',		'1400'), \
						(%i, 'Hunter Fox III',		'1650'), \
						(%i, 'Hunter Fox Elite',	'2000'), \
						(%i, 'Timber Wolf',			'2400'), \
						(%i, 'Ember Wolf',			'2800'), \
						(%i, 'Wildfire Wolf',		'3200'), \
						(%i, 'The Howling Alpha',	'4000')", g_iRanksID, g_iRanksID, g_iRanksID, g_iRanksID, 
						g_iRanksID, g_iRanksID, g_iRanksID, g_iRanksID, g_iRanksID, g_iRanksID, g_iRanksID, 
						g_iRanksID, g_iRanksID, g_iRanksID, g_iRanksID);
			}
			case '2':
			{
				g_hDatabase.Format(SZF(szQuery), "INSERT INTO `fps_ranks` (`rank_id`, `rank_name`, `points`) \
					VALUES \
						(%i, 'FaceIt Level I',		'0'), \
						(%i, 'FaceIt Level II',		'700'), \
						(%i, 'FaceIt Level III',	'800'), \
						(%i, 'FaceIt Level IV',		'1000'), \
						(%i, 'FaceIt Level V',		'1300'), \
						(%i, 'FaceIt Level VI',		'1600'), \
						(%i, 'FaceIt Level VII',	'2000'), \
						(%i, 'FaceIt Level VIII',	'2400'), \
						(%i, 'FaceIt Level IX',		'3000'), \
						(%i, 'FaceIt Level X',		'4000')", g_iRanksID, g_iRanksID, g_iRanksID, g_iRanksID, 
						g_iRanksID, g_iRanksID, g_iRanksID, g_iRanksID, g_iRanksID, g_iRanksID);
			}
			default:
			{
				ReplyToCommand(iClient, ">> Выберите тип рангов: 0 - Стандартные ранги (18 lvl). 1 - Ранги опасной зоны (15 lvl). 2 - Фейсит ранги (10 lvl).");
				return Plugin_Handled;
			}
		}
		FPS_Debug("CommandCreateRanks >> Query(Type: %s): %s", szArg, szQuery)
		g_hDatabase.Query(SQL_Callback_CreateRanks, szQuery, iClient ? UID(iClient) : 0);
	}
	return Plugin_Handled;
}

void SQL_Callback_CreateRanks(Database hDatabase, DBResultSet hResult, const char[] szError, any iUserID)
{
	if (CheckDatabaseConnection("SQL_Callback_CreateRanks", szError, hResult))
	{
		LoadRanksSettings();

		int iClient = CID(iUserID);
		if (iClient)
		{
			FPS_PrintToChat(iClient, "Request completed successfully!");
		}
	}
}

// Load ranks settings
void LoadRanksSettings()
{
	if (g_hDatabase)
	{
		char szQuery[256];
		g_hDatabase.Format(SZF(szQuery), "SELECT `rank_name`, `points` \
			FROM `fps_ranks` WHERE `rank_id` = %i ORDER BY `points` DESC", g_iRanksID);
		FPS_Debug("LoadRanksSettings >> Query: %s", szQuery)
		g_hDatabase.Query(SQL_Callback_LoadRanks, szQuery);
	}
}

void SQL_Callback_LoadRanks(Database hDatabase, DBResultSet hResult, const char[] szError, any data)
{
	if (g_hRanks && CheckDatabaseConnection("SQL_Callback_LoadRanks", szError, hResult))
	{
		g_hRanks.Clear();

		int		iLevel;
		char	szBuffer[64];
		while(hResult.FetchRow())
		{
			g_hRanks.Push(hResult.FetchFloat(1));
			hResult.FetchString(0, SZF(szBuffer));
			g_hRanks.PushString(szBuffer);
			++iLevel;
		}
		g_iRanksCount = iLevel;

		if (!g_iRanksCount)
		{
			LogError("[FPS] No rank! Add them using 'sm_fps_create_default_ranks' or manually.");
		}

		FPS_Debug("SQL_Callback_LoadRanks >> Ranks count: %i", g_iRanksCount)
	}
}

// Load player data
void LoadPlayerData(int iClient)
{
	if (g_hDatabase)
	{
		char szQuery[256];
		g_hDatabase.Format(SZF(szQuery), "SELECT \
				`points`, `kills`, `deaths`, `assists`, \
				`round_max_kills`, `round_win`, `round_lose`, `playtime` \
			FROM \
				`fps_servers_stats` \
			WHERE \
				`server_id` = %i AND `account_id` = %i LIMIT 1", g_iServerID, g_iPlayerAccountID[iClient]);
		FPS_Debug("LoadPlayerData >> Query: %s", szQuery)
		g_hDatabase.Query(SQL_Callback_LoadPlayerData, szQuery, UID(iClient));
	}
}

void SQL_Callback_LoadPlayerData(Database hDatabase, DBResultSet hResult, const char[] szError, any iUserID)
{
	int iClient = CID(iUserID);
	if (!iClient || !CheckDatabaseConnection("SQL_Callback_LoadPlayerData", szError, hResult))
	{
		return;
	}

	if (hResult.FetchRow())
	{
		g_fPlayerSessionPoints[iClient] = g_fPlayerPoints[iClient] = hResult.FetchFloat(0);
		for (int i = 0; i < sizeof(g_iPlayerData[]); ++i)
		{
			g_iPlayerSessionData[iClient][i] = g_iPlayerData[iClient][i] = hResult.FetchInt(i+1);
		}

		FPS_Debug("SQL_Callback_LoadPlayerData >> %N: points: %f | kills: %i, deaths: %i, assists: %i, round_max_kills: %i, round_win: %i, round_lose: %i, playtime: %i", iClient, g_fPlayerPoints[iClient], g_iPlayerData[iClient][KILLS], g_iPlayerData[iClient][DEATHS], g_iPlayerData[iClient][ASSISTS], g_iPlayerData[iClient][MAX_ROUNDS_KILLS], g_iPlayerData[iClient][ROUND_WIN], g_iPlayerData[iClient][ROUND_LOSE], g_iPlayerData[iClient][PLAYTIME])
	}
	else
	{
		g_fPlayerSessionPoints[iClient]	= g_fPlayerPoints[iClient] = DEFAULT_POINTS;
		FPS_Debug("SQL_Callback_LoadPlayerData >> New player: %N", iClient)
	}

	g_iPlayerSessionData[iClient][MAX_ROUNDS_KILLS] = 0; // (not used var) for blocked accrual of experience to connected player
	g_iPlayerSessionData[iClient][PLAYTIME] = GetTime();
	g_bStatsLoad[iClient] = true;
	GetPlayerPosition(iClient);
	CheckRank(iClient);

	CallForward_OnFPSClientLoaded(iClient, g_fPlayerPoints[iClient]);
}

void SavePlayerData(int iClient)
{
	if (g_hDatabase)
	{
		char	szQuery[1024],
				szAuth[32],
				szName[MAX_NAME_LENGTH * 2 + 1],
				szIp[32];
		GetClientAuthId(iClient, AuthId_SteamID64, SZF(szAuth), true);
		GetClientName(iClient, SZF(szName));
		GetClientIP(iClient, SZF(szIp));

		Transaction	hTxn = new Transaction();

		g_hDatabase.Format(SZF(szQuery), "INSERT INTO `fps_players` ( \
				`account_id`, `steam_id`, `nickname`, `ip` \
			) VALUES ( \
				'%i', '%s', '%s', '%s' \
			) ON DUPLICATE KEY UPDATE `nickname` = '%s', `ip` = '%s';", 
			g_iPlayerAccountID[iClient], szAuth, szName, szIp, szName, szIp);
		FPS_Debug("SavePlayerData >> Query#1: %s", szQuery)
		hTxn.AddQuery(szQuery);

		int iPlayTime = FPS_GetPlayedTime(iClient);
		g_hDatabase.Format(SZF(szQuery), "INSERT INTO `fps_servers_stats` ( \
				`account_id`,`server_id`,`points`, `rank`, `kills`, \
				`deaths`,`assists`,`round_max_kills`,`round_win`, \
				`round_lose`,`playtime`,`lastconnect` \
			) \
			VALUES \
				(%i, %i, %f, %i, %i, %i, %i, %i, %i, %i, %i, %i) ON DUPLICATE KEY \
			UPDATE \
				`points` = %f, `rank` = %i, `kills` = %i, `deaths` = %i, `assists` = %i, `round_max_kills` = %i, \
				`round_win` = %i, `round_lose` = %i, `playtime` = %i, `lastconnect` = %i;", 
			g_iPlayerAccountID[iClient], g_iServerID, g_fPlayerPoints[iClient], g_iPlayerRanks[iClient], g_iPlayerData[iClient][KILLS],
			g_iPlayerData[iClient][DEATHS], g_iPlayerData[iClient][ASSISTS], g_iPlayerData[iClient][MAX_ROUNDS_KILLS], g_iPlayerData[iClient][ROUND_WIN],
			g_iPlayerData[iClient][ROUND_LOSE], iPlayTime, g_iPlayerSessionData[iClient][PLAYTIME],

			g_fPlayerPoints[iClient], g_iPlayerRanks[iClient], g_iPlayerData[iClient][KILLS], g_iPlayerData[iClient][DEATHS], 
			g_iPlayerData[iClient][ASSISTS], g_iPlayerData[iClient][MAX_ROUNDS_KILLS], 
			g_iPlayerData[iClient][ROUND_WIN], g_iPlayerData[iClient][ROUND_LOSE], iPlayTime, g_iPlayerSessionData[iClient][PLAYTIME]);
		FPS_Debug("SavePlayerData >> Query#2: %s", szQuery)
		hTxn.AddQuery(szQuery);

		// Save weapons stats
		if (g_hWeaponsData[iClient])
		{
			int		iSize = g_hWeaponsData[iClient].Length,
					iArray[W_SIZE];
			char	szWeapon[32];
			for (int i = 0; i < iSize; i += 2)
			{
				g_hWeaponsData[iClient].GetString(i, SZF(szWeapon));
				FPS_Debug("SavePlayerData >> Weapon '%s' finded! Index: %i", szWeapon, i)
				g_hWeaponsData[iClient].GetArray((i+1), SZF(iArray));

				g_hDatabase.Format(SZF(szQuery), "INSERT INTO `fps_weapons_stats` ( \
						`account_id`, `server_id`, `weapon`, `kills`, `shoots`, \
						`hits_head`, `hits_neck`, `hits_chest`, `hits_stomach`, \
						`hits_left_arm`, `hits_right_arm`, `hits_left_leg`, `hits_right_leg`, `headshots` \
					) VALUES \
						('%i', '%i', '%s', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i') ON DUPLICATE KEY \
					UPDATE \
						`kills` = `kills` + '%i', \
						`shoots` = `shoots` + '%i', \
						`hits_head` = `hits_head` + '%i', \
						`hits_neck` = `hits_neck` + '%i', \
						`hits_chest` = `hits_chest` + '%i', \
						`hits_stomach` = `hits_stomach` + '%i', \
						`hits_left_arm` = `hits_left_arm` + '%i', \
						`hits_right_arm` = `hits_right_arm` + '%i', \
						`hits_left_leg` = `hits_left_leg` + '%i', \
						`hits_right_leg` = `hits_right_leg` + '%i', \
						`headshots` = `headshots` + '%i';", 
					g_iPlayerAccountID[iClient], g_iServerID, szWeapon, iArray[W_KILLS], iArray[W_SHOOTS], 
					iArray[W_HITS_HEAD], iArray[W_HITS_NECK], iArray[W_HITS_CHEST], iArray[W_HITS_STOMACH], 
					iArray[W_HITS_LEFT_ARM], iArray[W_HITS_RIGHT_ARM], iArray[W_HITS_LEFT_LEG], iArray[W_HITS_RIGHT_LEG], iArray[W_HEADSHOTS], 
					iArray[W_KILLS], iArray[W_SHOOTS], iArray[W_HITS_HEAD], iArray[W_HITS_NECK], iArray[W_HITS_CHEST], iArray[W_HITS_STOMACH], 
					iArray[W_HITS_LEFT_ARM], iArray[W_HITS_RIGHT_ARM], iArray[W_HITS_LEFT_LEG], iArray[W_HITS_RIGHT_LEG], iArray[W_HEADSHOTS]);
				FPS_Debug("SavePlayerData >> WeaponQuery#%i: %s", ++u, szQuery)
				hTxn.AddQuery(szQuery);
			}

			g_hWeaponsData[iClient].Clear();
		}

		g_hDatabase.Execute(hTxn, SQL_TxnSuccess_UpdateOrInsertPlayerData, SQL_TxnFailure_UpdateOrInsertPlayerData);
	}
}

void SQL_TxnSuccess_UpdateOrInsertPlayerData(Database hDatabase, any Data, int iNumQueries, DBResultSet[] results, any[] QueryData)
{
	FPS_Debug("SQL_TxnSuccess_UpdateOrInsertPlayerData >> Success")
}

void SQL_TxnFailure_UpdateOrInsertPlayerData(Database hDatabase, any Data, int iNumQueries, const char[] szError, int iFailIndex, any[] QueryData)
{
	char szBuffer[128];
	FormatEx(SZF(szBuffer), "SQL_TxnFailure_UpdateOrInsertPlayerData #%i", iFailIndex);
	CheckDatabaseConnection(szBuffer, szError);
}

void DeleteInactivePlayers()
{
	if (g_hDatabase && g_iDeletePlayersTime)
	{
		char szQuery[256];
		g_hDatabase.Format(SZF(szQuery), "DELETE `s`, `w` \
			FROM \
				`fps_servers_stats` AS `s` \
				INNER JOIN `fps_weapons_stats` AS `w` ON `s`.`account_id` = `w`.`account_id` AND `s`.`server_id` = `w`.`server_id` \
			WHERE \
				`s`.`server_id` = %i AND `s`.`lastconnect` < %i;", g_iServerID, (GetTime() - g_iDeletePlayersTime));
		FPS_Debug("DeleteInactivePlayers >> Query: %s", szQuery)
		g_hDatabase.Query(SQL_Default_Callback, szQuery, 3);
	}
}

// Get top data
void LoadTopData()
{
	if (g_hDatabase)
	{
		char	szQuery[256];
		Transaction	hTxn = new Transaction();

		g_hDatabase.Format(SZF(szQuery), "SELECT `p`.`nickname`, `s`.`points` \
			FROM \
				`fps_servers_stats` AS `s` \
				INNER JOIN `fps_players` AS `p` ON `p`.`account_id` = `s`.`account_id` \
			WHERE `server_id` = %i ORDER BY `points` DESC LIMIT 10;", g_iServerID);
		FPS_Debug("LoadTopData >> Query#1 (TopPoints): %s", szQuery)
		hTxn.AddQuery(szQuery);

		g_hDatabase.Format(SZF(szQuery), "SELECT `p`.`nickname`, TRUNCATE(`s`.`kills` / `s`.`deaths`, 2) AS `kdr` \
				FROM `fps_servers_stats` AS `s` \
				INNER JOIN `fps_players` AS `p` ON `p`.`account_id` = `s`.`account_id` \
			WHERE `server_id` = %i ORDER BY `kdr` DESC LIMIT 10;", g_iServerID);
		FPS_Debug("LoadTopData >> Query#2 (TopKRD): %s", szQuery)
		hTxn.AddQuery(szQuery);

		g_hDatabase.Format(SZF(szQuery), "SELECT `p`.`nickname`, `s`.`playtime` \
			FROM \
				`fps_servers_stats` AS `s` \
				INNER JOIN `fps_players` AS `p` ON `p`.`account_id` = `s`.`account_id` \
			WHERE `server_id` = %i ORDER BY `playtime` DESC LIMIT 10;", g_iServerID);
		FPS_Debug("LoadTopData >> Query#3 (TopTime): %s", szQuery)
		hTxn.AddQuery(szQuery);

		g_hDatabase.Format(SZF(szQuery), "SELECT `p`.`nickname`, `s`.`round_max_kills` \
			FROM \
				`fps_servers_stats` AS `s` \
				INNER JOIN `fps_players` AS `p` ON `p`.`account_id` = `s`.`account_id` \
			WHERE `server_id` = %i ORDER BY `round_max_kills` DESC, `points` DESC LIMIT 10", g_iServerID);
		FPS_Debug("LoadTopData >> Query#4 (TopClutch): %s", szQuery)
		hTxn.AddQuery(szQuery);

		g_hDatabase.Format(SZF(szQuery), "SELECT COUNT(`id`) FROM `fps_servers_stats` WHERE `server_id` = %i;", g_iServerID);
		FPS_Debug("LoadTopData >> Query#5 (GetPlayerCount): %s", szQuery)
		hTxn.AddQuery(szQuery);

		g_hDatabase.Execute(hTxn, SQL_TxnSuccess_TopData, SQL_TxnFailure_TopData);
	}
}

void SQL_TxnSuccess_TopData(Database hDatabase, any Data, int iNumQueries, DBResultSet[] hResult, any[] QueryData)
{
	for (int i = 0; i < sizeof(g_fTopData[]); ++i)
	{
		int u = 0;
		while(hResult[i].FetchRow())
		{
			hResult[i].FetchString(0, g_sTopData[u][i], sizeof(g_sTopData[][]));
			g_fTopData[u][i] = hResult[i].FetchFloat(1);
			++u;
		}
	}

	if (hResult[sizeof(g_fTopData[])].FetchRow())
	{
		g_iPlayersCount = hResult[sizeof(g_fTopData[])].FetchInt(0);
	}
}

void SQL_TxnFailure_TopData(Database hDatabase, any Data, int iNumQueries, const char[] szError, int iFailIndex, any[] QueryData)
{
	char szBuffer[128];
	FormatEx(SZF(szBuffer), "SQL_TxnFailure_TopData #%i", iFailIndex);
	CheckDatabaseConnection(szBuffer, szError);
}

// Get player position
void GetPlayerPosition(int iClient)
{
	if (g_hDatabase)
	{
		char szQuery[256];
		g_hDatabase.Format(SZF(szQuery), "SELECT DISTINCT COUNT(`id`) AS `position` \
			FROM `fps_servers_stats` WHERE `points` >= %f AND `server_id` = %i;", g_fPlayerPoints[iClient], g_iServerID);
		FPS_Debug("GetPlayerPosition >> Query: %s", szQuery)
		g_hDatabase.Query(SQL_Callback_PlayerPosition, szQuery, UID(iClient));
	}
}

void SQL_Callback_PlayerPosition(Database hDatabase, DBResultSet hResult, const char[] szError, any iUserID)
{
	int iClient = CID(iUserID);
	if (iClient && CheckDatabaseConnection("SQL_Callback_PlayerPosition", szError, hResult))
	{
		g_iPlayerPosition[iClient] = hResult.FetchRow() ? hResult.FetchInt(0) : 0;
		FPS_Debug("SQL_Callback_PlayerPosition >> %N: position: %i / %i", iClient, g_iPlayerPosition[iClient], g_iPlayersCount)

		CallForward_OnFPSPlayerPosition(iClient, g_iPlayerPosition[iClient], g_iPlayersCount);
	}
}

void UpdateServerData(char[] szIP, int iPort)
{
	if (g_hDatabase)
	{
		char	szQuery[512],
				szServerName[256];
		FindConVar("hostname").GetString(SZF(szServerName));

		#if UPDATE_SERVER_IP == 1
			g_hDatabase.Format(SZF(szQuery), "INSERT INTO `fps_servers` ( \
				`id`, `server_name`, `settings_rank_id`, `settings_points_id`, `server_ip` \
			) VALUES ( %i, '%s', %i, %i, '%s:%i' ) ON DUPLICATE KEY UPDATE \
				`id` = %i, `server_name` = '%s', `settings_rank_id` = %i, `settings_points_id` = %i, `server_ip` = '%s:%i';", 
			g_iServerID, szServerName, g_iRanksID, 1, szIP, iPort,
			g_iServerID, szServerName, g_iRanksID, 1, szIP, iPort);
		#else
			g_hDatabase.Format(SZF(szQuery), "INSERT INTO `fps_servers` ( \
				`id`, `server_name`, `settings_rank_id`, `settings_points_id`, `server_ip` \
			) VALUES ( %i, '%s', %i, %i, '%s:%i' ) ON DUPLICATE KEY UPDATE \
				`id` = %i, `server_name` = '%s', `settings_rank_id` = %i, `settings_points_id` = %i;", 
			g_iServerID, szServerName, g_iRanksID, 1, szIP, iPort,
			g_iServerID, szServerName, g_iRanksID, 1);
		#endif

		FPS_Debug("UpdateServerData >> Query (%i): %s", UPDATE_SERVER_IP, szQuery)
		g_hDatabase.Query(SQL_Default_Callback, szQuery, 5);
	}
}
