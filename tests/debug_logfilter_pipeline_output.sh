#!/bin/bash
set -u

cd "$(dirname "$0")/.."
source .env.test
export DEBUGMODE=1

# Idempotence
rm -f "$CONNECTEDPLAYERSFILE" "$OFFLINEPLAYERSFILE" "$STEAMIDMAPFILE" "$LASTWORLDSAVEFILE" "$INGAMETIMEFILE" "$INGAMETIMEEVENTSFILE"

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
"09/10/2026 01:27:32: Get create world FinekipUnPointZero" \
"09/10/2026 01:27:32: SaveSystem.Reload for World is done [100ms]" \
"09/10/2026 01:27:32: Using environment steamid 892970" \
"09/10/2026 01:27:32: Using steam APPID:892970" \
"IPC function call IClientUtils::GetSteamRealm took too long: 76 msec" \
"09/10/2026 01:27:33: Server ID 90071992547409920" \
"09/10/2026 01:27:33: Authentication:k_ESteamNetworkingAvailability_Waiting" \
"09/10/2026 01:27:33: Steam game server initialized" \
"09/10/2026 01:27:33: Valheim version: l-1.0.7 (network version 39)" \
"09/10/2026 01:27:33: Worldgenerator version setup:2" \
"09/10/2026 01:27:33: Console: Valheim l-1.0.7 (network version 39)" \
"09/10/2026 01:27:33: Console:" \
"09/10/2026 01:27:33: Console: type \"help\" - for commands" \
"09/10/2026 01:27:33: Console:" \
"09/10/2026 01:27:33: Render threading mode:SingleThreaded" \
| ./vss.log-filter

echo -e "\n---\n\n$(ColorYellow 'Testing log filter pipeline output: Save detection (1 output expected)') :"

printf '%s\n' \
"09/10/2026 19:48:14: ### Save World Thread Started! ###" \
"09/10/2026 19:48:14: Considering autobackup for World. World time: 8988,277, short time: 7200, long time: 43200, backup count: 2" \
"09/10/2026 19:48:14: SaveSystem.Reload for World is done [9ms]" \
"09/10/2026 19:48:14: No autobackup needed yet..." \
"09/10/2026 19:48:14: World save (1/5) Cloud & Backup checks done [0ms] => Save number 47" \
"09/10/2026 19:48:15: World save (2/5) Chunks writing done [275ms]" \
"09/10/2026 19:48:15: World save (3/5) DB2 writing done [29ms]" \
"09/10/2026 19:48:15: World save (4/5) FWL writing done [1ms]" \
"09/10/2026 19:48:15: World save (5/5) done. Total time [319ms]" \
"09/10/2026 19:48:26: Connections 0 ZDOS:44844 sent:0 recv:0" \
"09/10/2026 19:58:26: Connections 0 ZDOS:44844 sent:0 recv:0" \
| ./vss.log-filter

echo -e "\n---\n\n$(ColorYellow 'Testing log filter pipeline output: First connection detection (1 steamid and 1 json output expected with event \"first_join\")') :"
echo "" > "$CONNECTEDPLAYERSFILE"
echo "" > "$STEAMIDMAPFILE"

printf '%s\n' \
"09/10/2026 12:17:48: Connections 0 ZDOS:44824 sent:0 recv:0" \
"09/10/2026 12:22:15: Got status changed msg k_ESteamNetworkingConnectionState_Connecting" \
"09/10/2026 12:22:15: New connection" \
"09/10/2026 12:22:47: Got character ZDOID from Laryakan : 328410070:35" \
"09/10/2026 12:22:15: Accepting connection k_EResultOK" \
"09/10/2026 12:22:15: Connecting to Steamworks.SteamNetworkingIdentity" \
"09/10/2026 12:22:15: Got status changed msg k_ESteamNetworkingConnectionState_Connected" \
"09/10/2026 12:22:15: Connected" \
"09/10/2026 12:22:15: Got connection SteamID 76561190000000" \
"09/10/2026 12:22:15: Got handshake from client 76561190000000" \
"09/10/2026 12:22:24: Network version check, their:39, mine:39" \
"09/10/2026 12:22:24: Checking for any blocked players in the historical player list..." \
"09/10/2026 12:22:24: Server: New peer connected,sending global keys" \
"09/10/2026 12:22:24: Checking for any blocked players in the historical player list..." \
"09/10/2026 12:22:42: Checking for any blocked players in the historical player list..." \
"09/10/2026 12:22:47: Got character ZDOID from Laryakan : 328410070:4" \
"09/10/2026 12:22:47: Got character ZDOID from Laryakan : 328410070:1" \
"09/10/2026 12:27:48: Unloading unused assets" \
"Unloading 0 Unused Serialized files (Serialized files now loaded: 20)" \
"09/10/2026 12:27:48: Connections 1 ZDOS:44824 sent:0 recv:274" \
| ./vss.log-filter

