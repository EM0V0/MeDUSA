using System;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Windows.Devices.Bluetooth;
using Windows.Devices.Bluetooth.Advertisement;
using Windows.Devices.Bluetooth.GenericAttributeProfile;
using Windows.Devices.Enumeration;
using Windows.Storage.Streams;

namespace MedusaBleConsoleTest
{
    class Program
    {
        // ====================================================================
        // UUIDs from MeDUSA WiFi Helper GATT service (from test_wifi_helper.py)
        // ====================================================================
        
        private static readonly Guid SERVICE_UUID = 
            new Guid("c0de0000-7e1a-4f83-bf3a-0c0ffee0c0de");

        private static readonly Guid SSID_CHAR_UUID = 
            new Guid("c0de0001-7e1a-4f83-bf3a-0c0ffee0c0de");

        private static readonly Guid PSK_CHAR_UUID = 
            new Guid("c0de0002-7e1a-4f83-bf3a-0c0ffee0c0de");

        private static readonly Guid CONTROL_CHAR_UUID = 
            new Guid("c0de0003-7e1a-4f83-bf3a-0c0ffee0c0de");

        private static readonly Guid STATUS_CHAR_UUID = 
            new Guid("c0de0004-7e1a-4f83-bf3a-0c0ffee0c0de");

        // ====================================================================
        // Control commands
        // ====================================================================
        private const byte CMD_CONNECT = 0x01;
        private const byte CMD_CLEAR = 0x02;
        private const byte CMD_FACTORY_RESET = 0x03;

        // ====================================================================
        // Status codes
        // ====================================================================
        private static readonly Dictionary<byte, string> STATUS_CODES = new()
        {
            { 0x01, "Idle" },
            { 0x02, "Pairing" },
            { 0x03, "Ready" },
            { 0x04, "Connecting" },
            { 0x05, "Authenticating" },
            { 0x06, "Obtaining IP" },
            { 0x07, "Success ?" },
            { 0xF0, "Fail Pair ?" },
            { 0xF1, "Fail Auth ?" },
            { 0xF2, "Fail Network ?" },
            { 0xFF, "Fail Internal ?" }
        };

        // ====================================================================

        private const string TARGET_DEVICE_NAME = "medusa";
        private const int SCAN_TIMEOUT_SECONDS = 10;
        private const int STATUS_MONITOR_SECONDS = 30;

        private static BluetoothLEDevice? bleDevice;
        private static GattCharacteristic? statusChar;
        private static GattCharacteristic? ssidChar;
        private static GattCharacteristic? pskChar;
        private static GattCharacteristic? controlChar;
        private static ulong deviceAddress;

        static async Task<int> Main(string[] args)
        {
            // Set console encoding for emoji support
            try
            {
                Console.OutputEncoding = Encoding.UTF8;
                Console.InputEncoding = Encoding.UTF8;
            }
            catch
            {
                // If UTF-8 fails, continue anyway
            }
            
            // Handle Ctrl+C gracefully
            Console.CancelKeyPress += (sender, e) =>
            {
                e.Cancel = true;
                Console.WriteLine("\n\n?? Interrupted by user");
                Cleanup();
                Environment.Exit(0);
            };
            
            PrintHeader();

            try
            {
                // Initial scan for device (optional - can rescan from menu)
                deviceAddress = await ScanForDevice();
                if (deviceAddress == 0)
                {
                    Console.WriteLine("\n??  Device not found in initial scan.");
                    Console.WriteLine("?? You can scan again from the menu (Option 4)");
                    Console.WriteLine("?? Or make sure medusa_wifi_helper is running on your Pi");
                }

                // Interactive menu loop (even if device not found initially)
                await InteractiveMenu();

                Console.WriteLine("\n? All done!");
                return 0;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"\n? Error: {ex.Message}");
                Console.WriteLine($"   {ex.GetType().Name}");
                if (ex.StackTrace != null)
                {
                    Console.WriteLine($"\n   Stack trace:");
                    Console.WriteLine(ex.StackTrace);
                }
                return 1;
            }
            finally
            {
                Cleanup();
            }
        }

        static void PrintHeader()
        {
            Console.WriteLine("=".PadRight(60, '='));
            Console.WriteLine("   MeDUSA WiFi Helper - BLE GATT Test Tool");
            Console.WriteLine("=".PadRight(60, '='));
            Console.WriteLine();
        }

