import sys

path = r'd:\Health_UT\Health_UT_INFO\client\android\app\src\main\kotlin\com\samsung\health\client\WifiP2pPlugin.kt'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update Imports
content = content.replace('import android.net.wifi.WifiManager', '''import android.net.wifi.WifiManager
import android.net.wifi.p2p.WifiP2pManager
import android.net.wifi.p2p.WifiP2pConfig
import android.net.wifi.p2p.WifiP2pGroup''')

# 2. Add P2P variables
content = content.replace('private var hotspotReservation: WifiManager.LocalOnlyHotspotReservation? = null', '''
    private var wifiP2pManager: WifiP2pManager? = null
    private var p2pChannel: WifiP2pManager.Channel? = null''')

# 3. Update FIXED_SSID
content = content.replace('const val FIXED_SSID = "healthport"', 'const val FIXED_SSID = "DIRECT-healthport"')

# 4. Initialize Manager in register
reg_target = '''        MethodChannel(engine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->'''
reg_repl = '''        wifiP2pManager = context.getSystemService(Context.WIFI_P2P_SERVICE) as? WifiP2pManager
        p2pChannel = wifiP2pManager?.initialize(context, Looper.getMainLooper(), null)
        
        MethodChannel(engine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->'''
content = content.replace(reg_target, reg_repl)

# 5. Modify startServer
start_target = '''        // 1. Start TCP ServerSocket
        startTcpClientThread()

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
            startTcpClientThread()

            // 2. Broadcast UDP Beacon on targeted subnet
            startMultiSubnetUdpBeacon(ip, mode)
        }'''
content = content.replace(start_target, start_repl)

# 6. Add startP2pGroup method
p2p_method = '''
    @SuppressLint("MissingPermission")
    private fun startP2pGroup() {
        if (wifiP2pManager == null || p2pChannel == null) return
        
        val config = WifiP2pConfig.Builder()
            .setNetworkName(FIXED_SSID)
            .setPassphrase(PRIMARY_PASS)
            .build()
            
        // Ensure old group is removed first
        wifiP2pManager?.removeGroup(p2pChannel, object : WifiP2pManager.ActionListener {
            override fun onSuccess() { createNewGroup(config) }
            override fun onFailure(reason: Int) { createNewGroup(config) }
        })
    }

    @SuppressLint("MissingPermission")
    private fun createNewGroup(config: WifiP2pConfig) {
        wifiP2pManager?.createGroup(p2pChannel, config, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                Log.i(TAG, "Wi-Fi Direct P2P Group Created: $FIXED_SSID")
                
                // Now start TCP client and UDP beacon
                startTcpClientThread()
                val ip = getActiveIpAddress()
                startMultiSubnetUdpBeacon(ip, "HOTSPOT")
                
                sendEvent("hotspotStarted", mapOf(
                    "ssid"     to FIXED_SSID,
                    "password" to PRIMARY_PASS,
                    "ip"       to ip
                ))
            }

            override fun onFailure(reason: Int) {
                Log.e(TAG, "Failed to create P2P Group. Reason: $reason")
            }
        })
    }
'''
content = content.replace('// MULTI-SUBNET UDP BEACON', p2p_method + '\n    // MULTI-SUBNET UDP BEACON')

# 7. Modify stopServer to remove P2P group
stop_target = '''    private fun stopServer() {
        if (!isServerRunning) return
        isServerRunning = false'''
stop_repl = '''    private fun stopServer() {
        if (!isServerRunning) return
        isServerRunning = false
        wifiP2pManager?.removeGroup(p2pChannel, null)'''
content = content.replace(stop_target, stop_repl)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Refactored WifiP2pPlugin.kt successfully')
