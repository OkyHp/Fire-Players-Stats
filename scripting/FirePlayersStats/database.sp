static Handle g_hTimerReconnectDB;

void DatabaseConnect()
{
	static const char szSection[] = "fire_players_stats";

	if (g_hDatabase)
	{
		delete g_hDatabase;
	}

	if (SQL_CheckConfig(szSection))
	{
		Database.Connect(OnDatabaseConnect, szSection);
	}
	else
	{
		SetFailState("DatabaseConnect: Section \"%s\" not found in \"/addons/sourcemod/configs/database.cfg\". Use only MySQL!", szSection);
	}
}

public Action Timer_DatabaseRetryConn(Handle hTimer)
{
	DatabaseConnect();
	return Plugin_Continue;
}

bool CheckDatabaseConnection(Database hDatabase, const char[] szError, const char[] szErrorTag)
{
	if (!hDatabase || szError[0])
	{
		LogError("%s: %s", szErrorTag, szError);
		if(StrContains(szError, "Lost connection to MySQL", false) != -1)
		{
			delete g_hDatabase;
			CallForward_OnFPSDatabaseLostConnection();
			g_hTimerReconnectDB = CreateTimer(g_fDBRetryConnTime, Timer_DatabaseRetryConn, _, TIMER_REPEAT);
		}
		return false;
	}
	return true;
}

public void OnDatabaseConnect(Database hDatabase, const char[] szError, any Data)
{
	if (!CheckDatabaseConnection(hDatabase, szError, "OnDatabaseConnect"))
	{
		return;
	}

	if (g_hTimerReconnectDB)
	{
		delete g_hTimerReconnectDB;
	}

	g_hDatabase = hDatabase;
	CallForward_OnFPSDatabaseConnected();

	static bool bCrateTables;
	if (!bCrateTables)
	{
		bCrateTables = true;

		Transaction hTxn = new Transaction();
		hTxn.AddQuery("CREATE TABLE IF NOT EXISTS `fps_players` ( \
				`account_id`	int				NOT NULL, \
				`steam_id`		varchar(64)		NOT NULL, \
				`nickname`		varchar(256)	NOT NULL, \
				`ip`			varchar(24)		NOT NULL, \
				PRIMARY KEY (`account_id`) \
			) ENGINE = InnoDB CHARACTER SET utf8 COLLATE utf8_general_ci;");
		hTxn.AddQuery("CREATE TABLE IF NOT EXISTS `fps_servers_stats` ( \
				`id`				int 		NOT NULL AUTO_INCREMENT, \
				`account_id`		int			NOT NULL, \
				`server_id`			int			NOT NULL, \
				`points`			float		UNSIGNED NOT NULL, \
				`kills`				int			NOT NULL DEFAULT '0', \
				`deaths`			int			NOT NULL DEFAULT '0', \
				`assists`			int			NOT NULL DEFAULT '0', \
				`round_max_kills`	int			NOT NULL DEFAULT '0', \
				`round_win`			int			NOT NULL DEFAULT '0', \
				`round_lose`		int			NOT NULL DEFAULT '0', \
				`playtime`			int			NOT NULL DEFAULT '0', \
				`lastconnect`		int			NOT NULL, \
				PRIMARY KEY (`id`), \
				UNIQUE(`account_id`, `server_id`) \
			) ENGINE = InnoDB CHARACTER SET utf8 COLLATE utf8_general_ci;");
		hTxn.AddQuery("CREATE TABLE IF NOT EXISTS `fps_weapons_stats` ( \
				`id`				int 			NOT NULL AUTO_INCREMENT, \
				`account_id`		int				NOT NULL, \
				`server_id`			int				NOT NULL, \
				`weapon`			varchar(64)		NOT NULL, \
				`kills`				int				NOT NULL, \
				`shoots`			int				NOT NULL, \
				`hits_head`			int				NOT NULL, \
				`hits_body`			int				NOT NULL, \
				`hits_left_arm`		int				NOT NULL, \
				`hits_right_arm`	int				NOT NULL, \
				`hits_left_leg`		int				NOT NULL, \
				`hits_right_leg`	int				NOT NULL, \
				`headshots`			int				NOT NULL, \
				PRIMARY KEY (`id`), \
				UNIQUE(`account_id`, `server_id`, `weapon`) \
			) ENGINE = InnoDB CHARACTER SET utf8 COLLATE utf8_general_ci;"); // `hits`			int				NOT NULL, 
		#if USE_RANKS == 1
			hTxn.AddQuery("CREATE TABLE IF NOT EXISTS `fps_ranks` ( \
					`id`			int 			NOT NULL AUTO_INCREMENT, \
					`rank_id`		int 			NOT NULL, \
					`rank_name`		varchar(128)	NOT NULL, \
					`points`		float			UNSIGNED NOT NULL, \
					PRIMARY KEY (`id`) \
				) ENGINE = InnoDB CHARACTER SET utf8 COLLATE utf8_general_ci;");
		#endif
		g_hDatabase.Execute(hTxn, SQL_TxnSuccess_CreateTable, SQL_TxnFailure_CreateTable);
	}
}

