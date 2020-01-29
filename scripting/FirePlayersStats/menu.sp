void SetCommands()
{
	RegConsoleCmd("sm_pos",			CommandPosition);
	RegConsoleCmd("sm_position",	CommandPosition);
	RegConsoleCmd("sm_top",			CommandTop);
	RegConsoleCmd("sm_stats",		CommandFpsMenu);
	RegConsoleCmd("sm_fps",			CommandFpsMenu);
	RegConsoleCmd("sm_rank",		CommandFpsMenu);
}

Action CommandPosition(int iClient, int iArgs)
{
	if (IsPlayerLoaded(iClient))
	{
		ShowPosition(iClient);
	}
	return Plugin_Handled;
}

Action CommandTop(int iClient, int iArgs)
{
	if (IsPlayerLoaded(iClient))
	{
		char szArg[32];
		GetCmdArg(1, SZF(szArg));

		if (!szArg[0])
		{
			ShowMainTopMenu(iClient);
		}
		else
		{
			static const char szTops[][] = {"points", "kdr", "time", "clutch"};
			for (int i = sizeof(szTops); i--;)
			{
				if (!strcmp(szArg, szTops[i], false))
				{
					ShowTopMenu(iClient, i);
					break;
				}
			}
		}
	}
	return Plugin_Handled;
}

Action CommandFpsMenu(int iClient, int iArgs)
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
	hMenu.SetTitle("%t\n ", "MiniDataTitle", "FpsTitle", g_fPlayerPoints[iClient], g_iPlayerRanks[iClient], FindTranslationRank(iClient), g_iPlayerPosition[iClient], g_iPlayersCount);
	
	char szBuffer[128];
	FormatEx(SZF(szBuffer), "%t", "MainStatsMenu");
	hMenu.AddItem(NULL_STRING, szBuffer);
	FormatEx(SZF(szBuffer), "%t", "ListsOfTops");
	hMenu.AddItem(NULL_STRING, szBuffer);
	FormatEx(SZF(szBuffer), "%t", "AdditionalMenu");
	hMenu.AddItem(NULL_STRING, szBuffer);

	hMenu.ExitButton = true;
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

int Handler_FpsMenu(Menu hMenu, MenuAction action, int iClient, int iItem)
{
	switch(action)
	{
		case MenuAction_End: delete hMenu;
		case MenuAction_Select:
		{
			switch(iItem)
			{
				case 0: ShowMainStatsMenu(iClient);
				case 1: ShowMainTopMenu(iClient);
				case 2: ShowMainAdditionalMenu(iClient);
			}
		}
	}
}

void ShowMainStatsMenu(int iClient, int iPage = 0)
{
	Menu hMenu = new Menu(Handler_MainStatsMenu, MENU_ACTIONS_ALL);
	SetGlobalTransTarget(iClient);
	hMenu.SetTitle("%t\n ", "MiniDataTitle", "MainStatsMenu", g_fPlayerPoints[iClient], g_iPlayerRanks[iClient], FindTranslationRank(iClient), g_iPlayerPosition[iClient], g_iPlayersCount);
	
	char szBuffer[128];
	FormatEx(SZF(szBuffer), "%t", "GeneralStats");
	hMenu.AddItem(">", szBuffer);
	FormatEx(SZF(szBuffer), "%t", "SessionStats");
	hMenu.AddItem(">", szBuffer);

	AddFeatureItemToMenu(hMenu, FPS_STATS_MENU);

	if (g_iResetStatsTime)
	{
		int iPlayedTime = FPS_GetPlayedTime(iClient);
		if (iPlayedTime < g_iResetStatsTime)
		{
			float fResult = float(g_iResetStatsTime - iPlayedTime);
			FormatEx(SZF(szBuffer), "%t\n ", "ResetPlayerStatsLock", fResult > 0 ? (fResult / 60 / 60) : 0.0);
			hMenu.AddItem(">", szBuffer, ITEMDRAW_DISABLED);
		}
		else
		{
			FormatEx(SZF(szBuffer), "%t\n ", "ResetPlayerStats");
			hMenu.AddItem(">", szBuffer, ITEMDRAW_DEFAULT);
		}
	}

	hMenu.ExitBackButton = true;
	hMenu.ExitButton = true;
	hMenu.DisplayAt(iClient, iPage, MENU_TIME_FOREVER);
}

