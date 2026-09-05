import sys

path = r'd:\Health_UT\Health_UT_INFO\client\android\app\src\main\kotlin\com\samsung\health\client\WifiP2pPlugin.kt'

with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix 1: startServer replacement
start_target = '''        // 1. Start TCP ServerSocket
        startTcpServerThread()

        // 2. Broadcast UDP Beacon on targeted subnet
        startMultiSubnetUdpBeacon(ip, mode)

        if (mode == "HOTSPOT") {
            sendEvent("hotspotStarted", mapOf(
                "ssid"     to FIXED_SSID,
                "password" to PRIMARY_PASS,
                "ip"       to ip
            ))
        }'''
        
start_repl = '''        if (mode == "HOTSPOT") {
            startP2pGroup()
        } else {
            // 1. Start TCP ServerSocket
            startTcpServerThread()

            // 2. Broadcast UDP Beacon on targeted subnet
            startMultiSubnetUdpBeacon(ip, mode)
        }'''
content = content.replace(start_target, start_repl)

# Fix 2: !! on p2pChannel and startTcpServerThread instead of Client
p2p_bad = '''        // Ensure old group is removed first
        wifiP2pManager?.removeGroup(p2pChannel, object : WifiP2pManager.ActionListener {'''
p2p_good = '''        // Ensure old group is removed first
        wifiP2pManager?.removeGroup(p2pChannel!!, object : WifiP2pManager.ActionListener {'''
content = content.replace(p2p_bad, p2p_good)

p2p_create_bad = '''        wifiP2pManager?.createGroup(p2pChannel, config, object : WifiP2pManager.ActionListener {'''
p2p_create_good = '''        wifiP2pManager?.createGroup(p2pChannel!!, config, object : WifiP2pManager.ActionListener {'''
content = content.replace(p2p_create_bad, p2p_create_good)

content = content.replace('startTcpClientThread()', 'startTcpServerThread()')

# Fix 3: hotspotReservation unresolved
stop_target = '''        udpBeaconThread = null
        hotspotReservation?.close()
        hotspotReservation = null
        sendEvent("connectionStateChanged", mapOf("connected" to false))'''
stop_repl = '''        udpBeaconThread = null
        wifiP2pManager?.removeGroup(p2pChannel, null)
        sendEvent("connectionStateChanged", mapOf("connected" to false))'''
content = content.replace(stop_target, stop_repl)

# Also fix the previous stopServer replacement which appended an extra removeGroup?
# Let's clean up any double removeGroup in stopServer
# wait, my previous python script was:
# stop_repl = '''    private fun stopServer() {
#         if (!isServerRunning) return
#         isServerRunning = false
#         wifiP2pManager?.removeGroup(p2pChannel, null)'''
# But let's just make sure we remove hotspotReservation.
content = content.replace('hotspotReservation?.close()', '// hotspot removed')
content = content.replace('hotspotReservation = null', '')


with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Fixed WifiP2pPlugin.kt')
