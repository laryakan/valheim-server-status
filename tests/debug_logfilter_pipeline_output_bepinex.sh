#!/bin/bash
set -u

cd "$(dirname "$0")/.."
source .env.test
export DEBUGMODE=1

# Idempotence
rm -f "$CONNECTEDPLAYERSFILE" "$OFFLINEPLAYERSFILE" "$STEAMIDMAPFILE" "$LASTWORLDSAVEFILE"

# Colors
red='\e[31m'
green='\e[32m'
yellow='\e[93m'
clear='\e[0m'
ColorRed(){
	echo -ne $red$1$clear
}
ColorGreen(){
	echo -ne $green$1$clear
}
ColorYellow(){
	echo -ne $yellow$1$clear
}

echo -e "\n---\n\n$(ColorYellow 'Testing log filter pipeline output: Version detection (1 output expected)') :"

printf '%s\n' \
"[Info   : Unity Log] 09/18/2026 09:48:28: SaveSystem.Reload for World is done [97ms]" \
"[Info   : Unity Log] 09/18/2026 09:48:28: Setting world modifier preset: normal" \
"[Info   : Unity Log] 09/18/2026 09:48:28: Setting world modifier: combat->hard" \
"[Info   : Unity Log] 09/18/2026 09:48:28: Using environment steamid 892970" \
"[Info   : Unity Log] 09/18/2026 09:48:28: Using steam APPID:892970" \
"[Info   : Unity Log] 09/18/2026 09:48:28: Server ID 90071992547409920" \
"[Info   : Unity Log] 09/18/2026 09:48:28: Authentication:k_ESteamNetworkingAvailability_Waiting" \
"[Info   : Unity Log] 09/18/2026 09:48:28: Steam game server initialized" \
"[Info   : Unity Log] 09/18/2026 09:48:28: Valheim version: l-1.0.14 (network version 40)" \
"[Info   : Unity Log] 09/18/2026 09:48:28: Worldgenerator version setup:2" \
"[Info   : Unity Log] 09/18/2026 09:48:28: Console: Valheim l-1.0.14 (network version 40)" \
"[Info   : Unity Log] 09/18/2026 09:48:28: Console:" \
"[Info   : Unity Log] 09/18/2026 09:48:28: Console: type \"help\" - for commands" \
"[Info   : Unity Log] 09/18/2026 09:48:28: Console:" \
"[Info   : Unity Log] 09/18/2026 09:48:28: Render threading mode:SingleThreaded" \
"[Warning: Unity Log] [AmplifyOcclusion] System does not support CopyTexture. CacheAware will be disabled." \
| ./vss.log-filter

echo -e "\n---\n\n$(ColorYellow 'Testing log filter pipeline output: Bepinex Version detection (1 output expected)') :"

printf '%s\n' \
"[Info   : Unity Log] 09/18/2026 09:55:05: Stopping build thread" \
"[Message:   BepInEx] BepInEx 5.4.23.5 - valheim_server (07/09/2026 23:14:40)" \
"[Info   :   BepInEx] Running under Unity vUnknown (post-2017)" \
"[Info   :   BepInEx] CLR runtime version: 4.0.30319.42000" \
"[Info   :   BepInEx] Supports SRE: True" \
"[Info   :   BepInEx] System platform: Bits64, Linux" \
"[Message:   BepInEx] Preloader started" \
"[Info   :   BepInEx] Loaded 1 patcher method from [BepInEx.Preloader 5.4.23.5]" \
"[Info   :   BepInEx] 1 patcher plugin loaded" \
"[Info   :   BepInEx] Patching [UnityEngine.CoreModule] with [BepInEx.Chainloader]" \
"[Message:   BepInEx] Preloader finished" \
"[Info   :   BepInEx] Detected Unity version: v6000.0.75f1" \
"[Message:   BepInEx] Chainloader ready" \
"[Message:   BepInEx] Chainloader started" \
"[Info   :   BepInEx] 0 plugins to load" \
"[Message:   BepInEx] Chainloader startup complete" \
"[Info   : Unity Log] 09/18/2026 10:00:13: Set background loading budget to Low" \
| ./vss.log-filter