public void SQL_Default_Callback(Database hDatabase, DBResultSet hResult, const char[] szError, any QueryID)
{
	if (hResult == null || szError[0])
	{
		char szBuffer[128];
		FormatEx(SZF(szBuffer), "SQL_Default_Callback #%i", QueryID);
		CheckDatabaseConnection(hDatabase, szError, szBuffer);
	}
}

public void SQL_TxnSuccess_CreateTable(Database hDatabase, any Data, int iNumQueries, DBResultSet[] results, any[] QueryData)
{
	if (g_hDatabase)
	{
		g_hDatabase.Query(SQL_Default_Callback, "SET NAMES 'utf8'", 1);
		g_hDatabase.Query(SQL_Default_Callback, "SET CHARSET 'utf8'", 2);
		g_hDatabase.SetCharset("utf8");
	}
}

public void SQL_TxnFailure_CreateTable(Database hDatabase, any Data, int iNumQueries, const char[] szError, int iFailIndex, any[] QueryData)
{
	SetFailState("SQL_TxnFailure_CreateTable #%i: %s", iFailIndex, szError);
}

#if USE_RANKS == 1
	// Load ranks settings
	void LoadRanksSettings()
	{
		if (g_hDatabase)
		{
			char szQuery[256];
			g_hDatabase.Format(SZF(szQuery), "SELECT `rank_name`, `points` \
				FROM `fps_ranks` WHERE `rank_id` = %i ORDER BY `points` ASC", g_iRanksID);
			FPS_Debug("LoadRanksSettings >> Query: %s", szQuery)
			g_hDatabase.Query(SQL_Callback_LoadRanks, szQuery);
		}
	}

	public void SQL_Callback_LoadRanks(Database hDatabase, DBResultSet hResult, const char[] szError, any data)
	{
		if (g_hRanksConfigKV)
		{
			delete g_hRanksConfigKV;
		}
		char szPath[256];
		BuildPath(Path_SM, SZF(szPath), "configs/FirePlayersStats/catch_ranks.ini");
		g_hRanksConfigKV = new KeyValues("Ranks_Settings");

		if (!CheckDatabaseConnection(hDatabase, szError, "SQL_Callback_LoadRanks"))
		{
			if (!g_hDatabase)
			{
				if (!g_hRanksConfigKV.ImportFromFile(szPath))
				{
					SetFailState("Not fount ranks setting cache file. If it`s first run of the plugin - check database connection.");
				}

				int iLevel;
				g_hRanksConfigKV.Rewind();
				if (g_hRanksConfigKV.GotoFirstSubKey(false))
				{
					do {
						++iLevel;
					} while (g_hRanksConfigKV.GotoNextKey(false));
				}
				g_iRanksCount = iLevel;

				FPS_Debug("SQL_Callback_LoadRanks >> Catch KV >> %i", iLevel)
			}
			return;
		}

		int		iLevel;
		char	szBuffer[128];
		while(hResult.FetchRow())
		{
			hResult.FetchString(0, SZF(szBuffer));
			g_hRanksConfigKV.SetFloat(szBuffer, hResult.FetchFloat(1));
			++iLevel;
		}
		g_iRanksCount = iLevel;

		FPS_Debug("SQL_Callback_LoadRanks >> Database KV >> %i", iLevel)

		g_hRanksConfigKV.Rewind();
		g_hRanksConfigKV.ExportToFile(szPath);
	}