int Handler_MainStatsMenu(Menu hMenu, MenuAction action, int iClient, int iItem)
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
		case MenuAction_Select:
		{
			switch(iItem)
			{
				case 0: ShowPlayerMenu(iClient, false);
				case 1: ShowPlayerMenu(iClient, true);
				default: 
				{
					if (iItem == hMenu.ItemCount - 1)
					{
						ResetPlayerStatsMenu(iClient);
					}
				}
			}
		}
		case MenuAction_DrawItem:
		{
			if (iItem == hMenu.ItemCount - 1 && FPS_GetPlayedTime(iClient) < g_iResetStatsTime)
			{
				return ITEMDRAW_DISABLED;
			}
		}
	}

	return FeatureHandler(hMenu, action, iClient, iItem, FPS_STATS_MENU);
}

void ShowPlayerMenu(int iClient, bool bSession = false)
{
	char szBuffer[512];
	Panel hPanel = new Panel();
	SetGlobalTransTarget(iClient);

	if (!bSession)
	{
		FormatEx(SZF(szBuffer), "[ %t ]\n ", "GeneralStats");
		hPanel.SetTitle(szBuffer);

		int iPlayedTime = FPS_GetPlayedTime(iClient);
		FormatEx(SZF(szBuffer), "%t\n ", "PlayerGeneralData", g_fPlayerPoints[iClient], g_iPlayerData[iClient][KILLS], g_iPlayerData[iClient][DEATHS], 
			(g_iPlayerData[iClient][KILLS] && g_iPlayerData[iClient][DEATHS] ? (float(g_iPlayerData[iClient][KILLS]) / float(g_iPlayerData[iClient][DEATHS])) : 0.0), 
			g_iPlayerData[iClient][ASSISTS], g_iPlayerData[iClient][MAX_ROUNDS_KILLS], (g_iPlayerData[iClient][ROUND_WIN] + g_iPlayerData[iClient][ROUND_LOSE]), 
			g_iPlayerData[iClient][ROUND_WIN], g_iPlayerData[iClient][ROUND_LOSE], (iPlayedTime ? (float(iPlayedTime) / 60.0 / 60.0) : 0.0));
	}
	else
	{
		FormatEx(SZF(szBuffer), "[ %t ]\n ", "SessionStats");
		hPanel.SetTitle(szBuffer);

		int iSessions[4];
		iSessions[0] = g_iPlayerData[iClient][KILLS] - g_iPlayerSessionData[iClient][KILLS];
		iSessions[1] = g_iPlayerData[iClient][DEATHS] - g_iPlayerSessionData[iClient][DEATHS];
		iSessions[2] = g_iPlayerData[iClient][ROUND_WIN] - g_iPlayerSessionData[iClient][ROUND_WIN];
		iSessions[3] = g_iPlayerData[iClient][ROUND_LOSE] - g_iPlayerSessionData[iClient][ROUND_LOSE];
		FormatEx(SZF(szBuffer), "%t\n ", "PlayerSessionData", (g_fPlayerPoints[iClient] - g_fPlayerSessionPoints[iClient]), 
			iSessions[0], iSessions[1], (iSessions[0] && iSessions[1] ? (float(iSessions[0]) / float(iSessions[1])) : 0.0), 
			(g_iPlayerData[iClient][ASSISTS] - g_iPlayerSessionData[iClient][ASSISTS]), (iSessions[2] + iSessions[3]), iSessions[2], iSessions[3]);
	}

	hPanel.DrawText(szBuffer);

	FormatEx(SZF(szBuffer), "%t", "Back");
	hPanel.CurrentKey = 7;
	hPanel.DrawItem(szBuffer);

	FormatEx(SZF(szBuffer), "%t", "Exit");
	hPanel.CurrentKey = 9;
	hPanel.DrawItem(szBuffer);

	hPanel.Send(iClient, Handler_PanelStats, MENU_TIME_FOREVER);
	delete hPanel;
}