echo -e "\n---\n\n$(ColorYellow 'Testing log filter pipeline output: Save detection (1 output expected)') :"

printf '%s\n' \
"[Info   : Unity Log] 09/10/2026 19:48:14: ### Save World Thread Started! ###" \
"[Info   : Unity Log] 09/10/2026 19:48:14: Considering autobackup for World. World time: 8988,277, short time: 7200, long time: 43200, backup count: 2" \
"[Info   : Unity Log] 09/10/2026 19:48:14: SaveSystem.Reload for World is done [9ms]" \
"[Info   : Unity Log] 09/10/2026 19:48:14: No autobackup needed yet..." \
"[Info   : Unity Log] 09/10/2026 19:48:14: World save (1/5) Cloud & Backup checks done [0ms] => Save number 47" \
"[Info   : Unity Log] 09/10/2026 19:48:15: World save (2/5) Chunks writing done [275ms]" \
"[Info   : Unity Log] 09/10/2026 19:48:15: World save (3/5) DB2 writing done [29ms]" \
"[Info   : Unity Log] 09/10/2026 19:48:15: World save (4/5) FWL writing done [1ms]" \
"[Info   : Unity Log] 09/10/2026 19:48:15: World save (5/5) done. Total time [319ms]" \
"[Info   : Unity Log] 09/10/2026 19:48:26: Connections 0 ZDOS:44844 sent:0 recv:0" \
"[Info   : Unity Log] 09/10/2026 19:58:26: Connections 0 ZDOS:44844 sent:0 recv:0" \
| ./vss.log-filter

echo -e "\n---\n\n$(ColorYellow 'Testing log filter pipeline output: First connection detection (1 steamid and 1 json output expected with event \"first_join\")') :"
echo "" > "$CONNECTEDPLAYERSFILE"
echo "" > "$STEAMIDMAPFILE"

printf '%s\n' \
"[Info   : Unity Log] 09/10/2026 12:17:48: Connections 0 ZDOS:44824 sent:0 recv:0" \
"[Info   : Unity Log] 09/10/2026 12:22:15: Got status changed msg k_ESteamNetworkingConnectionState_Connecting" \
"[Info   : Unity Log] 09/10/2026 12:22:15: New connection" \
"[Info   : Unity Log] 09/10/2026 12:22:47: Got character ZDOID from Laryakan : 328410070:35" \
"[Info   : Unity Log] 09/10/2026 12:22:15: Accepting connection k_EResultOK" \
"[Info   : Unity Log] 09/10/2026 12:22:15: Connecting to Steamworks.SteamNetworkingIdentity" \
"[Info   : Unity Log] 09/10/2026 12:22:15: Got status changed msg k_ESteamNetworkingConnectionState_Connected" \
"[Info   : Unity Log] 09/10/2026 12:22:15: Connected" \
"[Info   : Unity Log] 09/10/2026 12:22:15: Got connection SteamID 76561190000000" \
"[Info   : Unity Log] 09/10/2026 12:22:15: Got handshake from client 76561190000000" \
"[Info   : Unity Log] 09/10/2026 12:22:24: Network version check, their:39, mine:39" \
"[Info   : Unity Log] 09/10/2026 12:22:24: Checking for any blocked players in the historical player list..." \
"[Info   : Unity Log] 09/10/2026 12:22:24: Server: New peer connected,sending global keys" \
"[Info   : Unity Log] 09/10/2026 12:22:24: Checking for any blocked players in the historical player list..." \
"[Info   : Unity Log] 09/10/2026 12:22:42: Checking for any blocked players in the historical player list..." \
"[Info   : Unity Log] 09/10/2026 12:22:47: Got character ZDOID from Laryakan : 2569070:4" \
"[Info   : Unity Log] 09/10/2026 12:22:47: Got character ZDOID from Laryakan : 328410070:1" \
"[Info   : Unity Log] 09/10/2026 12:27:48: Unloading unused assets" \
"[Info   : Unity Log] Unloading 0 Unused Serialized files (Serialized files now loaded: 20)" \
"[Info   : Unity Log] 09/10/2026 12:27:48: Connections 1 ZDOS:44824 sent:0 recv:274" \
| ./vss.log-filter