echo -e "\n---\n\n$(ColorYellow 'Testing log filter pipeline output: Connection detection (1 steamid 1 json output expected with \"connected\")') :"
echo "" > "$CONNECTEDPLAYERSFILE"
echo "76561190000000;Laryakan" > "$STEAMIDMAPFILE"

printf '%s\n' \
"09/10/2026 12:17:48: Connections 0 ZDOS:44824 sent:0 recv:0" \
"09/10/2026 12:22:15: Got status changed msg k_ESteamNetworkingConnectionState_Connecting" \
"09/10/2026 12:22:15: New connection" \
"09/10/2026 12:22:47: Got character ZDOID from Laryakan : 328410070:35" \
"09/10/2026 12:22:15: Accepting connection k_EResultOK" \
"09/10/2026 12:22:15: Connecting to Steamworks.SteamNetworkingIdentity" \
"09/10/2026 12:22:15: Got status changed msg k_ESteamNetworkingConnectionState_Connected" \
"09/10/2026 12:22:15: Connected" \
"09/10/2026 12:22:15: Got connection SteamID 76561190000000" \
"09/10/2026 12:22:15: Got handshake from client 76561190000000" \
"09/10/2026 12:22:24: Network version check, their:39, mine:39" \
"09/10/2026 12:22:24: Checking for any blocked players in the historical player list..." \
"09/10/2026 12:22:24: Server: New peer connected,sending global keys" \
"09/10/2026 12:22:24: Checking for any blocked players in the historical player list..." \
"09/10/2026 12:22:42: Checking for any blocked players in the historical player list..." \
"09/10/2026 12:22:47: Got character ZDOID from Laryakan : 328410070:1" \
"09/10/2026 12:27:48: Unloading unused assets" \
"Unloading 0 Unused Serialized files (Serialized files now loaded: 20)" \
"09/10/2026 12:27:48: Connections 1 ZDOS:44824 sent:0 recv:274" \
| ./vss.log-filter

echo -e "\n---\n\n$(ColorYellow 'Testing log filter pipeline output: Disconnect detection (1 json output expected)') :"

# To test this, we have to fake a previous connection, because the disconnect detection only works if the player is already known to be connected.
echo "2026-09-10.20:38:21;Laryakan;-106309146:1" > "$CONNECTEDPLAYERSFILE"

printf '%s\n' \
"09/10/2026 19:34:37: Got status changed msg k_ESteamNetworkingConnectionState_Connected" \
"09/10/2026 19:34:37: Connected" \
"09/10/2026 19:34:37: Got connection SteamID 76561190000000" \
"09/10/2026 19:34:37: Got handshake from client 76561190000000" \
"09/10/2026 19:34:39: Network version check, their:39, mine:39" \
"09/10/2026 19:34:39: Checking for any blocked players in the historical player list..." \
"09/10/2026 19:34:39: Server: New peer connected,sending global keys" \
"09/10/2026 19:34:41: Checking for any blocked players in the historical player list..." \
"09/10/2026 19:34:55: Checking for any blocked players in the historical player list..." \
"09/10/2026 19:35:02: Got character ZDOID from Laryakan : -106309146:4" \
"09/10/2026 19:35:13: RPC_Disconnect" \
"09/10/2026 19:35:13: Destroying abandoned non persistent zdo 49897:12 owner 49897" \
"09/10/2026 19:35:13: Destroying abandoned non persistent zdo -106309146:1 owner -106309146" \
"09/10/2026 19:35:13: Destroying abandoned non persistent zdo 49887:1 owner 49887" \
"09/10/2026 19:35:13: Disposing socket" \
"09/10/2026 19:35:13: Closing socket 76561190000000" \
"09/10/2026 19:35:13: send queue size:0" \
"09/10/2026 19:35:13: Disposing socket" \
"09/10/2026 19:35:13: Got status changed msg k_ESteamNetworkingConnectionState_ClosedByPeer" \
"09/10/2026 19:35:13: Socket closed by peer Steamworks.SteamNetConnectionStatusChangedCallback_t" \
"09/10/2026 19:35:13: Got status changed msg k_ESteamNetworkingConnectionState_None" \
"09/10/2026 19:38:26: Connections 0 ZDOS:44844 sent:0 recv:0" \
| ./vss.log-filter

