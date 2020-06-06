#define HITGROUP_GENERIC	0
#define HITGROUP_HEAD		1
#define HITGROUP_CHEST		2
#define HITGROUP_STOMACH	3
#define HITGROUP_LEFTARM	4
#define HITGROUP_RIGHTARM	5
#define HITGROUP_LEFTLEG	6
#define HITGROUP_RIGHTLEG	7
#define HITGROUP_NECK		8
#define HITGROUP_GEAR		10

static int		iMaxRoundsKills[MAXPLAYERS+1];
static float	fRoundPlayerPoints[MAXPLAYERS+1];

void HookEvents()
{
	HookEvent("weapon_fire", 		Event_WeaponFire);
	HookEvent("player_hurt", 		Event_PlayerHurt);
	HookEvent("player_death", 		Event_PlayerDeath);
	HookEvent("player_spawn",		Event_PlayerSpawn);

	HookEvent("round_prestart",		Event_RoundAction, EventHookMode_PostNoCopy);
	HookEvent("round_mvp",			Event_RoundAction);
	HookEvent("round_end",			Event_RoundAction);

	HookEvent("bomb_planted",		Event_OtherAction);
	HookEvent("bomb_defused",		Event_OtherAction);
	HookEvent("bomb_dropped",		Event_OtherAction);
	HookEvent("bomb_pickup",		Event_OtherAction);
	HookEvent("hostage_killed",		Event_OtherAction);
	HookEvent("hostage_rescued",	Event_OtherAction);
}

void Event_WeaponFire(Event hEvent, const char[] sEvName, bool bDontBroadcast)
{
	if (g_bStatsActive)
	{
		int iClient = CID(hEvent.GetInt("userid"));
		if (!iClient || !g_bStatsLoad[iClient] || !g_hWeaponsData[iClient])
		{
			return;
		}

		char szWeapon[32];
		hEvent.GetString("weapon", SZF(szWeapon));
		if (!IsGrenade(szWeapon[7]))
		{
			if (IsKnife(szWeapon[7]))
			{
				szWeapon = "weapon_knife";
			}
			FPS_Debug("----->> Event_WeaponFire >>----- %s", szWeapon[7])
			WriteWeaponData(iClient, szWeapon[7], W_SHOOTS);
		}
	}
}

void Event_PlayerHurt(Event hEvent, const char[] sEvName, bool bDontBroadcast)
{
	if (g_bStatsActive)
	{
		int iAttacker = CID(hEvent.GetInt("attacker"));
		if (!iAttacker || CID(hEvent.GetInt("userid")) == iAttacker || !g_bStatsLoad[iAttacker] || !g_hWeaponsData[iAttacker])
		{
			return;
		}

		char szWeapon[32];
		hEvent.GetString("weapon", SZF(szWeapon));
		if (!IsGrenade(szWeapon))
		{
			if (!IsKnife(szWeapon))
			{
				GetClientWeapon(iAttacker, SZF(szWeapon));
			}
			else
			{
				szWeapon = "weapon_knife";
			}
			FPS_Debug("----->> Event_PlayerHurt >>----- %s", szWeapon[7])

			int iHitgroup = hEvent.GetInt("hitgroup");
			if (iHitgroup != HITGROUP_GENERIC && iHitgroup != HITGROUP_GEAR)
			{
				int iHits;
				switch(iHitgroup)
				{
					case HITGROUP_HEAD:		iHits = W_HITS_HEAD;
					case HITGROUP_NECK:		iHits = W_HITS_NECK;
					case HITGROUP_CHEST:	iHits = W_HITS_CHEST;
					case HITGROUP_STOMACH:	iHits = W_HITS_STOMACH;
					case HITGROUP_LEFTARM:	iHits = W_HITS_LEFT_ARM;
					case HITGROUP_RIGHTARM:	iHits = W_HITS_RIGHT_ARM;
					case HITGROUP_LEFTLEG:	iHits = W_HITS_LEFT_LEG;
					case HITGROUP_RIGHTLEG:	iHits = W_HITS_RIGHT_LEG;
				}
				WriteWeaponData(iAttacker, szWeapon[7], iHits);
			}
		}
	}
}