echo -e "\n---\n\n$(ColorYellow 'Testing log filter pipeline output: Connection detection (1 steamid 1 json output expected with \"connected\")') :"
echo "" > "$CONNECTEDPLAYERSFILE"
echo "76561190000000;Laryakan" > "$STEAMIDMAPFILE"

printf '%s\n' \
"[Info   : Unity Log] 09/10/2026 12:17:48: Connections 0 ZDOS:44824 sent:0 recv:0" \
"[Info   : Unity Log] 09/10/2026 12:22:15: Got status changed msg k_ESteamNetworkingConnectionState_Connecting" \
"[Info   : Unity Log] 09/10/2026 12:22:15: New connection" \
"[Info   : Unity Log] 09/10/2026 12:22:47: Got character ZDOID from Laryakan : 328410070:35" \
"[Info   : Unity Log] 09/10/2026 12:22:15: Accepting connection k_EResultOK" \
"[Info   : Unity Log] 09/10/2026 12:22:15: Connecting to Steamworks.SteamNetworkingIdentity" \
"[Info   : Unity Log] 09/10/2026 12:22:15: Got status changed msg k_ESteamNetworkingConnectionState_Connected" \
"[Info   : Unity Log] 09/10/2026 12:22:15: Connected" \
"[Info   : Unity Log] 09/10/2026 12:22:15: Got connection SteamID 76561190000000" \
"[Info   : Unity Log] 09/10/2026 12:22:15: Got handshake from client 76561190000000" \
"[Info   : Unity Log] 09/10/2026 12:22:24: Network version check, their:39, mine:39" \
"[Info   : Unity Log] 09/10/2026 12:22:24: Checking for any blocked players in the historical player list..." \
"[Info   : Unity Log] 09/10/2026 12:22:24: Server: New peer connected,sending global keys" \
"[Info   : Unity Log] 09/10/2026 12:22:24: Checking for any blocked players in the historical player list..." \
"[Info   : Unity Log] 09/10/2026 12:22:42: Checking for any blocked players in the historical player list..." \
"[Info   : Unity Log] 09/10/2026 12:22:47: Got character ZDOID from Laryakan : 328410070:1" \
"[Info   : Unity Log] 09/10/2026 12:27:48: Unloading unused assets" \
"[Info   : Unity Log] Unloading 0 Unused Serialized files (Serialized files now loaded: 20)" \
"[Info   : Unity Log] 09/10/2026 12:27:48: Connections 1 ZDOS:44824 sent:0 recv:274" \
| ./vss.log-filter

echo -e "\n---\n\n$(ColorYellow 'Testing log filter pipeline output: Disconnect detection (1 json output expected)') :"

# To test this, we have to fake a previous connection, because the disconnect detection only works if the player is already known to be connected.
echo "2026-09-10.20:38:21;Laryakan;-106309146:1" > "$CONNECTEDPLAYERSFILE"

