import Cocoa
import Foundation
import IOKit
import IOKit.usb

/// Advanced PTP management for macOS camera access
public class PTPManager: NSObject {
    private static let shared = PTPManager()
    
    // PTP daemon control
    private let ptpDaemonName = "com.apple.ptpcamerad"
    
    /// Temporarily disable macOS PTP daemon
    public static func disablePTPDaemon() -> Bool {
        print("PTPManager: Attempting to disable PTP daemon")
        
        // Method 1: Use modern launchctl bootout to disable the daemon
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = ["bootout", "system/com.apple.ptpcamerad"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                print("PTPManager: Successfully disabled PTP daemon")
                return true
            } else {
                print("PTPManager: Failed to disable PTP daemon (status: \(task.terminationStatus))")
            }
        } catch {
            print("PTPManager: Error disabling PTP daemon: \(error)")
        }
        
        // Method 2: Kill ptpcamerad process directly
        return killPTPProcess()
    }
    
    /// Kill ptpcamerad process
    private static func killPTPProcess() -> Bool {
        let task = Process()
        task.launchPath = "/usr/bin/pkill"
        task.arguments = ["-f", "ptpcamerad"]
        
        do {
            try task.run()
            task.waitUntilExit()
            print("PTPManager: Attempted to kill PTP processes")
            return true
        } catch {
            print("PTPManager: Error killing PTP process: \(error)")
            return false
        }
    }
    
    /// Re-enable PTP daemon
    public static func enablePTPDaemon() -> Bool {
        print("PTPManager: Re-enabling PTP daemon")
        
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = ["bootstrap", "system", "/System/Library/LaunchDaemons/com.apple.ptpcamerad.plist"]
        
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            print("PTPManager: Error re-enabling PTP daemon: \(error)")
            return false
        }
    }
    
    /// Check if PTP daemon is running
    public static func isPTPDaemonRunning() -> Bool {
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-ax"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            return output.contains("ptpcamerad")
        } catch {
            print("PTPManager: Error checking PTP daemon: \(error)")
            return false
        }
    }
    
    /// Create exclusive USB access for camera
    public static func requestExclusiveUSBAccess(vendorID: UInt16, productID: UInt16) -> Bool {
        print("PTPManager: Requesting exclusive USB access for \(String(format: "%04x", vendorID)):\(String(format: "%04x", productID))")
        
        var masterPort = mach_port_t()
        let result = IOMasterPort(MACH_PORT_NULL, &masterPort)
        
        guard result == KERN_SUCCESS else {
            print("PTPManager: Failed to get master port")
            return false
        }
        
        // Create matching dictionary for USB device
        let matchingDict = IOServiceMatching(kIOUSBDeviceClassName)
        guard matchingDict != nil else {
            print("PTPManager: Failed to create matching dictionary")
            return false
        }
        
        // Set vendor and product ID
        let vendorIDNum = NSNumber(value: vendorID)
        let productIDNum = NSNumber(value: productID)
        
        CFDictionarySetValue(matchingDict, Unmanaged.passUnretained(kUSBVendorID).toOpaque(), 
                           Unmanaged.passUnretained(vendorIDNum).toOpaque())
        CFDictionarySetValue(matchingDict, Unmanaged.passUnretained(kUSBProductID).toOpaque(), 
                           Unmanaged.passUnretained(productIDNum).toOpaque())
        
        var iterator = io_iterator_t()
        let serviceResult = IOServiceGetMatchingServices(masterPort, matchingDict, &iterator)
        
        guard serviceResult == KERN_SUCCESS else {
            print("PTPManager: Failed to get matching services")
            return false
        }
        
        defer { IOObjectRelease(iterator) }
        
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service) }
            
            // Try to open the device exclusively
            var deviceInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface>?>?
            var pluginInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOCFPlugInInterface>?>?
            var score: Int32 = 0
            
            let pluginResult = IOCreatePlugInInterfaceForService(
                service,
                kIOUSBDeviceUserClientTypeID,
                kIOCFPlugInInterfaceID,
                &pluginInterface,
                &score
            )
            
            if pluginResult == KERN_SUCCESS, let plugin = pluginInterface {
                let queryResult = withUnsafeMutablePointer(to: &deviceInterface) { devicePtr in
                    plugin.pointee.pointee.QueryInterface(
                        plugin,
                        CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID),
                        UnsafeMutableRawPointer(devicePtr)
                    )
                }
                
                if queryResult == S_OK, let device = deviceInterface {
                    let openResult = device.pointee.pointee.USBDeviceOpen(device)
                    if openResult == kIOReturnSuccess {
                        print("PTPManager: Successfully opened USB device exclusively")
                        return true
                    } else {
                        print("PTPManager: Failed to open USB device: \(openResult)")
                    }
                }
            }
            
            service = IOIteratorNext(iterator)
        }
        
        return false
    }
}