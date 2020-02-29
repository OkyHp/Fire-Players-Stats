// Reset vars data for player
void ResetData(int iClient, bool bResetStats = false)
{
	int iLen = sizeof(g_iPlayerData[]);
	if (!bResetStats)
	{
		g_iPlayerAccountID[iClient] = 0;
		g_bStatsLoad[iClient] = false;
	}
	else
	{
		iLen--;
	}

	g_iPlayerPosition[iClient] = 0;
	g_fPlayerSessionPoints[iClient]	= g_fPlayerPoints[iClient] = DEFAULT_POINTS;
	for (int i = 0; i < iLen; ++i)
	{
		g_iPlayerSessionData[iClient][i] = g_iPlayerData[iClient][i] = 0;
	}

	g_iPlayerRanks[iClient] = 0;
	g_sRankName[iClient][0] = 0;
}

// Weapons stats
void WriteWeaponData(int iClient, char[] szWeapon, int iData, bool bLast = false)
{
	if (g_hWeaponsData[iClient])
	{
		static int iIndex;
		if (!bLast && !(iIndex = g_hWeaponsData[iClient].FindString(szWeapon) + 1))
		{
			FPS_Debug("WriteWeaponData >> %N >> Weapon '%s' added in array.", iClient, szWeapon)
			g_hWeaponsData[iClient].PushString(szWeapon);

			int iArray[W_SIZE];
			iArray[iData]++;
			g_hWeaponsData[iClient].PushArray(SZF(iArray));
			return;
		}

		if (iIndex)
		{
			FPS_Debug("WriteWeaponData >> %N >> (bLast: %i) Weapon '%s' finded >> Index: %i >> Source: %i", iClient, bLast, szWeapon, iIndex, g_hWeaponsData[iClient].Get(iIndex))
			g_hWeaponsData[iClient].Set(iIndex, (g_hWeaponsData[iClient].Get(iIndex) + 1), iData);
		}
	}
}

// Reset if less zero
void ResetIfLessZero(float &fValue)
{
	if (fValue < 0.0)
	{
		fValue = 0.0;
	}
}

// Get steak points
stock float StreakPoints(int iClient)
{
	static int iStrick[MAXPLAYERS+1][2];
	int iTime = GetTime();
	if (iTime <= iStrick[iClient][1] + 10)
	{
		if (iStrick[iClient][0] < 5)
		{
			iStrick[iClient][0]++;
		}
		
		FPS_Debug("StreakPoints >> %N: #%i %f", iClient, iStrick[iClient][0], g_fExtraPoints[iStrick[iClient][0] + 12])

		return g_fExtraPoints[iStrick[iClient][0] + 12];
	}

	iStrick[iClient][0] = 0;
	iStrick[iClient][1] = iTime;
	return 0.0;
}

// Set extra points for killing weapons
float GetWeaponExtraPoints(const char[] szWeapon, bool bIsGrenade)
{
	if (g_hWeaponsConfigKV && !bIsGrenade)
	{
		g_hWeaponsConfigKV.Rewind();
		if (g_hWeaponsConfigKV.JumpToKey("WeaponCoeff") && ( g_hWeaponsConfigKV.JumpToKey(g_sMap) || g_hWeaponsConfigKV.JumpToKey("default") ))
		{
			float fExtPoints = g_hWeaponsConfigKV.GetFloat(szWeapon, 1.0);
			FPS_Debug("GetWeaponExtraPoints >> %s -> %f", szWeapon, fExtPoints)
			return fExtPoints;
		}
	}
	return 1.0;
}

// Check rank level
void CheckRank(int iClient)
{
	if (FPS_IsCalibration(iClient))
	{
		g_iPlayerRanks[iClient] = 0;
		g_sRankName[iClient] = "Calibration";
		return;
	}

	if (g_hRanks)
	{
		int		iSize = g_hRanks.Length,
				iLevel = g_iRanksCount;
		for (int i = 0; i < iSize; i += 2)
		{
			if (g_hRanks.Get(i) <= g_fPlayerPoints[iClient])
			{
				if (iLevel == g_iPlayerRanks[iClient])
				{
					return;
				}

				g_hRanks.GetString(i+1, g_sRankName[iClient], sizeof(g_sRankName[]));
				
				if (g_iPlayerSessionData[iClient][MAX_ROUNDS_KILLS])
				{
					FPS_PrintToChat(iClient, "%t", g_iPlayerRanks[iClient] ? (iLevel > g_iPlayerRanks[iClient] ? "RankUpped" : "RankDowned") : "CalibrationCompleted", FindTranslationRank(iClient, g_sRankName[iClient]));
					CallForward_OnFPSLevelChange(iClient, g_iPlayerRanks[iClient], iLevel);
				}

				g_iPlayerRanks[iClient] = iLevel;
				FPS_Debug("CheckRank >> %N >> Old lvl: %i | New lvl: %i | Rank name: %s", iClient, (g_iPlayerRanks[iClient] - 1), g_iPlayerRanks[iClient], g_sRankName[iClient])
				return;
			}
			--iLevel;
		}
	}
}