void Event_PlayerDeath(Event hEvent, const char[] sEvName, bool bDontBroadcast)
{
	if (g_bStatsActive)
	{
		if (g_fExtraPoints[CFG_ASSIST])
		{
			int iAssister = CID(hEvent.GetInt("assister"));
			if (iAssister && g_bStatsLoad[iAssister])
			{
				g_iPlayerData[iAssister][ASSISTS]++;
				g_fPlayerPoints[iAssister] += g_fExtraPoints[CFG_ASSIST];
				CheckRank(iAssister);
			}
		}

		int iVictim = CID(hEvent.GetInt("userid")),
			iAttacker = CID(hEvent.GetInt("attacker"));
		if (!iVictim || !iAttacker || !g_bStatsLoad[iVictim] || !g_bStatsLoad[iAttacker])
		{
			return;
		}

		if (iVictim != iAttacker)
		{
			if(!g_bTeammatesAreEnemies && g_fExtraPoints[CFG_TEAMKILL] && GetClientTeam(iAttacker) == GetClientTeam(iVictim))
			{
				g_fPlayerPoints[iAttacker] += g_fExtraPoints[CFG_TEAMKILL];
				CheckRank(iAttacker);
				FPS_Debug("Event_PlayerDeath >> TeamKill >> Attacker: %f", g_fPlayerPoints[iAttacker])
				return;
			}

			iMaxRoundsKills[iAttacker]++;
			g_iPlayerData[iAttacker][KILLS]++;
			g_iPlayerData[iVictim][DEATHS]++;

			char	szWeapon[32];
			hEvent.GetString("weapon", SZF(szWeapon));
			bool	bHeadshot = hEvent.GetBool("headshot"),
					bIsGrenade = IsGrenade(szWeapon);

			if (g_hWeaponsData[iAttacker] && !bIsGrenade)
			{
				if (IsKnife(szWeapon))
				{
					szWeapon = "knife";
				}

				WriteWeaponData(iAttacker, szWeapon, W_KILLS);
				if (bHeadshot)
				{
					WriteWeaponData(iAttacker, szWeapon, W_HEADSHOTS, true);
				}

				FPS_Debug("Event_Death >> Weapon: %s >> HS: %i", szWeapon, bHeadshot)
			}

			float	fPointsAttacker	= (g_fPlayerPoints[iVictim] / g_fPlayerPoints[iAttacker]) * 5.0,
					fDiff			= (g_fPlayerPoints[iAttacker] / g_fPlayerPoints[iVictim]) + 0.6,
					fPointsVictim	= fPointsAttacker * g_fCoeff * (fDiff < 1.0 && FPS_IsCalibration(iAttacker) ? fDiff : 1.0),
					fExtPoints		= GetWeaponExtraPoints(szWeapon, bIsGrenade),
					fHeadshot		= bHeadshot ? g_fExtraPoints[CFG_HEADSHOT] : 0.0,
					fStreak;

			#if USE_STREAK_POINTS == 1
				fStreak = StreakPoints(iAttacker);
			#endif

			fPointsAttacker	= (fPointsAttacker * fExtPoints) + fHeadshot + fStreak;
			FPS_Debug("Event_PlayerDeath >> Points Data: \n ----->> EP: %f \n ----->> HS: %f \n ----->> ST: %f \n ----->> DF: %f", fExtPoints, fHeadshot, fStreak, fDiff)
			FPS_Debug("Event_PlayerDeath >> Points >> Attacker (%N): %f / Victim (%N): %f", iAttacker, fPointsAttacker, iVictim, fPointsVictim)

			ResetIfLessZero(fPointsAttacker);
			ResetIfLessZero(fPointsVictim);

			float	fAddPointsAttacker = fPointsAttacker,
					fAddPointsVictim = fPointsVictim;
			switch(CallForward_OnFPSPointsChangePre(iAttacker, iVictim, hEvent, fAddPointsAttacker, fAddPointsVictim))
			{
				case Plugin_Continue:
				{
					g_fPlayerPoints[iAttacker] += fPointsAttacker;
					g_fPlayerPoints[iVictim] -= fPointsVictim;
				}
				case Plugin_Changed:
				{
					g_fPlayerPoints[iAttacker] += fAddPointsAttacker;
					g_fPlayerPoints[iVictim] -= fAddPointsVictim;
					FPS_Debug("Event_PlayerDeath >> Points Pre Changed >> Attacker (%N): %f / Victim (%N): %f", iAttacker, fAddPointsAttacker, iVictim, fAddPointsVictim)
				}
				default:
				{
					return;
				}
			}

			CheckRank(iAttacker);
			CheckRank(iVictim);

			CallForward_OnFPSPointsChange(iAttacker, iVictim, g_fPlayerPoints[iAttacker], g_fPlayerPoints[iVictim]);
		}
		else
		{
			g_fPlayerPoints[iVictim] += g_fExtraPoints[CFG_SUICIDE];
		}

		if (g_iInfoMessage == 2)
		{
			float fPoints = g_fPlayerPoints[iVictim] - fRoundPlayerPoints[iVictim];
			FPS_PrintToChat(iVictim, "%t [ %t ]", "PrintPoints", g_fPlayerPoints[iVictim], fPoints > 0.0 ? "ResultOfLifetimePositive" : "ResultOfLifetimeNegative", fPoints);
		}
	}
}

