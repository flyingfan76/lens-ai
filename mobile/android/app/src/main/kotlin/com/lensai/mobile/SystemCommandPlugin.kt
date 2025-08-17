package com.lensai.mobile

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import java.io.BufferedReader
import java.io.InputStreamReader
import java.util.concurrent.TimeUnit

class SystemCommandPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "lens_ai/system_commands")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "executeCommand" -> {
                val command = call.argument<String>("command")
                val timeout = call.argument<Int>("timeout") ?: 5000
                
                if (command != null) {
                    executeCommand(command, timeout.toLong(), result)
                } else {
                    result.error("INVALID_ARGUMENT", "Command cannot be null", null)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun executeCommand(command: String, timeoutMs: Long, result: Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val output = when {
                    command.startsWith("lsusb") -> executeLsusb()
                    command.contains("usb") -> executeUSBCommand(command)
                    else -> executeGenericCommand(command, timeoutMs)
                }
                
                withContext(Dispatchers.Main) {
                    result.success(output)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("EXECUTION_ERROR", "Command execution failed: ${e.message}", null)
                }
            }
        }
    }

    private fun executeLsusb(): String {
        // Android doesn't have lsusb by default, but we can check USB devices via sysfs
        val output = StringBuilder()
        
        try {
            // Check for USB host support first
            val usbHostSupported = checkUSBHostSupport()
            if (!usbHostSupported) {
                return "USB Host mode not supported on this device"
            }
            
            // Try to read USB device information from sysfs
            val usbDevices = getUSBDevicesFromSysfs()
            if (usbDevices.isNotEmpty()) {
                output.append("USB devices found via sysfs:\n")
                usbDevices.forEach { device ->
                    output.append("${device}\n")
                }
            } else {
                output.append("No USB devices detected in sysfs")
            }
            
            // Also try Android's USB manager approach
            val managerDevices = getUSBDevicesFromManager()
            if (managerDevices.isNotEmpty()) {
                output.append("\nUSB devices found via UsbManager:\n")
                managerDevices.forEach { device ->
                    output.append("${device}\n")
                }
            }
            
        } catch (e: Exception) {
            output.append("Error reading USB devices: ${e.message}")
        }
        
        return output.toString()
    }

    private fun checkUSBHostSupport(): Boolean {
        return try {
            context.packageManager.hasSystemFeature("android.hardware.usb.host")
        } catch (e: Exception) {
            false
        }
    }

    private fun getUSBDevicesFromSysfs(): List<String> {
        val devices = mutableListOf<String>()
        
        try {
            // Common paths for USB device information on Android
            val sysfsUSBPaths = listOf(
                "/sys/bus/usb/devices",
                "/sys/devices/platform/usb",
                "/proc/bus/usb/devices"
            )
            
            for (path in sysfsUSBPaths) {
                try {
                    val process = ProcessBuilder("ls", "-la", path).start()
                    val reader = BufferedReader(InputStreamReader(process.inputStream))
                    
                    var line: String?
                    while (reader.readLine().also { line = it } != null) {
                        line?.let { 
                            if (it.contains("usb") || it.contains("device")) {
                                devices.add("sysfs: $it")
                            }
                        }
                    }
                    process.waitFor(2, TimeUnit.SECONDS)
                } catch (e: Exception) {
                    // Continue to next path
                }
            }
            
            // Try to read vendor/product IDs from specific device paths
            devices.addAll(readUSBVendorProductIds())
            
        } catch (e: Exception) {
            devices.add("sysfs error: ${e.message}")
        }
        
        return devices
    }

    private fun readUSBVendorProductIds(): List<String> {
        val devices = mutableListOf<String>()
        
        try {
            // Look for USB device directories
            val usbDevicePattern = Regex("""(\d+-\d+)""")
            val process = ProcessBuilder("find", "/sys/bus/usb/devices", "-name", "*-*", "-type", "d").start()
            val reader = BufferedReader(InputStreamReader(process.inputStream))
            
            var line: String?
            while (reader.readLine().also { line = it } != null) {
                line?.let { devicePath ->
                    try {
                        val vendorFile = "${devicePath}/idVendor"
                        val productFile = "${devicePath}/idProduct"
                        val manufacturerFile = "${devicePath}/manufacturer"
                        val productNameFile = "${devicePath}/product"
                        
                        val vendor = readFileContent(vendorFile)
                        val product = readFileContent(productFile) 
                        val manufacturer = readFileContent(manufacturerFile)
                        val productName = readFileContent(productNameFile)
                        
                        if (vendor != null && product != null) {
                            val deviceInfo = buildString {
                                append("ID ${vendor}:${product}")
                                if (manufacturer != null) append(" $manufacturer")
                                if (productName != null) append(" $productName")
                            }
                            devices.add(deviceInfo)
                        }
                    } catch (e: Exception) {
                        // Skip this device
                    }
                }
            }
            process.waitFor(3, TimeUnit.SECONDS)
            
        } catch (e: Exception) {
            devices.add("vendor/product ID error: ${e.message}")
        }
        
        return devices
    }

    private fun readFileContent(filePath: String): String? {
        return try {
            val process = ProcessBuilder("cat", filePath).start()
            val reader = BufferedReader(InputStreamReader(process.inputStream))
            val content = reader.readLine()?.trim()
            process.waitFor(1, TimeUnit.SECONDS)
            content
        } catch (e: Exception) {
            null
        }
    }

    private fun getUSBDevicesFromManager(): List<String> {
        val devices = mutableListOf<String>()
        
        try {
            // This would require UsbManager access, which needs to be implemented
            // in the MainActivity or through a proper Android service
            devices.add("UsbManager integration pending - requires MainActivity setup")
        } catch (e: Exception) {
            devices.add("UsbManager error: ${e.message}")
        }
        
        return devices
    }

    private fun executeUSBCommand(command: String): String {
        return when {
            command.contains("lsusb") -> executeLsusb()
            else -> "Unknown USB command: $command"
        }
    }

    private fun executeGenericCommand(command: String, timeoutMs: Long): String {
        val process = ProcessBuilder(*command.split(" ").toTypedArray()).start()
        val reader = BufferedReader(InputStreamReader(process.inputStream))
        val output = StringBuilder()
        
        var line: String?
        while (reader.readLine().also { line = it } != null) {
            output.append(line).append("\n")
        }
        
        val completed = process.waitFor(timeoutMs, TimeUnit.MILLISECONDS)
        if (!completed) {
            process.destroyForcibly()
            throw Exception("Command timeout after ${timeoutMs}ms")
        }
        
        return output.toString()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}