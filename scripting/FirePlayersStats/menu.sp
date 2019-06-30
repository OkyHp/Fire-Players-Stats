public void OnClientSayCommand_Post(int iClient, const char[] szCommand, const char[] sArgs)
{
	if (g_bStatsLoad[iClient])
	{
		static const char szCommands[][] = {
			"pos", "position", "top", "toptime", "stats", "fps", "rank"
		};

		if (!strcmp(sArgs[1], szCommands[0], false) || !strcmp(sArgs, szCommands[0], false) || !strcmp(sArgs[1], szCommands[1], false) || !strcmp(sArgs, szCommands[1], false))
		{
			ShowPosition(iClient);
		}
		else if (!strcmp(sArgs[1], szCommands[2], false) || !strcmp(sArgs, szCommands[2], false))
		{
			ShowTopMenu(iClient, 0);
		}
		else if (!strcmp(sArgs[1], szCommands[3], false) || !strcmp(sArgs, szCommands[3], false))
		{
			ShowTopMenu(iClient, 1);
		}
		else if (!strcmp(sArgs[1], szCommands[4], false) || !strcmp(sArgs, szCommands[4], false) || !strcmp(sArgs[1], szCommands[5], false) || !strcmp(sArgs, szCommands[5], false) || !strcmp(sArgs[1], szCommands[6], false) || !strcmp(sArgs, szCommands[6], false))
		{
			ShowFpsMenu(iClient);
		}

		return;
	}

	FPS_PrintToChat(iClient, "%t", "ErrorDataLoad");
}

void ShowFpsMenu(int iClient)
{
	Menu hMenu = new Menu(Handler_FpsMenu);
	SetGlobalTransTarget(iClient);
	hMenu.SetTitle("%t\n ", "FpsTitle", g_fPlayerPoints[iClient], g_iPlayerRanks[iClient], g_sRankName[iClient]);
	
	char szBuffer[64];
	FormatEx(SZF(szBuffer), "%t", "MyStats");
	hMenu.AddItem(NULL_STRING, szBuffer);
	FormatEx(SZF(szBuffer), "%t", "TopTen");
	hMenu.AddItem(NULL_STRING, szBuffer);
	FormatEx(SZF(szBuffer), "%t", "TopTime");
	hMenu.AddItem(NULL_STRING, szBuffer);
	FormatEx(SZF(szBuffer), "%t", "RanksInfo");
	hMenu.AddItem(NULL_STRING, szBuffer);
	FormatEx(SZF(szBuffer), "%t", "StatsInfo");
	hMenu.AddItem(NULL_STRING, szBuffer);

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
				case 3: ShowRankInfoMenu(iClient);
				case 4: ShowStatsInfoMenu(iClient);
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

	int iPlayedTime = FPS_GetPlayedTime(iClient, false);
	float fPlayedTime = iPlayedTime ? (iPlayedTime / 60.0 / 60.0) : 0.0;

	FormatEx(SZF(szBuffer), "%t\n ", "PlayerData", g_fPlayerPoints[iClient], g_iPlayerRanks[iClient], g_sRankName[iClient], g_iPlayerPosition[iClient], g_iPlayersCount, g_iPlayerData[iClient][KILLS], 
		g_iPlayerData[iClient][DEATHS], (g_iPlayerData[iClient][KILLS] && g_iPlayerData[iClient][DEATHS] ? (float(g_iPlayerData[iClient][KILLS]) / float(g_iPlayerData[iClient][DEATHS])) : 0.0), g_iPlayerData[iClient][ASSISTS], 
		g_iPlayerData[iClient][MAX_ROUNDS_KILLS], (g_iPlayerData[iClient][ROUND_WIN] + g_iPlayerData[iClient][ROUND_LOSE]), g_iPlayerData[iClient][ROUND_WIN], g_iPlayerData[iClient][ROUND_LOSE], fPlayedTime);
	hPanel.DrawText(szBuffer);

	FormatEx(SZF(szBuffer), "%t", "SessionStats");
	hPanel.CurrentKey = 1;
	hPanel.DrawItem(szBuffer);

	FormatEx(SZF(szBuffer), "%t\n ", "ResetPlayerStats");
	hPanel.CurrentKey = 2;
	hPanel.DrawItem(szBuffer, iPlayedTime > g_iResetStatsTime ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

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
	FormatEx(SZF(szBuffer), "%t\n ", "PlayerDataSession", iSessions[0], iSessions[1], 
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
			SavePlayerData(iClient);
			FPS_PrintToChat(iClient, "%t", "YourStatsReset");
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

	FormatEx(SZF(szBuffer), "%t\n ", "TopTitle", !iMenuType ? "TopTen" : "TopTime");
	hPanel.SetTitle(szBuffer);

	int i;
	while(i < 10)
	{
		if (g_iTopData[i][iMenuType])
		{
			FormatEx(SZF(szBuffer), "%i. [%.2f] %s", i+1, !iMenuType ? g_fTopData[i][iMenuType] : (g_fTopData[i][iMenuType] / 60 / 60), g_sTopData[i][iMenuType]);
			hPanel.DrawText(szBuffer);
			++i;
		}
	}

	if (!i)
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

void ShowStatsInfoMenu(int iClient)
{
	char szBuffer[512];
	Panel hPanel = new Panel();
	SetGlobalTransTarget(iClient);

	FormatEx(SZF(szBuffer), "[ %t ]\n ", "StatsInfo");
	hPanel.SetTitle(szBuffer);

	FormatEx(SZF(szBuffer), "%t\n ", "StatsInfoData");
	hPanel.DrawText(szBuffer);

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