printf '%s\n' \
"[Info   : Unity Log] 09/10/2026 19:34:37: Got status changed msg k_ESteamNetworkingConnectionState_Connected" \
"[Info   : Unity Log] 09/10/2026 19:34:37: Connected" \
"[Info   : Unity Log] 09/10/2026 19:34:37: Got connection SteamID 76561190000000" \
"[Info   : Unity Log] 09/10/2026 19:34:37: Got handshake from client 76561190000000" \
"[Info   : Unity Log] 09/10/2026 19:34:39: Network version check, their:39, mine:39" \
"[Info   : Unity Log] 09/10/2026 19:34:39: Checking for any blocked players in the historical player list..." \
"[Info   : Unity Log] 09/10/2026 19:34:39: Server: New peer connected,sending global keys" \
"[Info   : Unity Log] 09/10/2026 19:34:41: Checking for any blocked players in the historical player list..." \
"[Info   : Unity Log] 09/10/2026 19:34:55: Checking for any blocked players in the historical player list..." \
"[Info   : Unity Log] 09/10/2026 19:35:02: Got character ZDOID from Laryakan : -106309146:4" \
"[Info   : Unity Log] 09/10/2026 19:35:13: RPC_Disconnect" \
"[Info   : Unity Log] 09/10/2026 19:35:13: Destroying abandoned non persistent zdo 49897:12 owner 49897" \
"[Info   : Unity Log] 09/10/2026 19:35:13: Destroying abandoned non persistent zdo -106309146:1 owner -106309146" \
"[Info   : Unity Log] 09/10/2026 19:35:13: Destroying abandoned non persistent zdo 49887:1 owner 49887" \
"[Info   : Unity Log] 09/10/2026 19:35:13: Disposing socket" \
"[Info   : Unity Log] 09/10/2026 19:35:13: Closing socket 76561190000000" \
"[Info   : Unity Log] 09/10/2026 19:35:13: send queue size:0" \
"[Info   : Unity Log] 09/10/2026 19:35:13: Disposing socket" \
"[Info   : Unity Log] 09/10/2026 19:35:13: Got status changed msg k_ESteamNetworkingConnectionState_ClosedByPeer" \
"[Info   : Unity Log] 09/10/2026 19:35:13: Socket closed by peer Steamworks.SteamNetConnectionStatusChangedCallback_t" \
"[Info   : Unity Log] 09/10/2026 19:35:13: Got status changed msg k_ESteamNetworkingConnectionState_None" \
"[Info   : Unity Log] 09/10/2026 19:38:26: Connections 0 ZDOS:44844 sent:0 recv:0" \
| ./vss.log-filter

# Testing that we do not try to disconect a player that is not in the connected list, even if we see a disconnect event for them.
echo -e "\n---\n\n$(ColorYellow 'Testing log filter pipeline output: Disconnect undetection (we should not see anything)') :"
echo "" > "$CONNECTEDPLAYERSFILE"

printf '%s\n' \
"[Info   : Unity Log] 09/10/2026 19:34:37: Got status changed msg k_ESteamNetworkingConnectionState_Connected" \
"[Info   : Unity Log] 09/10/2026 19:34:37: Connected" \
"[Info   : Unity Log] 09/10/2026 19:34:39: Network version check, their:39, mine:39" \
"[Info   : Unity Log] 09/10/2026 19:34:39: Checking for any blocked players in the historical player list..." \
"[Info   : Unity Log] 09/10/2026 19:34:39: Server: New peer connected,sending global keys" \
"[Info   : Unity Log] 09/10/2026 19:34:41: Checking for any blocked players in the historical player list..." \
"[Info   : Unity Log] 09/10/2026 19:34:55: Checking for any blocked players in the historical player list..." \
"[Info   : Unity Log] 09/10/2026 19:35:13: RPC_Disconnect" \
"[Info   : Unity Log] 09/10/2026 19:35:13: Destroying abandoned non persistent zdo -106309146:1 owner -106309146" \
"[Info   : Unity Log] 09/10/2026 19:35:13: Disposing socket" \
"[Info   : Unity Log] 09/10/2026 19:35:13: Closing socket 76561190000000" \
"[Info   : Unity Log] 09/10/2026 19:35:13: send queue size:0" \
"[Info   : Unity Log] 09/10/2026 19:35:13: Disposing socket" \
"[Info   : Unity Log] 09/10/2026 19:35:13: Got status changed msg k_ESteamNetworkingConnectionState_ClosedByPeer" \
"[Info   : Unity Log] 09/10/2026 19:35:13: Socket closed by peer Steamworks.SteamNetConnectionStatusChangedCallback_t" \
"[Info   : Unity Log] 09/10/2026 19:35:13: Got status changed msg k_ESteamNetworkingConnectionState_None" \
"[Info   : Unity Log] 09/10/2026 19:38:26: Connections 0 ZDOS:44844 sent:0 recv:0" \
| ./vss.log-filter