// Check grenade
bool IsGrenade(const char[] szWeapon)
{
	// FPS_Debug("IsGrenade >> %s", szWeapon)
	return (szWeapon[0] == 'i' // inferno + incgrenade
			|| szWeapon[4] == 'y' // decoy
			|| (szWeapon[0] == 'h' && szWeapon[1] == 'e') // hegrenade + healthshot
			|| (szWeapon[0] == 'f' && szWeapon[1] == 'l') // flashbang
			|| (szWeapon[0] == 'm' && szWeapon[1] == 'o') // molotov
			|| (szWeapon[0] == 's' && szWeapon[1] == 'm') // smokegren
			|| (szWeapon[0] == 't' && szWeapon[2] == 'g') // tagrenade
		);
}

// Check knife
bool IsKnife(const char[] szWeapon)
{
	// FPS_Debug("IsKnife >> %s", szWeapon)
	return (szWeapon[0] == 'k' || szWeapon[2] == 'y');
}

// Play menu sounds
void PlayItemSelectSound(int iClient, bool bClose)
{
	ClientCommand(iClient, bClose ? "playgamesound *buttons/combine_button7.wav" : "playgamesound *buttons/button14.wav");
}

// Print message on load data status
bool IsPlayerLoaded(int iClient)
{
	if (iClient)
	{
		if (g_bStatsLoad[iClient])
		{
			return true;
		}

		FPS_PrintToChat(iClient, "%t", "ErrorDataLoad");
	}
	return false;
}

void GetCurrentMapEx(char[] szMapBuffer, int iSize)
{
	char szBuffer[256];
	GetCurrentMap(szBuffer, sizeof szBuffer);
	int iIndex = -1, iLen = strlen(szBuffer);
	
	for(int i = 0; i < iLen; i++)
	{
		if(FindCharInString(szBuffer[i], '/') != -1 || FindCharInString(szBuffer[i], '\\') != -1)
		{
			if(i != iLen - 1)
			{
				iIndex = i;
			}
			continue;
		}
		break;
	}

	strcopy(szMapBuffer, iSize, szBuffer[iIndex+1]);
}

void AddFeatureItemToMenu(Menu hMenu, FeatureMenus eType)
{
	int 	iSize = g_hItems.Length;
	char	szBuffer[128];
	for (int i = 0; i < iSize; i += F_COUNT)
	{
		if (g_hItems.Get(i + F_MENU_TYPE) == view_as<int>(eType))
		{
			g_hItems.GetString(i, SZF(szBuffer));
			hMenu.AddItem(szBuffer, szBuffer);
			FPS_Debug("AddFeatureItemToMenu >> F_TYPE: %i >> F: %s", eType, szBuffer)
		}
	}
}

int FeatureHandler(Menu hMenu, MenuAction action, int iClient, int iItem, FeatureMenus eType)
{
	static char szItem[128];
	
	if (hMenu)
	{
		hMenu.GetItem(iItem, SZF(szItem));
		if (!szItem[0] || szItem[0] == '>')
		{
			return 0;
		}

		int iIndex = g_hItems.FindString(szItem);
		if (iIndex != -1)
		{
			static Function Func;
			switch(action)
			{
				case MenuAction_Select:
				{
					Func = g_hItems.Get(iIndex + F_SELECT);
					if (Func != INVALID_FUNCTION)
					{
						bool bResult;
						Call_StartFunction(g_hItems.Get(iIndex + F_PLUGIN), Func);
						Call_PushCell(iClient);
						Call_Finish(bResult);

						if(bResult)
						{
							switch(eType)
							{
								case FPS_STATS_MENU:	ShowMainStatsMenu(iClient,		GetMenuSelectionPosition());
								case FPS_TOP_MENU:		ShowMainTopMenu(iClient,		GetMenuSelectionPosition());
								case FPS_ADVANCED_MENU:	ShowMainAdditionalMenu(iClient,	GetMenuSelectionPosition());
							}
						}
					}
				}
				case MenuAction_DisplayItem:
				{
					Func = g_hItems.Get(iIndex + F_DISPLAY);
					if (Func != INVALID_FUNCTION)
					{
						bool bResult;
						Call_StartFunction(g_hItems.Get(iIndex + F_PLUGIN), Func);
						Call_PushCell(iClient);
						Call_PushStringEx(SZF(szItem), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
						Call_PushCell(sizeof(szItem));
						Call_Finish(bResult);

						if(bResult)
						{
							return RedrawMenuItem(szItem);
						}
					}
				}
				case MenuAction_DrawItem:
				{
					Func = g_hItems.Get(iIndex + F_DRAW);
					if (Func != INVALID_FUNCTION)
					{
						int iStyle;
						hMenu.GetItem(iItem, "", 0, iStyle);

						Call_StartFunction(g_hItems.Get(iIndex + F_PLUGIN), Func);
						Call_PushCell(iClient);
						Call_PushCell(iStyle);
						Call_Finish(iStyle);

						return iStyle;
					}
				}
			}
		}
	}
	return 0;
}

// Get auto server id
// void GetAutoServerID()
// {
// 	if (!g_iServerID)
// 	{
// 		g_iServerID = GetServerSteamAccountId();
// 		FPS_Debug("GetAutoServerID >> %i", g_iServerID)
// 	}
// }