        static async Task InteractiveMenu()
        {
            while (true)
            {
                Console.WriteLine("\n" + "=".PadRight(60, '='));
                Console.WriteLine("Options:");
                Console.WriteLine("  1. Provision WiFi credentials");
                Console.WriteLine("  2. Clear credentials");
                Console.WriteLine("  3. Read current status");
                Console.WriteLine("  4. Scan again");
                Console.WriteLine("  5. Unpair device (if having pairing issues)");
                Console.WriteLine("  6. Exit");
                Console.WriteLine("=".PadRight(60, '='));

                Console.Write("\nSelect option (1-6): ");
                var choice = Console.ReadLine()?.Trim();

                switch (choice)
                {
                    case "1":
                        if (deviceAddress == 0)
                        {
                            Console.WriteLine("\n??  No device found yet. Please scan first (Option 4)");
                        }
                        else
                        {
                            await ProvisionWiFi();
                        }
                        break;

                    case "2":
                        if (deviceAddress == 0)
                        {
                            Console.WriteLine("\n??  No device found yet. Please scan first (Option 4)");
                        }
                        else
                        {
                            await ClearCredentials();
                        }
                        break;

                    case "3":
                        if (deviceAddress == 0)
                        {
                            Console.WriteLine("\n??  No device found yet. Please scan first (Option 4)");
                        }
                        else
                        {
                            await ReadCurrentStatus();
                        }
                        break;

                    case "4":
                        Cleanup();
                        deviceAddress = await ScanForDevice();
                        if (deviceAddress == 0)
                        {
                            Console.WriteLine("\n??  Device still not found. Make sure:");
                            Console.WriteLine("   - Pi is powered on and nearby");
                            Console.WriteLine("   - medusa_wifi_helper service is running");
                            Console.WriteLine("   - Pi is NOT already connected to WiFi");
                            Console.WriteLine("\nYou can try scanning again (Option 4)");
                        }
                        break;

                    case "5":
                        if (deviceAddress == 0)
                        {
                            Console.WriteLine("\n??  No device found yet. Please scan first (Option 4)");
                        }
                        else
                        {
                            await UnpairDevice();
                        }
                        break;

                    case "6":
                        Console.WriteLine("?? Goodbye!");
                        return;

                    default:
                        Console.WriteLine("? Invalid option");
                        break;
                }
            }
        }

        static async Task<ulong> ScanForDevice()
        {
            Console.WriteLine("?? Scanning for BLE devices...");
            
            var watcher = new BluetoothLEAdvertisementWatcher
            {
                ScanningMode = BluetoothLEScanningMode.Active
            };

            ulong foundAddress = 0;
            var tcs = new TaskCompletionSource<ulong>();

            watcher.Received += (sender, args) =>
            {
                var localName = args.Advertisement.LocalName;
                if (!string.IsNullOrEmpty(localName))
                {
                    // Check if this is our target device first
                    if (localName.Contains(TARGET_DEVICE_NAME, StringComparison.OrdinalIgnoreCase))
                    {
                        Console.WriteLine($"   Found: {localName} ({args.BluetoothAddress:X12})");
                        foundAddress = args.BluetoothAddress;
                        watcher.Stop(); // Stop immediately when MeDUSA found
                        tcs.TrySetResult(foundAddress);
                    }
                }
            };

            watcher.Start();

            // Wait for device or timeout
            var timeoutTask = Task.Delay(TimeSpan.FromSeconds(SCAN_TIMEOUT_SECONDS));
            var completedTask = await Task.WhenAny(tcs.Task, timeoutTask);

            watcher.Stop();

            if (completedTask == tcs.Task)
            {
                Console.WriteLine($"? Found MeDUSA device: {foundAddress:X12}\n");
                return foundAddress;
            }
            else
            {
                Console.WriteLine($"? Timeout: MeDUSA device not found after {SCAN_TIMEOUT_SECONDS}s\n");
                return 0;
            }
        }

        static async Task<bool> EnsureConnected()
        {
            if (bleDevice != null && bleDevice.ConnectionStatus == BluetoothConnectionStatus.Connected)
            {
                return true;
            }

            return await ConnectToDevice();
        }