#endif

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

public void SQL_Callback_LoadPlayerData(Database hDatabase, DBResultSet hResult, const char[] szError, any iUserID)
{
	int iClient = CID(iUserID);
	if (!iClient || !CheckDatabaseConnection(hDatabase, szError, "SQL_Callback_LoadPlayerData"))
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
	#if USE_RANKS == 1
		CheckRank(iClient);
	#endif
	GetPlayerPosition(iClient);
	g_bStatsLoad[iClient] = true;

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
		strcopy(SZF(szName), GetFixNamePlayer(iClient)); // <-----------------------------
		GetClientIP(iClient, SZF(szIp));

		Transaction	hTxn = new Transaction();

		g_hDatabase.Format(SZF(szQuery), "INSERT INTO `fps_players` ( \
				`account_id`, `steam_id`, `nickname`, `ip` \
			) VALUES ( \
				%i, '%s', '%s', '%s' \
			) ON DUPLICATE KEY UPDATE `nickname` = '%s', `ip` = '%s';", 
			g_iPlayerAccountID[iClient], szAuth, szName, szIp, szName, szIp);
		FPS_Debug("SavePlayerData >> Query#1: %s", szQuery)
		hTxn.AddQuery(szQuery);

		int iPlayTime = FPS_GetPlayedTime(iClient, false);
		g_hDatabase.Format(SZF(szQuery), "INSERT INTO `fps_servers_stats` ( \
				`account_id`,`server_id`,`points`,`kills`, \
				`deaths`,`assists`,`round_max_kills`,`round_win`, \
				`round_lose`,`playtime`,`lastconnect` \
			) \
			VALUES \
				(%i, %i, %f, %i, %i, %i, %i, %i, %i, %i, %i) ON DUPLICATE KEY \
			UPDATE \
				`points` = %f, `kills` = %i, `deaths` = %i, `assists` = %i, `round_max_kills` = %i, \
				`round_win` = %i, `round_lose` = %i, `playtime` = %i, `lastconnect` = %i;", 
			g_iPlayerAccountID[iClient], g_iServerID, g_fPlayerPoints[iClient], g_iPlayerData[iClient][KILLS],
			g_iPlayerData[iClient][DEATHS], g_iPlayerData[iClient][ASSISTS], g_iPlayerData[iClient][MAX_ROUNDS_KILLS], g_iPlayerData[iClient][ROUND_WIN],
			g_iPlayerData[iClient][ROUND_LOSE], iPlayTime, g_iPlayerSessionData[iClient][PLAYTIME],

			g_fPlayerPoints[iClient], g_iPlayerData[iClient][KILLS], g_iPlayerData[iClient][DEATHS], 
			g_iPlayerData[iClient][ASSISTS], g_iPlayerData[iClient][MAX_ROUNDS_KILLS], 
			g_iPlayerData[iClient][ROUND_WIN], g_iPlayerData[iClient][ROUND_LOSE], iPlayTime, g_iPlayerSessionData[iClient][PLAYTIME]);
		FPS_Debug("SavePlayerData >> Query#2: %s", szQuery)
		hTxn.AddQuery(szQuery);

		// Save weapons stats
		if (g_hWeaponsKV)
		{
			// char szPath[256];
			// BuildPath(Path_SM, SZF(szPath), "configs/FirePlayersStats/test.ini");
			// g_hWeaponsKV.Rewind();
			// g_hWeaponsKV.ExportToFile(szPath);

			char szAccountID[32];
			IntToString(g_iPlayerAccountID[iClient], SZF(szAccountID));

			g_hWeaponsKV.Rewind();
			if (g_hWeaponsKV.JumpToKey(szAccountID) && g_hWeaponsKV.GotoFirstSubKey())
			{
				#if DEBUG == 1
					int i;
				#endif
				int iKills, iShoots, iHitsHead, iHitsBody, iHitsLeftArm, iHitsRightArm, iHitsLeftLeg, iHitsRightLeg, iHeadshots;
				char szWeapon[32];
				do {
					iKills			= g_hWeaponsKV.GetNum("kills");
					iShoots			= g_hWeaponsKV.GetNum("shoots");
					//iHits			= g_hWeaponsKV.GetNum("hits");
					iHitsHead		= g_hWeaponsKV.GetNum("hitsHead");
					iHitsBody		= g_hWeaponsKV.GetNum("hitsBody");
					iHitsLeftArm	= g_hWeaponsKV.GetNum("hitsLeftArm");
					iHitsRightArm	= g_hWeaponsKV.GetNum("hitsRightArm");
					iHitsLeftLeg	= g_hWeaponsKV.GetNum("hitsLeftLeg");
					iHitsRightLeg	= g_hWeaponsKV.GetNum("hitsRightLeg");
					iHeadshots	= g_hWeaponsKV.GetNum("headshots");
					g_hWeaponsKV.GetSectionName(SZF(szWeapon));

					g_hDatabase.Format(SZF(szQuery), "INSERT INTO `fps_weapons_stats` ( \
							`account_id`, `server_id`, `weapon`, `kills`, `shoots`, \
							`hits_head`, `hits_body`, `hits_left_arm`, `hits_right_arm`, \
							`hits_left_leg`, `hits_right_leg`, `headshots` \
						) VALUES \
							(%i, %i, '%s', %i, %i, %i, %i, %i, %i, %i, %i, %i) ON DUPLICATE KEY \
						UPDATE \
							`kills` = `kills` + %i, \
							`shoots` = `shoots` + %i, \
							`hits_head` = `hits_head` + %i, \
							`hits_body` = `hits_body` + %i, \
							`hits_left_arm` = `hits_left_arm` + %i, \
							`hits_right_arm` = `hits_right_arm` + %i, \
							`hits_left_leg` = `hits_left_leg` + %i, \
							`hits_right_leg` = `hits_right_leg` + %i, \
							`headshots` = `headshots` + %i;", 
						g_iPlayerAccountID[iClient], g_iServerID, szWeapon, iKills, iShoots, 
						iHitsHead, iHitsBody, iHitsLeftArm, iHitsRightArm, 
						iHitsLeftLeg, iHitsRightLeg, iHeadshots,
						iKills, iShoots, iHitsHead, iHitsBody, iHitsLeftArm, iHitsRightArm,
						iHitsLeftLeg, iHitsRightLeg, iHeadshots);
					FPS_Debug("SavePlayerData >> WeaponQuery#%i: %s", ++i, szQuery)
					hTxn.AddQuery(szQuery);
				} while (g_hWeaponsKV.GotoNextKey());

				g_hWeaponsKV.GoBack();
				g_hWeaponsKV.DeleteThis();
			}
		}

		g_hDatabase.Execute(hTxn, SQL_TxnSuccess_UpdateOrInsertPlayerData, SQL_TxnFailure_UpdateOrInsertPlayerData);
	}
}

