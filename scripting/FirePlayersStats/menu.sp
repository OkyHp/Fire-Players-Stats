void SetCommands()
{
	RegConsoleCmd("sm_pos",			CommandPosition);
	RegConsoleCmd("sm_position",	CommandPosition);
	RegConsoleCmd("sm_top",			CommandTop);
	RegConsoleCmd("sm_toptime",		CommandTopTime);
	RegConsoleCmd("sm_clutch",		CommandClutch);
	RegConsoleCmd("sm_stats",		CommandFpsMenu);
	RegConsoleCmd("sm_fps",			CommandFpsMenu);
	RegConsoleCmd("sm_rank",		CommandFpsMenu);
}

public Action CommandPosition(int iClient, int iArgs)
{
	if (IsPlayerLoaded(iClient))
	{
		ShowPosition(iClient);
	}
	return Plugin_Handled;
}

public Action CommandTop(int iClient, int iArgs)
{
	if (IsPlayerLoaded(iClient))
	{
		ShowTopMenu(iClient, 0);
	}
	return Plugin_Handled;
}

public Action CommandTopTime(int iClient, int iArgs)
{
	if (IsPlayerLoaded(iClient))
	{
		ShowTopMenu(iClient, 1);
	}
	return Plugin_Handled;
}

public Action CommandClutch(int iClient, int iArgs)
{
	if (IsPlayerLoaded(iClient))
	{
		ShowTopMenu(iClient, 2);
	}
	return Plugin_Handled;
}

public Action CommandFpsMenu(int iClient, int iArgs)
{
	if (IsPlayerLoaded(iClient))
	{
		ShowFpsMenu(iClient);
	}
	return Plugin_Handled;
}