void Event_PlayerSpawn(Event hEvent, const char[] sEvName, bool bDontBroadcast)
{
	if (g_bStatsActive)
	{
		int iClient = CID(hEvent.GetInt("userid"));
		if (iClient)
		{
			fRoundPlayerPoints[iClient] = g_fPlayerPoints[iClient];
		}
	}
}

void Event_RoundAction(Event hEvent, const char[] sEvName, bool bDontBroadcast)
{
	switch(sEvName[6])
	{
		case 'p':
		{
			if (g_bBlockStatsOnWarmup && GameRules_GetProp("m_bWarmupPeriod"))
			{
				FPS_PrintToChatAll("%t", "StatsWarmupBlocked");
				g_bStatsActive = false;
				return;
			}

			if (g_bDisableStatisPerRound)
			{
				g_bStatsActive = false;
				g_bDisableStatisPerRound = false;
				return;
			}
			
			int iPlayers;
			for (int i = MaxClients + 1; --i;)
			{
				if (g_bStatsLoad[i])
				{
					iMaxRoundsKills[i] = 0;
					if (GetClientTeam(i) > 1)
					{
						++iPlayers;
						g_iPlayerSessionData[i][MAX_ROUNDS_KILLS] = 1;
					}
				}
			}

			if (g_iGameType[0] == 1 && g_iGameType[1] == 2)
			{
				g_bStatsActive = true;
				FPS_Debug("Event_RoundAction (s) >> DM >> true")
				return;
			}

			g_bStatsActive = (iPlayers >= g_iMinPlayers);
			if (!g_bStatsActive)
			{
				FPS_PrintToChatAll("%t", "NoPlayersForStatsWork", g_iMinPlayers);
			}

			FPS_Debug("Event_RoundAction (s) >> Stats %s", g_bStatsActive ? "ON" : "OFF")
		}
		case 'm':
		{
			if (g_bStatsActive && g_fExtraPoints[CFG_MVP_PLAYER])
			{
				int iClient = CID(hEvent.GetInt("userid"));
				if (iClient && g_bStatsLoad[iClient])
				{
					g_fPlayerPoints[iClient] += g_fExtraPoints[CFG_MVP_PLAYER];
					CheckRank(iClient);
				}

				FPS_Debug("Event_RoundAction (m) >> MVP: %N", iClient)
			}
		}
		case 'e':
		{
			if (g_bStatsActive && g_iGameType[0] != 1 && g_iGameType[1] != 2 && GameRules_GetProp("m_totalRoundsPlayed"))
			{
				g_bStatsActive = false;

				static int iSave;
				bool bSave = g_iSaveInterval ? !(++iSave%g_iSaveInterval) : false;
				int iTeam, iWinTeam = GetEventInt(hEvent, "winner");

				for (int i = MaxClients + 1; --i;)
				{
					if (g_bStatsLoad[i] && g_iPlayerSessionData[i][MAX_ROUNDS_KILLS] == 1 && (iTeam = GetClientTeam(i)) > 1)
					{
						if (iMaxRoundsKills[i] > g_iPlayerData[i][MAX_ROUNDS_KILLS])
						{
							g_iPlayerData[i][MAX_ROUNDS_KILLS] = iMaxRoundsKills[i];
						}

						if (iWinTeam > 1)
						{
							if (iTeam == iWinTeam)
							{
								g_iPlayerData[i][ROUND_WIN]++;
								g_fPlayerPoints[i] += g_fExtraPoints[CFG_WIN_ROUND];
								if (g_iInfoMessage == 2)
								{
									FPS_PrintToChat(i, "%t [ %t ]", "AdditionalPointsPositive", g_fExtraPoints[CFG_WIN_ROUND], "WinRound");
								}
							}
							else
							{
								g_iPlayerData[i][ROUND_LOSE]++;
								g_fPlayerPoints[i] += g_fExtraPoints[CFG_LOSE_ROUND];
								if (g_iInfoMessage == 2)
								{
									FPS_PrintToChat(i, "%t [ %t ]", "AdditionalPointsNegative", -g_fExtraPoints[CFG_LOSE_ROUND], "LoseRound");
								}
							}
							
							CheckRank(i);
						}

						if (g_iInfoMessage == 1)
						{
							float fPoints = g_fPlayerPoints[i] - fRoundPlayerPoints[i];
							FPS_PrintToChat(i, "%t [ %t ]", "PrintPoints", g_fPlayerPoints[i], fPoints > 0.0 ? "ResultOfRoundPositive" : "ResultOfRoundNegative", fPoints);
						}

						if (bSave)
						{
							FPS_Debug("Call Save Function >> %N | %i", i, iSave)
							SavePlayerData(i);
						}
					}
				}

				if (bSave)
				{
					LoadTopData();
					for (int i = MaxClients + 1; --i;)
					{
						if (g_bStatsLoad[i])
						{
							GetPlayerPosition(i);
						}
					}
					CallForward_OnFPSSecondDataUpdated();
				}

				FPS_Debug("Event_RoundAction (e) >> ----------------")
			}
		}
	}
}

void Event_OtherAction(Event hEvent, const char[] sEvName, bool bDontBroadcast)
{
	if (g_bStatsActive)
	{
		int iClient = CID(hEvent.GetInt("userid"));
		if (!iClient || !g_bStatsLoad[iClient])
		{
			return;
		}

		switch(sEvName[9])
		{
			case 't': g_fPlayerPoints[iClient] += g_fExtraPoints[CFG_BOMB_PLANTED];
			case 's': g_fPlayerPoints[iClient] += g_fExtraPoints[CFG_BOMB_DEFUSED];
			case 'p': g_fPlayerPoints[iClient] += g_fExtraPoints[CFG_BOMB_DROPPED];
			case 'u': g_fPlayerPoints[iClient] += g_fExtraPoints[CFG_BOMB_PICK_UP];
			case 'i': g_fPlayerPoints[iClient] += g_fExtraPoints[CFG_HOSTAGE_KILLED];
			case 'e': g_fPlayerPoints[iClient] += g_fExtraPoints[CFG_HOSTAGE_RESCUED];
		}

		CheckRank(iClient);
		FPS_Debug("Event_OtherAction >> %s", sEvName)
	}
}