# Testing that we do not try to disconect a player that is not in the connected list, even if we see a disconnect event for them.
echo -e "\n---\n\n$(ColorYellow 'Testing log filter pipeline output: Disconnect undetection (we should not see anything)') :"
echo "" > "$CONNECTEDPLAYERSFILE"

printf '%s\n' \
"09/10/2026 19:34:37: Got status changed msg k_ESteamNetworkingConnectionState_Connected" \
"09/10/2026 19:34:37: Connected" \
"09/10/2026 19:34:37: Got handshake from client 76561190000000" \
"09/10/2026 19:34:39: Network version check, their:39, mine:39" \
"09/10/2026 19:34:39: Checking for any blocked players in the historical player list..." \
"09/10/2026 19:34:39: Server: New peer connected,sending global keys" \
"09/10/2026 19:34:41: Checking for any blocked players in the historical player list..." \
"09/10/2026 19:34:55: Checking for any blocked players in the historical player list..." \
"09/10/2026 19:35:13: RPC_Disconnect" \
"09/10/2026 19:35:13: Destroying abandoned non persistent zdo -106309146:1 owner -106309146" \
"09/10/2026 19:35:13: Disposing socket" \
"09/10/2026 19:35:13: Closing socket 76561190000000" \
"09/10/2026 19:35:13: send queue size:0" \
"09/10/2026 19:35:13: Disposing socket" \
"09/10/2026 19:35:13: Got status changed msg k_ESteamNetworkingConnectionState_ClosedByPeer" \
"09/10/2026 19:35:13: Socket closed by peer Steamworks.SteamNetConnectionStatusChangedCallback_t" \
"09/10/2026 19:35:13: Got status changed msg k_ESteamNetworkingConnectionState_None" \
"09/10/2026 19:38:26: Connections 0 ZDOS:44844 sent:0 recv:0" \
| ./vss.log-filter

echo -e "\n---\n\n$(ColorYellow 'Testing log filter pipeline output: Death detection (1 json output expected)') :"

# To test this, we have to fake a previous connection, because the disconnect detection only works if the player is already known to be connected.
echo "2026-09-10.20:38:21;Laryakan;328410070:1" > "$CONNECTEDPLAYERSFILE"

printf '%s\n' \
"09/10/2026 12:41:01: Considering autobackup for World. World time: 40392,89, short time: 7200, long time: 43200, backup count: 2" \
"09/10/2026 12:41:01: SaveSystem.Reload for World is done [9ms]" \
"09/10/2026 12:41:01: No autobackup needed yet..." \
"09/10/2026 19:34:39: Network version check, their:39, mine:39" \
"09/10/2026 19:34:39: Checking for any blocked players in the historical player list..." \
"09/10/2026 19:34:39: Server: New peer connected,sending global keys" \
"09/10/2026 19:34:41: Checking for any blocked players in the historical player list..." \
"09/10/2026 19:34:55: Checking for any blocked players in the historical player list..." \
"09/10/2026 12:47:48: Connections 1 ZDOS:44798 sent:0 recv:309" \
"09/10/2026 12:54:02: Got character ZDOID from Laryakan : 0:0" \
"09/10/2026 12:54:02: Got character ZDOID from Laryakan : 0:2" \
"09/10/2026 12:54:02: Got character ZDOID from Laryakan : 1:0" \
"09/10/2026 12:54:10: Got character ZDOID from Laryakan : 328410070:3210" \
"09/10/2026 12:57:48: Connections 1 ZDOS:44805 sent:0 recv:326" \
"09/10/2026 13:07:48: Connections 1 ZDOS:44807 sent:0 recv:324" \
"09/10/2026 13:11:02: Available space to current user: 105801871360. Saving is blocked if below: 7639928 bytes. Warnings are given if below: 15279856" \
"09/10/2026 13:11:02: Sending message to save player profiles" \
"09/10/2026 13:11:02: Sent to 76561190000000" \
"09/10/2026 13:11:02: GetSaveClonePerChunk. Calculated number of actual chunk files: 5 Number of dirty chunks to save: 4 [16ms]" \
"09/10/2026 13:11:02: PrepareSave: ZDOExtraData.PrepareSave done [13ms]" \
"09/10/2026 13:11:02: ### Save World Thread Started! ###" \
"09/10/2026 13:11:02: Considering autobackup for World. World time: 42193,48, short time: 7200, long time: 43200, backup count: 2" \
"09/10/2026 13:11:02: SaveSystem.Reload for World is done [9ms]" \
| ./vss.log-filter

