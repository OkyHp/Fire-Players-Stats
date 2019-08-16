#if defined _fps_hint_info_included
 #endinput
#endif
#define _fps_hint_info_included

public SharedPlugin __pl_fps_hint_info= 
{
	name = "FPS_HintInfo",
	file = "FPS_HintInfo.smx",
	#if defined REQUIRE_PLUGIN
		required = 1
	#else
		required = 0
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_fps_hint_info_SetNTVOptional()
{
	MarkNativeAsOptional("FPS_HintInfo_GetState");
	MarkNativeAsOptional("FPS_HintInfo_SetState");
}
#endif

/**
 *	Получение статуса отображения хинта для игрока.
 *
 *	@param iClient		Индекс игрока.
 *	@return				true - Отображение включено.
 * 						false - Отображение выключено.
*/
native bool FPS_HintInfo_GetState(int iClient);

/**
 *	Установить статус отображения хинта для игрока.
 *
 *	@param iClient		Индекс игрока.
 *	@param bState		Устанавливаемый статус отображения.
 *	@noreturn
*/
native void FPS_HintInfo_SetState(int iClient, bool bState);