echo -e "\n---\n\n$(ColorYellow 'Testing log filter pipeline output: Death detection (1 json output expected)') :"

# To test this, we have to fake a previous connection, because the disconnect detection only works if the player is already known to be connected.
echo "2026-09-10.20:38:21;Laryakan;328410070:1" > "$CONNECTEDPLAYERSFILE"

printf '%s\n' \
"[Info   : Unity Log] 09/10/2026 12:41:01: Considering autobackup for World. World time: 40392,89, short time: 7200, long time: 43200, backup count: 2" \
"[Info   : Unity Log] 09/10/2026 12:41:01: SaveSystem.Reload for World is done [9ms]" \
"[Info   : Unity Log] 09/10/2026 12:41:01: No autobackup needed yet..." \
"[Info   : Unity Log] 09/10/2026 19:34:39: Network version check, their:39, mine:39" \
"[Info   : Unity Log] 09/10/2026 19:34:39: Checking for any blocked players in the historical player list..." \
"[Info   : Unity Log] 09/10/2026 19:34:39: Server: New peer connected,sending global keys" \
"[Info   : Unity Log] 09/10/2026 19:34:41: Checking for any blocked players in the historical player list..." \
"[Info   : Unity Log] 09/10/2026 19:34:55: Checking for any blocked players in the historical player list..." \
"[Info   : Unity Log] 09/10/2026 12:47:48: Connections 1 ZDOS:44798 sent:0 recv:309" \
"[Info   : Unity Log] 09/10/2026 12:54:02: Got character ZDOID from Laryakan : 0:0" \
"[Info   : Unity Log] 09/10/2026 12:54:02: Got character ZDOID from Laryakan : 0:2" \
"[Info   : Unity Log] 09/10/2026 12:54:02: Got character ZDOID from Laryakan : 1:0" \
"[Info   : Unity Log] 09/10/2026 12:54:10: Got character ZDOID from Laryakan : 328410070:3210" \
"[Info   : Unity Log] 09/10/2026 12:57:48: Connections 1 ZDOS:44805 sent:0 recv:326" \
"[Info   : Unity Log] 09/10/2026 13:07:48: Connections 1 ZDOS:44807 sent:0 recv:324" \
"[Info   : Unity Log] 09/10/2026 13:11:02: Available space to current user: 105801871360. Saving is blocked if below: 7639928 bytes. Warnings are given if below: 15279856" \
"[Info   : Unity Log] 09/10/2026 13:11:02: Sending message to save player profiles" \
"[Info   : Unity Log] 09/10/2026 13:11:02: Sent to 76561190000000" \
"[Info   : Unity Log] 09/10/2026 13:11:02: GetSaveClonePerChunk. Calculated number of actual chunk files: 5 Number of dirty chunks to save: 4 [16ms]" \
"[Info   : Unity Log] 09/10/2026 13:11:02: PrepareSave: ZDOExtraData.PrepareSave done [13ms]" \
"[Info   : Unity Log] 09/10/2026 13:11:02: ### Save World Thread Started! ###" \
"[Info   : Unity Log] 09/10/2026 13:11:02: Considering autobackup for World. World time: 42193,48, short time: 7200, long time: 43200, backup count: 2" \
"[Info   : Unity Log] 09/10/2026 13:11:02: SaveSystem.Reload for World is done [9ms]" \
| ./vss.log-filter
