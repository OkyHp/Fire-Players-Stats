// Reset vars data for player
void ResetData(int iClient)
{
	g_iPlayerAccountID[iClient] = 0;
	g_iPlayerPosition[iClient] = 0;
	g_bStatsLoad[iClient] = false;
	g_fPlayerSessionPoints[iClient]	= g_fPlayerPoints[iClient] = DEFAULT_POINTS;
	for (int i = 0; i < sizeof(g_iPlayerData[]); ++i)
	{
		g_iPlayerSessionData[iClient][i] = g_iPlayerData[iClient][i] = 0;
	}

	#if USE_RANKS == 1
		g_iPlayerRanks[iClient] = 0;
		g_sRankName[iClient][0] = 0;
	#endif
}

// Weapons stats KV
bool JumpToWeapons(int iClient, const char[] szWeapon)
{
	if (!g_hWeaponsKV)
	{
		return false;
	}

	char szAccountID[32];
	IntToString(g_iPlayerAccountID[iClient], SZF(szAccountID));

	g_hWeaponsKV.Rewind();
	if (!g_hWeaponsKV.JumpToKey(szAccountID, true))
	{
		LogError("SetWeaponsStats: JumpToKey %s failed!", szAccountID);
		return false;
	}
	if (!g_hWeaponsKV.JumpToKey(szWeapon, true))
	{
		LogError("SetWeaponsStats: JumpToKey %s failed!", szWeapon);
		return false;
	}

	FPS_Debug("JumpToWeapons >> %N: %s -> %s", iClient, szAccountID, szWeapon)
		
	return true;
}

// Reset if less zero
void ResetIfLessZero(float fValue)
{
	if (fValue < 0.0)
	{
		fValue = 0.0;
	}
}

// Get steak points
float StreakPoints(int iClient)
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

// Fix name by Pheonix
char[] GetFixNamePlayer(int iClient)
{
	char sName[MAX_NAME_LENGTH * 2 + 1];
	GetClientName(iClient, sName, sizeof(sName));

	for(int i = 0, len = strlen(sName), CharBytes; i < len;)
	{
		if((CharBytes = GetCharBytes(sName[i])) >= 4)
		{
			len -= CharBytes;
			for(int u = i; u <= len; u++)
			{
				sName[u] = sName[u + CharBytes];
			}
		}
		else i += CharBytes;
	}
	return sName;
}

// Set extra points for killing weapons
float GetWeaponExtraPoints(const char[] szWeapon)
{
	if (g_hWeaponsConfigKV)
	{
		g_hWeaponsConfigKV.Rewind();
		if (g_hWeaponsConfigKV.JumpToKey("WeaponCoeff"))
		{
			float fExtPoints = g_hWeaponsConfigKV.GetFloat(szWeapon, 1.0);
			FPS_Debug("GetWeaponExtraPoints >> %s -> %f", szWeapon, fExtPoints)
			return fExtPoints;
		}
	}
	return 1.0;
}

#if USE_RANKS == 1
	// Check rank level
	void CheckRank(int iClient)
	{
		if (FPS_IsCalibration(iClient))
		{
			g_iPlayerRanks[iClient] = 0;
			FormatEx(g_sRankName[iClient], sizeof(g_sRankName[]), "%T", "Calibration", iClient);
			return;
		}

		if (g_hRanksConfigKV)
		{
			int iLevel;
			g_hRanksConfigKV.Rewind();
			if (g_hRanksConfigKV.GotoFirstSubKey(false))
			{
				do {
					if (g_fPlayerPoints[iClient] < g_hRanksConfigKV.GetFloat(NULL_STRING))
					{
						if (iLevel != g_iPlayerRanks[iClient])
						{
							FPS_PrintToChat(iClient, "%t", g_iPlayerRanks[iClient] ? (iLevel > g_iPlayerRanks[iClient] ? "RankUpped" : "RankDowned", g_sRankName[iClient]) : ("CalibrationCompleted", g_sRankName[iClient]));
							CallForward_OnFPSLevelChange(iClient, g_iPlayerRanks[iClient], iLevel);
							FPS_Debug("CheckRank Pre (New level) >> %N: %i", iClient, iLevel)

							g_iPlayerRanks[iClient] = iLevel;
							FPS_Debug("CheckRank >> %N: %i | %s", iClient, g_iPlayerRanks[iClient], g_sRankName[iClient])
						}
						return;
					}
					g_hRanksConfigKV.GetSectionName(g_sRankName[iClient], sizeof(g_sRankName[])); // ebaniy kostil
					++iLevel;
				} while (g_hRanksConfigKV.GotoNextKey(false));
			}
		}
	}
#endif

// Check grenade
bool IsGrenade(const char[] szWeapon)
{
	FPS_Debug("IsGrenade >> %s", szWeapon)
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
	FPS_Debug("IsKnife >> %s", szWeapon)
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
	if (g_bStatsLoad[iClient])
	{
		return true;
	}

	FPS_PrintToChat(iClient, "%t", "ErrorDataLoad");
	return false;
}