void ShowFpsMenu(int iClient)
{
	Menu hMenu = new Menu(Handler_FpsMenu);
	SetGlobalTransTarget(iClient);
	#if USE_RANKS == 1
		hMenu.SetTitle("%t\n ", "FpsTitle", g_fPlayerPoints[iClient], g_iPlayerRanks[iClient], FindTranslationRank(iClient));
	#else
		hMenu.SetTitle("%t\n ", "FpsTitleNoRanks", g_fPlayerPoints[iClient]);
	#endif
	
	char szBuffer[64];
	FormatEx(SZF(szBuffer), "%t", "MyStats");
	hMenu.AddItem(NULL_STRING, szBuffer);
	FormatEx(SZF(szBuffer), "%t", "TopTen");
	hMenu.AddItem(NULL_STRING, szBuffer);
	FormatEx(SZF(szBuffer), "%t", "TopTime");
	hMenu.AddItem(NULL_STRING, szBuffer);
	FormatEx(SZF(szBuffer), "%t", "TopClutch");
	hMenu.AddItem(NULL_STRING, szBuffer);
	FormatEx(SZF(szBuffer), "%t", "StatsInfo");
	hMenu.AddItem(NULL_STRING, szBuffer);
	#if USE_RANKS == 1
		FormatEx(SZF(szBuffer), "%t", "RanksInfo");
		hMenu.AddItem(NULL_STRING, szBuffer);
	#endif

	hMenu.ExitButton = true;
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int Handler_FpsMenu(Menu hMenu, MenuAction action, int iClient, int iItem)
{
	switch(action)
	{
		case MenuAction_End: delete hMenu;
		case MenuAction_Select:
		{
			switch(iItem)
			{
				case 0: ShowPlayerMenu(iClient);
				case 1: ShowTopMenu(iClient, 0);
				case 2: ShowTopMenu(iClient, 1);
				case 3: ShowTopMenu(iClient, 2);
				case 4: ShowStatsInfoMenu(iClient);
				#if USE_RANKS == 1
					case 5: ShowRankInfoMenu(iClient);
				#endif
			}
		}
	}
}

void ShowPlayerMenu(int iClient)
{
	char szBuffer[512];
	Panel hPanel = new Panel();
	SetGlobalTransTarget(iClient);

	FormatEx(SZF(szBuffer), "[ %t ]\n ", "PlayerTitle");
	hPanel.SetTitle(szBuffer);

	int iPlayedTime = FPS_GetPlayedTime(iClient);
	float fPlayedTime = iPlayedTime ? (float(iPlayedTime) / 60.0 / 60.0) : 0.0;

	#if USE_RANKS == 1
		FormatEx(SZF(szBuffer), "%t\n ", "PlayerData", g_fPlayerPoints[iClient], g_iPlayerRanks[iClient], FindTranslationRank(iClient), g_iPlayerPosition[iClient], g_iPlayersCount, g_iPlayerData[iClient][KILLS], 
		g_iPlayerData[iClient][DEATHS], (g_iPlayerData[iClient][KILLS] && g_iPlayerData[iClient][DEATHS] ? (float(g_iPlayerData[iClient][KILLS]) / float(g_iPlayerData[iClient][DEATHS])) : 0.0), g_iPlayerData[iClient][ASSISTS], 
		g_iPlayerData[iClient][MAX_ROUNDS_KILLS], (g_iPlayerData[iClient][ROUND_WIN] + g_iPlayerData[iClient][ROUND_LOSE]), g_iPlayerData[iClient][ROUND_WIN], g_iPlayerData[iClient][ROUND_LOSE], fPlayedTime);
	#else
		FormatEx(SZF(szBuffer), "%t\n ", "PlayerDataNoRanks", g_fPlayerPoints[iClient], g_iPlayerPosition[iClient], g_iPlayersCount, g_iPlayerData[iClient][KILLS], 
		g_iPlayerData[iClient][DEATHS], (g_iPlayerData[iClient][KILLS] && g_iPlayerData[iClient][DEATHS] ? (float(g_iPlayerData[iClient][KILLS]) / float(g_iPlayerData[iClient][DEATHS])) : 0.0), g_iPlayerData[iClient][ASSISTS], 
		g_iPlayerData[iClient][MAX_ROUNDS_KILLS], (g_iPlayerData[iClient][ROUND_WIN] + g_iPlayerData[iClient][ROUND_LOSE]), g_iPlayerData[iClient][ROUND_WIN], g_iPlayerData[iClient][ROUND_LOSE], fPlayedTime);
	#endif
	hPanel.DrawText(szBuffer);

	FormatEx(SZF(szBuffer), "%t", "SessionStats");
	hPanel.CurrentKey = 1;
	hPanel.DrawItem(szBuffer);

	if (g_iResetStatsTime)
	{
		hPanel.CurrentKey = 2;
		if (iPlayedTime < g_iResetStatsTime)
		{
			FormatEx(SZF(szBuffer), "%t\n ", "ResetPlayerStatsLock", (float(g_iResetStatsTime) / 60.0 / 60.0) - fPlayedTime);
			hPanel.DrawItem(szBuffer, ITEMDRAW_DISABLED);
		}
		else
		{
			FormatEx(SZF(szBuffer), "%t\n ", "ResetPlayerStats");
			hPanel.DrawItem(szBuffer, ITEMDRAW_DEFAULT);
		}
	}

	FormatEx(SZF(szBuffer), "%t", "Back");
	hPanel.CurrentKey = 7;
	hPanel.DrawItem(szBuffer);

	FormatEx(SZF(szBuffer), "%t", "Exit");
	hPanel.CurrentKey = 9;
	hPanel.DrawItem(szBuffer);

	hPanel.Send(iClient, Handler_PanelStats, MENU_TIME_FOREVER);
	delete hPanel;
}

public int Handler_PanelStats(Menu hPanel, MenuAction action, int iClient, int iOption)
{
	if(g_bStatsLoad[iClient] && action == MenuAction_Select)
	{
		switch(iOption)
		{
			case 1: ShowPlayerSessionsMenu(iClient);
			case 2: ResetPlayerStatsMenu(iClient);
			case 7: ShowFpsMenu(iClient);
		}
		PlayItemSelectSound(iClient, (iOption == 7 || iOption == 9));
	}
}

void ShowPlayerSessionsMenu(int iClient)
{
	char szBuffer[512];
	Panel hPanel = new Panel();
	SetGlobalTransTarget(iClient);

	FormatEx(SZF(szBuffer), "[ %t ]\n ", "SessionStats");
	hPanel.SetTitle(szBuffer);

	int iSessions[4];
	iSessions[0] = g_iPlayerData[iClient][KILLS] - g_iPlayerSessionData[iClient][KILLS];
	iSessions[1] = g_iPlayerData[iClient][DEATHS] - g_iPlayerSessionData[iClient][DEATHS];
	iSessions[2] = g_iPlayerData[iClient][ROUND_WIN] - g_iPlayerSessionData[iClient][ROUND_WIN];
	iSessions[3] = g_iPlayerData[iClient][ROUND_LOSE] - g_iPlayerSessionData[iClient][ROUND_LOSE];
	FormatEx(SZF(szBuffer), "%t\n ", "PlayerDataSession", (g_fPlayerPoints[iClient] - g_fPlayerSessionPoints[iClient]), iSessions[0], iSessions[1], 
		(iSessions[0] && iSessions[1] ? (float(iSessions[0]) / float(iSessions[1])) : 0.0), 
		(g_iPlayerData[iClient][ASSISTS] - g_iPlayerSessionData[iClient][ASSISTS]), 
		(iSessions[2] + iSessions[3]), iSessions[2], iSessions[3]);
	hPanel.DrawText(szBuffer);

	FormatEx(SZF(szBuffer), "%t", "Back");
	hPanel.CurrentKey = 7;
	hPanel.DrawItem(szBuffer);

	FormatEx(SZF(szBuffer), "%t", "Exit");
	hPanel.CurrentKey = 9;
	hPanel.DrawItem(szBuffer);

	hPanel.Send(iClient, Handler_PanelSessions, MENU_TIME_FOREVER);
	delete hPanel;
}

public int Handler_PanelSessions(Menu hPanel, MenuAction action, int iClient, int iOption)
{
	if(g_bStatsLoad[iClient] && action == MenuAction_Select)
	{
		if (iOption == 7)
		{
			ShowPlayerMenu(iClient);
		}
		PlayItemSelectSound(iClient, true);
	}
}

void ResetPlayerStatsMenu(int iClient)
{
	char szBuffer[512];
	Panel hPanel = new Panel();
	SetGlobalTransTarget(iClient);

	FormatEx(SZF(szBuffer), "[ %t ]\n ", "ResetPlayerStats");
	hPanel.SetTitle(szBuffer);

	FormatEx(SZF(szBuffer), "%t\n ", "AreYouSureResetStats");
	hPanel.DrawText(szBuffer);

	FormatEx(SZF(szBuffer), "%t\n ", "YesImSure");
	hPanel.CurrentKey = GetRandomInt(1, 6);
	hPanel.DrawItem(szBuffer);

	FormatEx(SZF(szBuffer), "%t", "Back");
	hPanel.CurrentKey = 7;
	hPanel.DrawItem(szBuffer);

	FormatEx(SZF(szBuffer), "%t", "Exit");
	hPanel.CurrentKey = 9;
	hPanel.DrawItem(szBuffer);

	hPanel.Send(iClient, Handler_PanelResetStats, MENU_TIME_FOREVER);
	delete hPanel;
}

public int Handler_PanelResetStats(Menu hPanel, MenuAction action, int iClient, int iOption)
{
	if(g_bStatsLoad[iClient] && action == MenuAction_Select)
	{
		if (iOption != 7 && iOption != 9)
		{
			ResetData(iClient);
			int iAccountID = GetSteamAccountID(iClient, true);
			if (iAccountID)
			{
				g_iPlayerAccountID[iClient] = iAccountID;
				g_bStatsLoad[iClient] = true;
				SavePlayerData(iClient);
				FPS_PrintToChat(iClient, "%t", "YourStatsReset");
			}
			PlayItemSelectSound(iClient, false);
		}
		else
		{
			if (iOption == 7)
			{
				ShowPlayerMenu(iClient);
			}
			PlayItemSelectSound(iClient, true);
		}
	}
}

void ShowTopMenu(int iClient, int iMenuType)
{
	char szBuffer[512];
	Panel hPanel = new Panel();
	SetGlobalTransTarget(iClient);

	switch(iMenuType)
	{
		case 0: FormatEx(SZF(szBuffer), "%t\n ", "TopTitle", "TopTen");
		case 1: FormatEx(SZF(szBuffer), "%t\n ", "TopTitle", "TopTime");
		case 2: FormatEx(SZF(szBuffer), "%t\n ", "TopTitle", "TopClutch");
	}
	hPanel.SetTitle(szBuffer);
	
	for (int i = 0; i < 10; ++i)
	{
		if (!g_fTopData[i][iMenuType])
		{
			break;
		}

		switch(iMenuType)
		{
			case 0: FormatEx(SZF(szBuffer), "%i. %.2f %t - %s", i+1, g_fTopData[i][iMenuType], "Points", g_sTopData[i][iMenuType]);
			case 1: FormatEx(SZF(szBuffer), "%i. %.2f %t - %s", i+1, (g_fTopData[i][iMenuType] / 60.0 / 60.0), "Hours", g_sTopData[i][iMenuType]);
			case 2: FormatEx(SZF(szBuffer), "%i. %.0f %t - %s", i+1, g_fTopData[i][iMenuType], "Kills", g_sTopData[i][iMenuType]);
		}
		hPanel.DrawText(szBuffer);
	}

	if (!g_fTopData[0][iMenuType])
	{
		FormatEx(SZF(szBuffer), "%t", "NoPlayers");
		hPanel.DrawText(szBuffer);
	}

	hPanel.DrawText("\n ");
	
	FormatEx(SZF(szBuffer), "%t", "Back");
	hPanel.CurrentKey = 7;
	hPanel.DrawItem(szBuffer);

	FormatEx(SZF(szBuffer), "%t", "Exit");
	hPanel.CurrentKey = 9;
	hPanel.DrawItem(szBuffer);

	hPanel.Send(iClient, Handler_Panel, MENU_TIME_FOREVER);
	delete hPanel;
}

public int Handler_Panel(Menu hPanel, MenuAction action, int iClient, int iOption)
{
	if(g_bStatsLoad[iClient] && action == MenuAction_Select)
	{
		if (iOption == 7)
		{
			ShowFpsMenu(iClient);
		}
		PlayItemSelectSound(iClient, true);
	}
}

public int Handler_BackToFpsMenu(Menu hMenu, MenuAction action, int iClient, int iItem)
{
	switch(action)
	{
		case MenuAction_End: delete hMenu;
		case MenuAction_Cancel:
		{
			if(iItem == MenuCancel_ExitBack)
			{
				ShowFpsMenu(iClient);
			}
		}
	}
}

#if USE_RANKS == 1
	void ShowRankInfoMenu(int iClient)
	{
		Menu hMenu = new Menu(Handler_BackToFpsMenu);
		SetGlobalTransTarget(iClient);
		hMenu.SetTitle("[ %t ]\n ", "RanksInfo");

		char szBuffer[72];
		if (g_hRanksConfigKV)
		{
			float	fRank;
			char	szRank[64];
			g_hRanksConfigKV.Rewind();
			if (g_hRanksConfigKV.GotoFirstSubKey(false))
			{
				do {
					fRank = g_hRanksConfigKV.GetFloat(NULL_STRING);
					g_hRanksConfigKV.GetSectionName(SZF(szRank));
					FormatEx(SZF(szBuffer), "[%.2f] %s (%s)", fRank, szRank, g_fPlayerPoints[iClient] < fRank ? "✗" : "✓");
					hMenu.AddItem(NULL_STRING, szBuffer, ITEMDRAW_DISABLED);
				} while (g_hRanksConfigKV.GotoNextKey(false));
			}
		}

		if (!hMenu.ItemCount)
		{
			FormatEx(SZF(szBuffer), "%t", "NoRanks");
			hMenu.AddItem(NULL_STRING, szBuffer, ITEMDRAW_DISABLED);
		}

		hMenu.ExitBackButton = true;
		hMenu.ExitButton = true;
		hMenu.Display(iClient, MENU_TIME_FOREVER);
	}
#endif

void ShowStatsInfoMenu(int iClient)
{
	Menu hMenu = new Menu(Handler_BackToFpsMenu);
	SetGlobalTransTarget(iClient);
	hMenu.SetTitle("%t", "StatsInfoTitle", "StatsInfo", DEFAULT_POINTS);

	if (g_hWeaponsConfigKV)
	{
		g_hWeaponsConfigKV.Rewind();
		if (g_hWeaponsConfigKV.JumpToKey("ExtraPoints") && g_hWeaponsConfigKV.GotoFirstSubKey(false))
		{
			char szParam[32], szBuffer[128];
			do {
				g_hWeaponsConfigKV.GetSectionName(SZF(szParam));
				FormatEx(SZF(szBuffer), "%t", szParam, g_hWeaponsConfigKV.GetFloat(NULL_STRING, 0.0));
				hMenu.AddItem(NULL_STRING, szBuffer, ITEMDRAW_DISABLED);
			} while (g_hWeaponsConfigKV.GotoNextKey(false));
		}
	}

	hMenu.ExitBackButton = true;
	hMenu.ExitButton = true;
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

void ShowPosition(int iClient)
{
	float fKDR = g_iPlayerData[iClient][KILLS] && g_iPlayerData[iClient][DEATHS] ? (float(g_iPlayerData[iClient][KILLS]) / float(g_iPlayerData[iClient][DEATHS])) : 0.0;
	FPS_PrintToChat(iClient, "%t", "ShowMePosition", g_iPlayerPosition[iClient], g_iPlayersCount, g_fPlayerPoints[iClient], fKDR);
	if (g_bShowStatsEveryone)
	{
		for (int i = 1; i < MaxClients; ++i)
		{
			if (g_bStatsLoad[i] && iClient != i)
			{
				FPS_PrintToChat(i, "%t", "ShowPlayerPosition", iClient, g_iPlayerPosition[iClient], g_iPlayersCount, g_fPlayerPoints[iClient], fKDR);
			}
		}
	}
}
