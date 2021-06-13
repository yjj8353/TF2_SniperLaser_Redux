#include <sourcemod>	
#include <sdkhooks> 	// SDKHook_*
#include <tf2>			// TF*
#include <tf2_stocks>	// TF2_*

// Sourcemod 1.7 이상에서 새 구문을 강제 적용
#pragma newdecls required

ConVar g_cvarLaserEnabled;
ConVar g_cvarLaserRED;
ConVar g_cvarLaserBLU;

int g_iEyeProp[MAXPLAYERS + 1];
int g_iSniperDot[MAXPLAYERS + 1];
int g_iDotController[MAXPLAYERS + 1];



/****************************
	Sourcemod SDK Function
****************************/

public Plugin myinfo = {
	name 		= "[TF2] Sniper Laser Redux",
	author 		= "RetroTV",
	description = "Sniper rifles emit lasers redux",
	version 	= "0.1",
	url 		= ""
};

// 플러그인 시발점
public void OnPluginStart() {
	// CreateConVar(char[] name, char[] defaultValue, char[] description, int flags, boolean hasMin, float min, boolea hasMax, float max)
	g_cvarLaserEnabled = CreateConVar("sniperlaser_enabled", "1", "Sniper rifles emit lasers", _, true, 0.0, true, 1.0);
	g_cvarLaserRED 	   = CreateConVar("sniperlaser_color_red", "255 0 0", "Sniper laser color RED");
	g_cvarLaserBLU     = CreateConVar("sniperlaser_color_blu", "0 0 255", "Sniper laser color BLUE");
	
	// 클라이언트가 서버에 접속할 때마다 전역 변수를 세팅한다
	for (int i = 1; i <= MaxClients; i++) {
		OnClientPutInServer(i);
	}
}

// 클라이언트가 서버에 접속할 때, 동작하는 이벤트
public void OnClientPutInServer(int client) {
	
	// INVALID_ENT_REFERENCE: Entity 불일치를 확인하기 위한 값
	g_iEyeProp[client]       = INVALID_ENT_REFERENCE;
	g_iSniperDot[client]     = INVALID_ENT_REFERENCE;
	g_iDotController[client] = INVALID_ENT_REFERENCE;
}

// Entity가 생성될 때, 동작하는 이벤트
public void OnEntityCreated(int entity, const char[] classname) {
	if (g_cvarLaserEnabled.BoolValue && StrEqual(classname, "env_sniperdot")) {
		SDKHook(entity, SDKHook_SpawnPost, SpawnPost);
	}
}

// 서버 프레임마다 호출되는 이벤트
public void OnGameFrame() {
	for (int i = 1; i <= MaxClients; i++) 	{
		if(!IsClientInGame(i)) {
			continue;
		}
			
		int env_sniperdot = EntRefToEntIndex(g_iSniperDot[i]);
		int dotController = EntRefToEntIndex(g_iDotController[i]);
		
		if(env_sniperdot > 0 && dotController > 0) {
			float dotPos[3]; GetEntPropVector(env_sniperdot, Prop_Send, "m_vecOrigin", dotPos);
			DispatchKeyValueVector(dotController, "origin", dotPos);
		} else {
			if(env_sniperdot <= 0 && dotController > 0) {
				DispatchKeyValue(dotController, "origin", "99999 99999 99999");
				SetVariantString("OnUser1 !self:kill::0.1:1");
				AcceptEntityInput(dotController, "AddOutput");
				AcceptEntityInput(dotController, "FireUser1");
				
				g_iDotController[i] = INVALID_ENT_REFERENCE;
			}
		}
	}
}

/*******************
	User Function
*******************/

public Action SpawnPost(int entity) {
	
	// 다음 프레임 후킹
	RequestFrame(SetLaser, entity);	
}