int Handler_PanelStats(Menu hPanel, MenuAction action, int iClient, int iOption)
{
	if(g_bStatsLoad[iClient] && action == MenuAction_Select)
	{
		if (iOption == 7)
		{
			ShowMainStatsMenu(iClient);
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

int Handler_PanelResetStats(Menu hPanel, MenuAction action, int iClient, int iOption)
{
	if(g_bStatsLoad[iClient] && action == MenuAction_Select)
	{
		if (iOption != 7 && iOption != 9)
		{
			ResetData(iClient, true);
			SavePlayerData(iClient);
			FPS_PrintToChat(iClient, "%t", "YourStatsReset");
			PlayItemSelectSound(iClient, false);
		}
		else
		{
			if (iOption == 7)
			{
				ShowMainStatsMenu(iClient);
			}
			PlayItemSelectSound(iClient, true);
		}
	}
}


void ShowMainTopMenu(int iClient, int iPage = 0)
{
	Menu hMenu = new Menu(Handler_MainTopMenu, MENU_ACTIONS_ALL);
	SetGlobalTransTarget(iClient);
	hMenu.SetTitle("%t\n ", "TopTitle", "ListsOfTops");
	
	char szBuffer[128];
	FormatEx(SZF(szBuffer), "%t", "TopPoints");
	hMenu.AddItem(NULL_STRING, szBuffer);
	FormatEx(SZF(szBuffer), "%t", "TopKDR");
	hMenu.AddItem(NULL_STRING, szBuffer);
	FormatEx(SZF(szBuffer), "%t", "TopTime");
	hMenu.AddItem(NULL_STRING, szBuffer);
	FormatEx(SZF(szBuffer), "%t", "TopClutch");
	hMenu.AddItem(NULL_STRING, szBuffer);

	AddFeatureItemToMenu(hMenu, FPS_TOP_MENU);

	hMenu.ExitBackButton = true;
	hMenu.ExitButton = true;
	hMenu.DisplayAt(iClient, iPage, MENU_TIME_FOREVER);
}

int Handler_MainTopMenu(Menu hMenu, MenuAction action, int iClient, int iItem)
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
		case MenuAction_Select:
		{
			if (iItem < 4)
			{
				ShowTopMenu(iClient, iItem);
			}
		}
	}

	return FeatureHandler(hMenu, action, iClient, iItem, FPS_TOP_MENU);
}

void ShowTopMenu(int iClient, int iMenuType)
{
	char szBuffer[512];
	Panel hPanel = new Panel();
	SetGlobalTransTarget(iClient);

	switch(iMenuType)
	{
		case 0: FormatEx(SZF(szBuffer), "[ %t ]\n ", "TopPoints");
		case 1: FormatEx(SZF(szBuffer), "[ %t ]\n ", "TopKDR");
		case 2: FormatEx(SZF(szBuffer), "[ %t ]\n ", "TopTime");
		case 3: FormatEx(SZF(szBuffer), "[ %t ]\n ", "TopClutch");
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
			case 1: FormatEx(SZF(szBuffer), "%i. %.2f KDR - %s", i+1, g_fTopData[i][iMenuType], g_sTopData[i][iMenuType]);
			case 2: FormatEx(SZF(szBuffer), "%i. %.2f %t - %s", i+1, (g_fTopData[i][iMenuType] / 60.0 / 60.0), "Hours", g_sTopData[i][iMenuType]);
			case 3: FormatEx(SZF(szBuffer), "%i. %.0f %t - %s", i+1, g_fTopData[i][iMenuType], "Kills", g_sTopData[i][iMenuType]);
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

	hPanel.Send(iClient, Handler_PanelTop, MENU_TIME_FOREVER);
	delete hPanel;
}

int Handler_PanelTop(Menu hPanel, MenuAction action, int iClient, int iOption)
{
	if(g_bStatsLoad[iClient] && action == MenuAction_Select)
	{
		if (iOption == 7)
		{
			ShowMainTopMenu(iClient);
		}
		PlayItemSelectSound(iClient, true);
	}
}

void ShowMainAdditionalMenu(int iClient, int iPage = 0)
{
	Menu hMenu = new Menu(Handler_MainAdditionalMenu, MENU_ACTIONS_ALL);
	SetGlobalTransTarget(iClient);
	hMenu.SetTitle("[ %t ]\n ", "AdditionalMenu");

	char szBuffer[128];
	FormatEx(SZF(szBuffer), "%t", "StatsInfo");
	hMenu.AddItem(NULL_STRING, szBuffer);
	FormatEx(SZF(szBuffer), "%t", "RanksInfo");
	hMenu.AddItem(NULL_STRING, szBuffer);
	
	AddFeatureItemToMenu(hMenu, FPS_ADVANCED_MENU);

	hMenu.ExitBackButton = true;
	hMenu.ExitButton = true;
	hMenu.DisplayAt(iClient, iPage, MENU_TIME_FOREVER);
}

int Handler_MainAdditionalMenu(Menu hMenu, MenuAction action, int iClient, int iItem)
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
		case MenuAction_Select:
		{
			static char szItem[128];
			hMenu.GetItem(iItem, SZF(szItem));
			if (!szItem[0])
			{
				switch(iItem)
				{
					case 0: ShowStatsInfoMenu(iClient);
					case 1: ShowRankInfoMenu(iClient);
				}
			}
		}
	}
	return FeatureHandler(hMenu, action, iClient, iItem, FPS_ADVANCED_MENU);
}