        static async Task<bool> ConnectToDevice()
        {
            Console.WriteLine($"?? Connecting to {deviceAddress:X12}...");

            try
            {
                bleDevice = await BluetoothLEDevice.FromBluetoothAddressAsync(deviceAddress);
                
                if (bleDevice == null)
                {
                    Console.WriteLine("   ? Failed to create device object");
                    return false;
                }

                Console.WriteLine($"? Connected to {bleDevice.Name ?? bleDevice.DeviceId}");
                
                // Wait a moment for connection to stabilize
                await Task.Delay(1000);

                if (bleDevice.ConnectionStatus != BluetoothConnectionStatus.Connected)
                {
                    Console.WriteLine("   ? Waiting for connection...");
                    await Task.Delay(2000);
                }

                // *** LESC PAIRING WITH PASSKEY CONFIRMATION ***
                Console.WriteLine("?? Initiating LESC pairing...");
                var deviceInfo = bleDevice.DeviceInformation;
                var pairingInfo = deviceInfo.Pairing;
                
                Console.WriteLine($"   Can Pair: {pairingInfo.CanPair}");
                Console.WriteLine($"   Is Paired: {pairingInfo.IsPaired}");
                Console.WriteLine($"   Protection Level: {pairingInfo.ProtectionLevel}");
                
                if (!pairingInfo.IsPaired)
                {
                    Console.WriteLine("   Device not paired - requesting LESC pairing...");
                    Console.WriteLine("   ??  IMPORTANT: Check the OLED display for the 6-digit passkey!");
                    Console.WriteLine();
                    
                    var customPairing = deviceInfo.Pairing.Custom;
                    
                    // Register pairing event handler for LESC
                    customPairing.PairingRequested += (sender, args) =>
                    {
                        Console.WriteLine($"\n??????????????????????????????????????????????????");
                        Console.WriteLine($"?          PAIRING REQUEST                       ?");
                        Console.WriteLine($"??????????????????????????????????????????????????");
                        Console.WriteLine($"   Pairing Kind: {args.PairingKind}");

                        switch (args.PairingKind)
                        {
                            case DevicePairingKinds.ConfirmOnly:
                                Console.WriteLine("   Auto-confirming pairing (Just Works fallback)...");
                                args.Accept();
                                break;

                            case DevicePairingKinds.DisplayPin:
                                Console.WriteLine($"\n   ?? PASSKEY DISPLAYED: {args.Pin}");
                                Console.WriteLine($"   ??  CHECK if this matches the code on the OLED display!");
                                Console.Write("\n   Does the passkey match? (y/n): ");
                                var response = Console.ReadKey();
                                Console.WriteLine();
                                
                                if (response.Key == ConsoleKey.Y)
                                {
                                    Console.WriteLine("   ? Accepting pairing...");
                                    args.Accept();
                                }
                                else
                                {
                                    Console.WriteLine("   ? Rejecting pairing (passkey mismatch)");
                                }
                                break;

                            case DevicePairingKinds.ProvidePin:
                                Console.WriteLine($"\n   ??  PIN entry required");
                                Console.Write("   Enter PIN shown on OLED display: ");
                                var pin = Console.ReadLine();
                                args.Accept(pin);
                                break;

                            case DevicePairingKinds.ConfirmPinMatch:
                                Console.WriteLine($"\n   ?? PASSKEY TO CONFIRM: {args.Pin}");
                                Console.WriteLine($"   ??  VERIFY this matches the OLED display!");
                                Console.Write("\n   Does it match? (y/n): ");
                                var confirmResponse = Console.ReadKey();
                                Console.WriteLine();
                                
                                if (confirmResponse.Key == ConsoleKey.Y)
                                {
                                    Console.WriteLine("   ? Confirming passkey match...");
                                    args.Accept();
                                }
                                else
                                {
                                    Console.WriteLine("   ? Passkey mismatch - rejecting pairing");
                                }
                                break;

                            default:
                                Console.WriteLine($"   ??  Unexpected pairing kind: {args.PairingKind}");
                                Console.WriteLine("   Accepting to continue...");
                                args.Accept();
                                break;
                        }
                    };
                    
                    // Request LESC pairing with all possible pairing kinds
                    var pairingResult = await customPairing.PairAsync(
                        DevicePairingKinds.ConfirmOnly | 
                        DevicePairingKinds.DisplayPin | 
                        DevicePairingKinds.ProvidePin |
                        DevicePairingKinds.ConfirmPinMatch,
                        DevicePairingProtectionLevel.EncryptionAndAuthentication
                    );
                    
                    Console.WriteLine($"\n   Pairing result: {pairingResult.Status}");
                    
                    if (pairingResult.Status == DevicePairingResultStatus.Paired)
                    {
                        Console.WriteLine("   ? Device paired successfully with LESC!");
                        Console.WriteLine("   ?? All GATT writes will be encrypted with strong keys");
                    }
                    else if (pairingResult.Status == DevicePairingResultStatus.AlreadyPaired)
                    {
                        Console.WriteLine("   ? Device already paired");
                    }
                    else
                    {
                        Console.WriteLine($"   ??  Pairing failed: {pairingResult.Status}");
                        Console.WriteLine();
                        Console.WriteLine("   Possible causes:");
                        Console.WriteLine("   1. Passkey timeout (Pi defaults to 30 seconds)");
                        Console.WriteLine("   2. Passkey mismatch (check OLED display carefully)");
                        Console.WriteLine("   3. Pi's BlueZ agent not responding");
                        Console.WriteLine("   4. LESC not supported by Bluetooth adapter");
                        Console.WriteLine();
                        Console.WriteLine("   Check Pi-side diagnostics:");
                        Console.WriteLine("   journalctl -u medusa_wifi_helper | grep -i pairing");
                        Console.WriteLine("   journalctl -u bluetooth | grep -i pairing");
                        Console.WriteLine();
                        Console.WriteLine("   Will attempt to continue, but writes will likely fail...");
                    }
                }
                else
                {
                    Console.WriteLine("   ? Device already paired");
                    Console.WriteLine($"   Protection level: {pairingInfo.ProtectionLevel}");
                    
                    // Verify we have sufficient encryption
                    if (pairingInfo.ProtectionLevel == DevicePairingProtectionLevel.EncryptionAndAuthentication)
                    {
                        Console.WriteLine("   ? LESC encryption active");
                    }
                    else if (pairingInfo.ProtectionLevel == DevicePairingProtectionLevel.Encryption)
                    {
                        Console.WriteLine("   ??  Basic encryption (not LESC)");
                        Console.WriteLine("   For better security, unpair and re-pair with LESC");
                    }
                    else
                    {
                        Console.WriteLine("   ??  No encryption detected!");
                        Console.WriteLine("   Writes will likely fail. Try Option 5 to unpair and re-pair");
                    }
                }

                // Discover services
                if (!await DiscoverServices())
                {
                    Console.WriteLine("   ? Failed to discover services");
                    return false;
                }

                Console.WriteLine();
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"   ? Connection error: {ex.Message}");
                Console.WriteLine($"   Type: {ex.GetType().Name}");
                if (ex.HResult != 0)
                {
                    Console.WriteLine($"   Error code: 0x{ex.HResult:X8}");
                }
                return false;
            }
        }

        static async Task<bool> DiscoverServices()
        {
            if (bleDevice == null)
            {
                return false;
            }

            try
            {
                var servicesResult = await bleDevice.GetGattServicesAsync(BluetoothCacheMode.Uncached);
                
                if (servicesResult.Status != GattCommunicationStatus.Success)
                {
                    return false;
                }

                // Find our WiFi Helper service
                var wifiService = servicesResult.Services.FirstOrDefault(s => s.Uuid == SERVICE_UUID);
                
                if (wifiService == null)
                {
                    return false;
                }

                // Get characteristics
                var charsResult = await wifiService.GetCharacteristicsAsync(BluetoothCacheMode.Uncached);
                
                if (charsResult.Status != GattCommunicationStatus.Success)
                {
                    return false;
                }

                // Find our characteristics
                ssidChar = charsResult.Characteristics.FirstOrDefault(c => c.Uuid == SSID_CHAR_UUID);
                pskChar = charsResult.Characteristics.FirstOrDefault(c => c.Uuid == PSK_CHAR_UUID);
                controlChar = charsResult.Characteristics.FirstOrDefault(c => c.Uuid == CONTROL_CHAR_UUID);
                statusChar = charsResult.Characteristics.FirstOrDefault(c => c.Uuid == STATUS_CHAR_UUID);

                if (statusChar == null || ssidChar == null || pskChar == null || controlChar == null)
                {
                    return false;
                }

                return true;
            }
            catch
            {
                return false;
            }
        }

        static async Task ReadCurrentStatus()
        {
            if (!await EnsureConnected())
            {
                Console.WriteLine("? Failed to connect to device");
                return;
            }

            Console.WriteLine("\n?? Reading current status...");

            if (statusChar == null)
            {
                Console.WriteLine("   ? Status characteristic not available");
                return;
            }

            try
            {
                var result = await statusChar.ReadValueAsync(BluetoothCacheMode.Uncached);
                
                if (result.Status == GattCommunicationStatus.Success)
                {
                    var reader = DataReader.FromBuffer(result.Value);
                    var bytes = new byte[reader.UnconsumedBufferLength];
                    reader.ReadBytes(bytes);
                    
                    if (bytes.Length > 0)
                    {
                        var statusCode = bytes[0];
                        var statusText = DecodeStatusCode(statusCode);
                        Console.WriteLine($"   Current Status: {statusText}");
                    }
                }
                else
                {
                    Console.WriteLine($"   ??  Could not read status: {result.Status}");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"   ??  Error reading status: {ex.Message}");
            }
        }

        static async Task ProvisionWiFi()
        {
            if (!await EnsureConnected())
            {
                Console.WriteLine("? Failed to connect to device");
                return;
            }

            Console.WriteLine("\n" + "=".PadRight(60, '='));
            Console.WriteLine("   WiFi Provisioning");
            Console.WriteLine("=".PadRight(60, '='));
            Console.WriteLine();

            // Get SSID
            Console.Write("Enter WiFi SSID: ");
            var ssid = Console.ReadLine();
            
            if (string.IsNullOrWhiteSpace(ssid))
            {
                Console.WriteLine("? SSID cannot be empty");
                return;
            }

            // Get Password
            Console.Write("Enter WiFi Password: ");
            var password = Console.ReadLine();
            
            if (string.IsNullOrWhiteSpace(password))
            {
                Console.WriteLine("? Password cannot be empty");
                return;
            }

            Console.WriteLine("\n?? Provisioning WiFi...");

            // Write SSID
            Console.Write($"?? Writing SSID: {ssid}...");
            if (await WriteCharacteristic(ssidChar!, ssid))
            {
                Console.WriteLine(" ? Done");
            }
            else
            {
                Console.WriteLine(" ? Failed");
                return;
            }

            await Task.Delay(500);

            // Write Password
            Console.Write($"?? Writing password: {new string('*', password.Length)}...");
            if (await WriteCharacteristic(pskChar!, password))
            {
                Console.WriteLine(" ? Done");
            }
            else
            {
                Console.WriteLine(" ? Failed");
                return;
            }

            await Task.Delay(500);

            // Send CONNECT command
            Console.Write("?? Sending CONNECT command...");
            if (await WriteCommand(controlChar!, CMD_CONNECT))
            {
                Console.WriteLine(" ? Sent");
            }
            else
            {
                Console.WriteLine(" ? Failed");
                return;
            }

            // Monitor status
            Console.WriteLine($"\n? Waiting for connection status ({STATUS_MONITOR_SECONDS} seconds)...");
            
            for (int i = 0; i < STATUS_MONITOR_SECONDS; i++)
            {
                await Task.Delay(1000);
                
                try
                {
                    var result = await statusChar!.ReadValueAsync(BluetoothCacheMode.Uncached);
                    
                    if (result.Status == GattCommunicationStatus.Success)
                    {
                        var reader = DataReader.FromBuffer(result.Value);
                        var bytes = new byte[reader.UnconsumedBufferLength];
                        reader.ReadBytes(bytes);
                        
                        if (bytes.Length > 0)
                        {
                            var statusCode = bytes[0];
                            var statusText = DecodeStatusCode(statusCode);
                            Console.WriteLine($"?? [{i + 1}s] Status: {statusText}");

                            // Check if we're done (success or failure)
                            if (statusCode == 0x07) // Success
                            {
                                Console.WriteLine("\n?? WiFi provisioning successful!");
                                return;
                            }
                            else if (statusCode >= 0xF0) // Any failure code
                            {
                                Console.WriteLine("\n? WiFi provisioning failed!");
                                return;
                            }
                        }
                    }
                }
                catch
                {
                    // Ignore read errors during monitoring
                }
            }

            Console.WriteLine("\n??  Monitoring complete. Check Pi for final status.");
        }

        static async Task ClearCredentials()
        {
            if (!await EnsureConnected())
            {
                Console.WriteLine("? Failed to connect to device");
                return;
            }

            Console.WriteLine("\n???  Clearing credentials...");

            try
            {
                if (await WriteCommand(controlChar!, CMD_CLEAR))
                {
                    Console.WriteLine("? Credentials cleared!");
                    
                    // Give it a moment and read status
                    await Task.Delay(1000);
                    await ReadCurrentStatus();
                }
                else
                {
                    Console.WriteLine("? Failed to clear credentials");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"? Error: {ex.Message}");
            }
        }

        static async Task UnpairDevice()
        {
            if (!await EnsureConnected())
            {
                Console.WriteLine("? Failed to connect to device");
                return;
            }

            Console.WriteLine("\n?? Attempting to unpair device...");

            try
            {
                var deviceInfo = bleDevice!.DeviceInformation;
                var pairingInfo = deviceInfo.Pairing;

                if (!pairingInfo.IsPaired)
                {
                    Console.WriteLine("??  Device is not currently paired");
                    return;
                }

                Console.WriteLine($"   Current pairing protection level: {pairingInfo.ProtectionLevel}");
                Console.WriteLine("   Requesting unpair...");

                var unpairResult = await pairingInfo.UnpairAsync();

                if (unpairResult.Status == DeviceUnpairingResultStatus.Unpaired)
                {
                    Console.WriteLine("? Device unpaired successfully!");
                    Console.WriteLine();
                    Console.WriteLine("Now you can:");
                    Console.WriteLine("  1. Scan again (Option 4)");
                    Console.WriteLine("  2. Connect and try provisioning");
                    Console.WriteLine("  3. Fresh pairing will be established automatically");
                    
                    // Clean up connection since we just unpaired
                    Cleanup();
                    deviceAddress = 0; // Force rescan
                }
                else if (unpairResult.Status == DeviceUnpairingResultStatus.AlreadyUnpaired)
                {
                    Console.WriteLine("??  Device was already unpaired");
                }
                else
                {
                    Console.WriteLine($"??  Unpair result: {unpairResult.Status}");
                    Console.WriteLine();
                    Console.WriteLine("If unpair failed, manually remove device from:");
                    Console.WriteLine("  Windows Settings ? Bluetooth & devices ? MeDUSA-Helper ? Remove");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"? Error unpairing: {ex.Message}");
                Console.WriteLine();
                Console.WriteLine("Try manually removing device from:");
                Console.WriteLine("  Windows Settings ? Bluetooth & devices");
            }
        }

        static async Task<bool> WriteCharacteristic(GattCharacteristic characteristic, string value)
        {
            try
            {
                // Check if characteristic has Write property
                if (!characteristic.CharacteristicProperties.HasFlag(GattCharacteristicProperties.Write) &&
                    !characteristic.CharacteristicProperties.HasFlag(GattCharacteristicProperties.WriteWithoutResponse))
                {
                    Console.WriteLine($"\n   ? Characteristic doesn't have Write property");
                    Console.WriteLine($"   Properties: {characteristic.CharacteristicProperties}");
                    return false;
                }
                
                var writer = new DataWriter();
                writer.WriteBytes(Encoding.UTF8.GetBytes(value));
                
                var result = await characteristic.WriteValueAsync(writer.DetachBuffer(), GattWriteOption.WriteWithResponse);
                
                if (result != GattCommunicationStatus.Success)
                {
                    Console.WriteLine($"\n   ? Write failed: {result}");
                    
                    switch (result)
                    {
                        case GattCommunicationStatus.Unreachable:
                            Console.WriteLine("   Device disconnected during write");
                            break;
                            
                        case GattCommunicationStatus.ProtocolError:
                            Console.WriteLine("   GATT protocol error (0x05)");
                            Console.WriteLine("   This typically means insufficient authentication/encryption");
                            Console.WriteLine("   The Pi requires encrypted write (BLE pairing)");
                            Console.WriteLine("   ");
                            Console.WriteLine("   Solutions:");
                            Console.WriteLine("   1. Windows should pair automatically (Just Works mode)");
                            Console.WriteLine("   2. If not paired, remove device from Windows Bluetooth settings and reconnect");
                            Console.WriteLine("   3. Check Pi's BlueZ pairing mode in medusa_wifi_helper logs");
                            break;
                            
                        case GattCommunicationStatus.AccessDenied:
                            Console.WriteLine("   Access denied - pairing required");
                            Console.WriteLine("   Remove device from Windows Bluetooth settings and try again");
                            break;
                    }
                    
                    return false;
                }
                
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"\n   ? Exception: {ex.Message}");
                Console.WriteLine($"   Type: {ex.GetType().Name}");
                
                if (ex.HResult != 0)
                {
                    Console.WriteLine($"   Error code: 0x{ex.HResult:X8}");
                    
                    switch ((uint)ex.HResult)
                    {
                        case 0x80070005:
                            Console.WriteLine("   Meaning: Access denied (E_ACCESSDENIED)");
                            Console.WriteLine("   Solution: BLE pairing required");
                            break;
                            
                        case 0x80070490:
                            Console.WriteLine("   Meaning: Element not found");
                            Console.WriteLine("   Cause: Device disconnected");
                            break;
                            
                        case 0x80650005:
                            Console.WriteLine("   Meaning: INSUFFICIENT AUTHENTICATION (BLE specific)");
                            Console.WriteLine("   ");
                            Console.WriteLine("   *** THIS IS THE PAIRING PROBLEM ***");
                            Console.WriteLine("   ");
                            Console.WriteLine("   The Pi REQUIRES pairing, but pairing failed earlier.");
                            Console.WriteLine("   ");
                            Console.WriteLine("   Root cause is on the Pi side:");
                            Console.WriteLine("   1. Check if medusa_wifi_helper's BlueZ agent is working:");
                            Console.WriteLine("      journalctl -u medusa_wifi_helper.service | grep -i \"agent\\|pairing\\|authorization\"");
                            Console.WriteLine("   ");
                            Console.WriteLine("   2. Check BlueZ is accepting pairing:");
                            Console.WriteLine("      journalctl -u bluetooth.service | tail -50");
                            Console.WriteLine("   ");
                            Console.WriteLine("   3. Verify Pi is pairable:");
                            Console.WriteLine("      bluetoothctl");
                            Console.WriteLine("      show");
                            Console.WriteLine("      (look for 'Pairable: yes')");
                            Console.WriteLine("   ");
                            Console.WriteLine("   4. Check /etc/bluetooth/main.conf has:");
                            Console.WriteLine("      AlwaysPairable = true");
                            Console.WriteLine("      JustWorksRepairing = always");
                            break;
                    }
                }
                
                return false;
            }
        }

        static async Task<bool> WriteCommand(GattCharacteristic characteristic, byte command)
        {
            try
            {
                var writer = new DataWriter();
                writer.WriteByte(command);
                
                var result = await characteristic.WriteValueAsync(writer.DetachBuffer(), GattWriteOption.WriteWithResponse);
                
                if (result != GattCommunicationStatus.Success)
                {
                    Console.WriteLine($"\n   ? Write failed: {result}");
                    
                    switch (result)
                    {
                        case GattCommunicationStatus.Unreachable:
                            Console.WriteLine("   Device disconnected");
                            break;
                            
                        case GattCommunicationStatus.ProtocolError:
                            Console.WriteLine("   GATT protocol error - pairing/encryption required");
                            break;
                            
                        case GattCommunicationStatus.AccessDenied:
                            Console.WriteLine("   Access denied");
                            break;
                    }
                    
                    return false;
                }
                
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"\n   ? Exception: {ex.Message}");
                Console.WriteLine($"   Type: {ex.GetType().Name}");
                return false;
            }
        }

        static string DecodeStatusCode(byte statusCode)
        {
            if (STATUS_CODES.TryGetValue(statusCode, out var status))
            {
                return status;
            }
            return $"Unknown (0x{statusCode:X2})";
        }

        static void Cleanup()
        {
            if (bleDevice != null)
            {
                Console.WriteLine("\n?? Cleaning up connection...");
            }
            
            bleDevice?.Dispose();
            bleDevice = null;
            
            statusChar = null;
            ssidChar = null;
            pskChar = null;
            controlChar = null;
        }
    }
}