public void SetLaser(int entity) {
	if (IsValidEntity(entity)) {
		int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		
		if(client > 0 && client <= MaxClients && IsClientInGame(client)) {
			if(GameRules_GetProp("m_bPlayingMannVsMachine") && TF2_GetClientTeam(client) != TFTeam_Red) {
				return;
			}
			
			float rgb[3];
			char strrgb[PLATFORM_MAX_PATH];
		
			switch(TF2_GetClientTeam(client)) {
				case TFTeam_Red:  g_cvarLaserRED.GetString(strrgb, PLATFORM_MAX_PATH);
				case TFTeam_Blue: g_cvarLaserBLU.GetString(strrgb, PLATFORM_MAX_PATH);
			}
			
			char rgbExploded[3][16];
			
			ExplodeString(strrgb, " ", rgbExploded, sizeof(rgbExploded), sizeof(rgbExploded[]));
			
			rgb[0] = StringToFloat(rgbExploded[0]);
			rgb[1] = StringToFloat(rgbExploded[1]);
			rgb[2] = StringToFloat(rgbExploded[2]);
			
			char name[PLATFORM_MAX_PATH];
			Format(name, PLATFORM_MAX_PATH, "laser_%i", entity);
		
			// color controls the color and is for color only.//
			int color = CreateEntityByName("info_particle_system");
			
			DispatchKeyValue(color, "targetname", name);
			DispatchKeyValueVector(color, "origin", rgb);
			DispatchSpawn(color);
			
			// Start of beam -> parented to client.
			int a = CreateEntityByName("info_particle_system");
			
			DispatchKeyValue(a, "effect_name", "laser_sight_beam");
			DispatchKeyValue(a, "cpoint2", name);
			DispatchSpawn(a);
			
			SetVariantString("!activator");
			AcceptEntityInput(a, "SetParent", client);
			
			SetVariantString("eyeglow_R");
			AcceptEntityInput(a, "SetParentAttachment", client);
			
			// Dot controller, set as controlpointent on beam
			int dotController = CreateEntityByName("info_particle_system");
			float dotPos[3];
			
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", dotPos);
			DispatchKeyValueVector(dotController, "origin", dotPos);
			DispatchSpawn(dotController);
			
			// Start of beam -> control point entity set to env_sniperdot
			SetEntPropEnt(a, Prop_Data, "m_hControlPointEnts", dotController);
			SetEntPropEnt(a, Prop_Send, "m_hControlPointEnts", dotController);
			
			ActivateEntity(a);
			AcceptEntityInput(a, "Start");
			
			SetVariantString("OnUser1 !self:kill::0.1:1");
			AcceptEntityInput(color, "AddOutput");
			AcceptEntityInput(color, "FireUser1");
			
			g_iEyeProp[client]       = EntIndexToEntRef(a);
			g_iSniperDot[client]     = EntIndexToEntRef(entity);
			g_iDotController[client] = EntIndexToEntRef(dotController);
			
			// 원본 레이저 도트 숨김
			SDKHook(entity, SDKHook_SetTransmit, OnDotTransmit);
		}
	}
}

public Action OnDotTransmit(int entity, int client) {
	return Plugin_Handled;
}

public void TF2_OnConditionRemoved(int client, TFCond condition) {
	if(TF2_GetPlayerClass(client) == TFClass_Sniper && condition == TFCond_Slowed) {		
		int iEyeProp = EntRefToEntIndex(g_iEyeProp[client])
		
		if(iEyeProp != INVALID_ENT_REFERENCE) {
			AcceptEntityInput(iEyeProp, "ClearParent");
			AcceptEntityInput(iEyeProp, "Stop");
			
			DispatchKeyValue(iEyeProp, "origin", "99999 99999 99999");
			
			SetVariantString("OnUser1 !self:kill::0.1:1");
			AcceptEntityInput(iEyeProp, "AddOutput");
			AcceptEntityInput(iEyeProp, "FireUser1");
			
			g_iEyeProp[client] = INVALID_ENT_REFERENCE;
		}
	}
}