// public int Handler_Panel(Menu hPanel, MenuAction action, int iClient, int iOption)
// {
// 	if(g_bStatsLoad[iClient] && action == MenuAction_Select)
// 	{
// 		if (iOption == 7)
// 		{
// 			ShowFpsMenu(iClient);
// 		}
// 		PlayItemSelectSound(iClient, true);
// 	}
// }

int Handler_BackToFpsMenu(Menu hMenu, MenuAction action, int iClient, int iItem)
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

void ShowRankInfoMenu(int iClient)
{
	Menu hMenu = new Menu(Handler_BackToFpsMenu);
	SetGlobalTransTarget(iClient);
	hMenu.SetTitle("[ %t ]\n ", "RanksInfo");

	char szBuffer[160];
	if (g_hRanks)
	{
		int		iSize = g_hRanks.Length;
		float	fRank;
		char	szRank[64];
		for (int i = 0; i < iSize; i += 2)
		{
			fRank = g_hRanks.Get(i);
			g_hRanks.GetString(i+1, SZF(szRank));
			FormatEx(SZF(szBuffer), "%.2f %t - %s [%s]", fRank, "Points", FindTranslationRank(iClient, szRank), g_fPlayerPoints[iClient] < fRank ? "✗" : "✓");
			hMenu.AddItem(NULL_STRING, szBuffer, ITEMDRAW_DISABLED);
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
			#if USE_STREAK_POINTS == 0
				int i;
			#endif

			char szParam[32], szBuffer[128];
			do {
				#if USE_STREAK_POINTS == 0
					if (i == 13)
					{
						break;
					}
					++i;
				#endif

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
		for (int i = MaxClients + 1; --i;)
		{
			if (g_bStatsLoad[i] && iClient != i)
			{
				FPS_PrintToChat(i, "%t", "ShowPlayerPosition", iClient, g_iPlayerPosition[iClient], g_iPlayersCount, g_fPlayerPoints[iClient], fKDR);
			}
		}
	}
}