echo -e "\n---\n\n$(ColorYellow 'Testing log filter pipeline output: Day number (2 clock samples expected, latest day stored in data)') :"

printf '%s\n' \
"Unloading 0 Unused Serialized files (Serialized files now loaded: 22)" \
"10/03/2026 21:16:47:  Connections 1 ZDOS:490391  sent:0 recv:745" \
"Unloading 0 unused Assets to reduce memory usage. Loaded Objects now: 278474." \
"Total: 732.065177 ms (FindLiveObjects: 58.432439 ms CreateObjectMapping: 69.834765 ms MarkObjects: 602.341838 ms  DeleteObjects: 1.454970 ms)" \
"10/03/2026 21:20:04: Time 783270,25787827, day:435    nextm:785070,000010729  skipspeed:149,978511038236" \
"10/04/2026 01:07:43: Time 795831,77718268, day:441    nextm:795870,000010729  skipspeed:3,18523567076772" \
"10/03/2026 21:20:24: Available space to current user: 104770367488. Saving is blocked if below: 42158640 bytes. Warnings are given if below: 84317280" \
"10/03/2026 21:20:24: GetSaveClonePerChunk. Calculated number of actual chunk files: 42  Number of dirty chunks to save: 4 [130ms]" \
"10/03/2026 21:20:24: PrepareSave: ZDOExtraData.PrepareSave done [169ms]" \
"10/03/2026 21:20:24:  ### Save World Thread Started! ###" \
"10/03/2026 21:20:24: Considering autobackup for World. World time: 57816,06, short time: 7200, long time: 43200, backup count: 4" \
"10/03/2026 21:20:24: SaveSystem.Reload for World is done [102ms]" \
"10/03/2026 21:20:24: No autobackup needed yet..." \
"10/03/2026 21:20:24: World save (1/5) Cloud & Backup checks done [0ms] => Save number 1203" \
"10/03/2026 21:20:25: World save (2/5) Chunks writing done [710ms]" \
"10/03/2026 21:20:25: World save (3/5) DB2 writing done [33ms]" \
| ./vss.log-filter

STORED_INGAMEDAY=$(cut -d ';' -f2 "$INGAMETIMEFILE")
if [ "$STORED_INGAMEDAY" != "442" ]; then
	printf 'FAIL: expected calibrated in-game day 442, got %s\n' "$STORED_INGAMEDAY" >&2
	exit 1
fi
echo -e "Stored in-game day number: $STORED_INGAMEDAY"
STORED_INGAMETIME=$(awk -F';' '{ time = $1; gsub(/,/, ".", time); phase = time - int(time / 1800) * 1800; total_minutes = int(phase * 24 * 60 / 1800); printf "%02d:%02d", int(total_minutes / 60), total_minutes % 60 }' "$INGAMETIMEFILE")
if [ "$STORED_INGAMETIME" != "03:36" ]; then
	printf 'FAIL: expected calibrated in-game time 03:36, got %s\n' "$STORED_INGAMETIME" >&2
	exit 1
fi
echo -e "Sampled in-game time: $STORED_INGAMETIME"