public void SQL_TxnSuccess_UpdateOrInsertPlayerData(Database hDatabase, any Data, int iNumQueries, DBResultSet[] results, any[] QueryData)
{
	FPS_Debug("SQL_TxnSuccess_UpdateOrInsertPlayerData >> Success")
}

public void SQL_TxnFailure_UpdateOrInsertPlayerData(Database hDatabase, any Data, int iNumQueries, const char[] szError, int iFailIndex, any[] QueryData)
{
	char szBuffer[128];
	FormatEx(SZF(szBuffer), "SQL_TxnFailure_UpdateOrInsertPlayerData #%i", iFailIndex);
	CheckDatabaseConnection(hDatabase, szError, szBuffer);
}

void DeleteInactivePlayers()
{
	if (g_hDatabase)
	{
		char szQuery[256];
		g_hDatabase.Format(SZF(szQuery), "DELETE `s`, `w` \
			FROM \
				`fps_servers_stats` AS `s` \
				INNER JOIN `fps_weapons_stats` AS `w` ON `s`.`account_id` = `w`.`account_id` \
			WHERE \
				`s`.`server_id` = %i \
				AND `w`.`server_id` = %i \
				AND `s`.`lastconnect` < %i;", g_iServerID, g_iServerID, (GetTime() - g_iDeletePlayersTime));
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

		g_hDatabase.Format(SZF(szQuery), "SELECT \
				`p`.`nickname`, `s`.`points` \
			FROM \
				`fps_servers_stats` AS `s` \
				INNER JOIN `fps_players` AS `p` ON `p`.`account_id` = `s`.`account_id` \
			WHERE `server_id` = %i ORDER BY `points` DESC LIMIT 10;", g_iServerID);
		FPS_Debug("LoadTopData >> Query#1 (Top): %s", szQuery)
		hTxn.AddQuery(szQuery);

		g_hDatabase.Format(SZF(szQuery), "SELECT \
				`p`.`nickname`, `s`.`playtime` \
			FROM \
				`fps_servers_stats` AS `s` \
				INNER JOIN `fps_players` AS `p` ON `p`.`account_id` = `s`.`account_id` \
			WHERE `server_id` = %i ORDER BY `playtime` DESC LIMIT 10;", g_iServerID);
		FPS_Debug("LoadTopData >> Query#2 (TopTime): %s", szQuery)
		hTxn.AddQuery(szQuery);

		g_hDatabase.Format(SZF(szQuery), "SELECT COUNT(`id`) FROM `fps_servers_stats` WHERE `server_id` = %i;", g_iServerID);
		FPS_Debug("LoadTopData >> Query#3 (GetPlayerCount): %s", szQuery)
		hTxn.AddQuery(szQuery);

		g_hDatabase.Execute(hTxn, SQL_TxnSuccess_TopData, SQL_TxnFailure_TopData);
	}
}

