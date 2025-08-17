package com.lensai.mobile

import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    private lateinit var systemCommandPlugin: SystemCommandPlugin
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register the system command plugin
        systemCommandPlugin = SystemCommandPlugin()
        flutterEngine.plugins.add(systemCommandPlugin)
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Request USB permissions if needed
        checkUSBPermissions()
    }
    
    private fun checkUSBPermissions() {
        try {
            val usbManager = getSystemService(USB_SERVICE) as UsbManager?
            usbManager?.let { manager ->
                val deviceList: HashMap<String, UsbDevice> = manager.deviceList
                
                // Log available USB devices for debugging
                println("LensAI: Found ${deviceList.size} USB devices")
                for ((name, device) in deviceList) {
                    println("LensAI: USB Device - $name: ${device.manufacturerName} ${device.productName}")
                    println("LensAI: VendorId: ${String.format("%04x", device.vendorId)}, ProductId: ${String.format("%04x", device.productId)}")
                }
            }
        } catch (e: Exception) {
            println("LensAI: Error checking USB devices: ${e.message}")
        }
    }
}