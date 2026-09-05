import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

path = r'd:\Health_UT\Health_UT_INFO\watch\app\src\main\kotlin\com\samsung\health\client\SyncService.kt'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

start_idx = content.find('fun startDirectConnectFallback() {')
if start_idx == -1:
    print('Could not find startDirectConnectFallback')
    sys.exit(1)

end_idx = content.find('fun startTcpClient(', start_idx)

replacement = '''fun startDirectConnectFallback() {
        if (directConnectThread?.isAlive == true) return
        directConnectThread = Thread {
            writeLog("Starting Direct Connection Fallback thread...")
            
            while (isServiceActive) {
                if (!isSocketRunning) {
                    val fallbackIps = mutableListOf<String>()
                    getWifiGatewayIp()?.let {
                        fallbackIps.add(it)
                    }
                    fallbackIps.addAll(listOf("192.168.43.1", "192.168.44.1", "192.168.45.1", "192.168.1.1", "192.168.0.1"))
                    val uniqueIps = fallbackIps.distinct()
                    
                    for (ip in uniqueIps) {
                        if (isSocketRunning) break
                        try {
                            val socket = Socket()
                            socket.receiveBufferSize = BUFFER_SIZE
                            socket.sendBufferSize = BUFFER_SIZE
                            
                            activeWifiNetwork?.let {
                                it.bindSocket(socket)
                            }
                            
                            writeLog("Attempting direct TCP connection to gateway: $ip:$TCP_PORT...")
                            socket.connect(InetSocketAddress(ip, TCP_PORT), 3000)
                            
                            writeLog("Direct connection success to $ip! Initiating synchronization client...")
                            tcpSocket = socket
                            isSocketRunning = true
                            
                            val writer = BufferedWriter(OutputStreamWriter(socket.getOutputStream(), Charsets.UTF_8))
                            socketWriter = writer
                            writer.write("HELLO_FROM_WATCH\\n")
                            writer.flush()
                            
                            if (isServiceActive) {
                                handleSocketCommand("START_SYNC", socket.getInputStream())
                                // block thread by reading next line
                                val reader = java.io.BufferedReader(java.io.InputStreamReader(socket.getInputStream(), Charsets.UTF_8))
                                handleSocketCommand(reader.readLine() ?: "dummy", socket.getInputStream()) 
                            }
                        } catch (e: Exception) {
                            // Silently ignore
                        } finally {
                            if (isSocketRunning) {
                                writeLog("Direct client session closed.")
                                stopTcpClient()
                            }
                        }
                    }
                }
                Thread.sleep(3000)
            }
        }.apply { isDaemon = true; start() }
    }

    // ?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€
    // TCP CLIENT (UDP BEACON INITIATED)
    // ?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€

    private '''

content = content[:start_idx] + replacement + content[end_idx + len('private '):]

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Replaced startDirectConnectFallback successfully')