public void SQL_TxnSuccess_TopData(Database hDatabase, any Data, int iNumQueries, DBResultSet[] hResult, any[] QueryData)
{
	for (int i = 0; i < 2; ++i)
	{
		int u = 0;
		while(hResult[i].FetchRow())
		{
			hResult[i].FetchString(0, g_sTopData[u][i], sizeof(g_sTopData[][]));
			g_fTopData[u][i] = hResult[i].FetchFloat(1);
			++u;
		}
	}

	if (hResult[2].FetchRow())
	{
		g_iPlayersCount = hResult[2].FetchInt(0);
	}
}

public void SQL_TxnFailure_TopData(Database hDatabase, any Data, int iNumQueries, const char[] szError, int iFailIndex, any[] QueryData)
{
	char szBuffer[128];
	FormatEx(SZF(szBuffer), "SQL_TxnFailure_TopData #%i", iFailIndex);
	CheckDatabaseConnection(hDatabase, szError, szBuffer);
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

public void SQL_Callback_PlayerPosition(Database hDatabase, DBResultSet hResult, const char[] szError, any iUserID)
{
	int iClient = CID(iUserID);
	if (!iClient || !CheckDatabaseConnection(hDatabase, szError, "SQL_Callback_PlayerPosition"))
	{
		return;
	}

	g_iPlayerPosition[iClient] = hResult.FetchRow() ? hResult.FetchInt(0) : 0;
	FPS_Debug("SQL_Callback_PlayerPosition >> %N: position: %i / %i", iClient, g_iPlayerPosition[iClient], g_iPlayersCount)

	CallForward_OnFPSPlayerPosition(iClient, g_iPlayerPosition[iClient], g_iPlayersCount);
}
