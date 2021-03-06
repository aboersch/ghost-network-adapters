$T = @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace Win32
{
    public static class SetupApi
    {
         // 1st form using a ClassGUID only, with Enumerator = IntPtr.Zero
        [DllImport("setupapi.dll", CharSet = CharSet.Auto)]
        public static extern IntPtr SetupDiGetClassDevs(
           ref Guid ClassGuid,
           IntPtr Enumerator,
           IntPtr hwndParent,
           int Flags
        );
    
        // 2nd form uses an Enumerator only, with ClassGUID = IntPtr.Zero
        [DllImport("setupapi.dll", CharSet = CharSet.Auto)]
        public static extern IntPtr SetupDiGetClassDevs(
           IntPtr ClassGuid,
           string Enumerator,
           IntPtr hwndParent,
           int Flags
        );
        
        [DllImport("setupapi.dll", CharSet = CharSet.Auto, SetLastError = true)]
        public static extern bool SetupDiEnumDeviceInfo(
            IntPtr DeviceInfoSet,
            uint MemberIndex,
            ref SP_DEVINFO_DATA DeviceInfoData
        );
    
        [DllImport("setupapi.dll", SetLastError = true)]
        public static extern bool SetupDiDestroyDeviceInfoList(
            IntPtr DeviceInfoSet
        );

        [DllImport("setupapi.dll", CharSet = CharSet.Auto, SetLastError = true)]
        public static extern bool SetupDiGetDeviceRegistryProperty(
            IntPtr deviceInfoSet,
            ref SP_DEVINFO_DATA deviceInfoData,
            uint property,
            out UInt32 propertyRegDataType,
            byte[] propertyBuffer,
            uint propertyBufferSize,
            out UInt32 requiredSize
        );
    
        [DllImport("setupapi.dll", CharSet = CharSet.Auto, SetLastError = true)]
        public static extern bool SetupDiRemoveDevice(IntPtr DeviceInfoSet,ref SP_DEVINFO_DATA DeviceInfoData);
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct SP_DEVINFO_DATA
    {
       public uint cbSize;
       public Guid classGuid;
       public uint devInst;
       public IntPtr reserved;
    }

    [Flags]
    public enum DiGetClassFlags : uint
    {
        DIGCF_DEFAULT       = 0x00000001,  // only valid with DIGCF_DEVICEINTERFACE
        DIGCF_PRESENT       = 0x00000002,
        DIGCF_ALLCLASSES    = 0x00000004,
        DIGCF_PROFILE       = 0x00000008,
        DIGCF_DEVICEINTERFACE   = 0x00000010,
    }

    public enum SetupDiGetDeviceRegistryPropertyEnum : uint
    {
         SPDRP_DEVICEDESC          = 0x00000000, // DeviceDesc (R/W)
         SPDRP_HARDWAREID          = 0x00000001, // HardwareID (R/W)
         SPDRP_COMPATIBLEIDS           = 0x00000002, // CompatibleIDs (R/W)
         SPDRP_UNUSED0             = 0x00000003, // unused
         SPDRP_SERVICE             = 0x00000004, // Service (R/W)
         SPDRP_UNUSED1             = 0x00000005, // unused
         SPDRP_UNUSED2             = 0x00000006, // unused
         SPDRP_CLASS               = 0x00000007, // Class (R--tied to ClassGUID)
         SPDRP_CLASSGUID           = 0x00000008, // ClassGUID (R/W)
         SPDRP_DRIVER              = 0x00000009, // Driver (R/W)
         SPDRP_CONFIGFLAGS         = 0x0000000A, // ConfigFlags (R/W)
         SPDRP_MFG             = 0x0000000B, // Mfg (R/W)
         SPDRP_FRIENDLYNAME        = 0x0000000C, // FriendlyName (R/W)
         SPDRP_LOCATION_INFORMATION    = 0x0000000D, // LocationInformation (R/W)
         SPDRP_PHYSICAL_DEVICE_OBJECT_NAME = 0x0000000E, // PhysicalDeviceObjectName (R)
         SPDRP_CAPABILITIES        = 0x0000000F, // Capabilities (R)
         SPDRP_UI_NUMBER           = 0x00000010, // UiNumber (R)
         SPDRP_UPPERFILTERS        = 0x00000011, // UpperFilters (R/W)
         SPDRP_LOWERFILTERS        = 0x00000012, // LowerFilters (R/W)
         SPDRP_BUSTYPEGUID         = 0x00000013, // BusTypeGUID (R)
         SPDRP_LEGACYBUSTYPE           = 0x00000014, // LegacyBusType (R)
         SPDRP_BUSNUMBER           = 0x00000015, // BusNumber (R)
         SPDRP_ENUMERATOR_NAME         = 0x00000016, // Enumerator Name (R)
         SPDRP_SECURITY            = 0x00000017, // Security (R/W, binary form)
         SPDRP_SECURITY_SDS        = 0x00000018, // Security (W, SDS form)
         SPDRP_DEVTYPE             = 0x00000019, // Device Type (R/W)
         SPDRP_EXCLUSIVE           = 0x0000001A, // Device is exclusive-access (R/W)
         SPDRP_CHARACTERISTICS         = 0x0000001B, // Device Characteristics (R/W)
         SPDRP_ADDRESS             = 0x0000001C, // Device Address (R)
         SPDRP_UI_NUMBER_DESC_FORMAT       = 0X0000001D, // UiNumberDescFormat (R/W)
         SPDRP_DEVICE_POWER_DATA       = 0x0000001E, // Device Power Data (R)
         SPDRP_REMOVAL_POLICY          = 0x0000001F, // Removal Policy (R)
         SPDRP_REMOVAL_POLICY_HW_DEFAULT   = 0x00000020, // Hardware Removal Policy (R)
         SPDRP_REMOVAL_POLICY_OVERRIDE     = 0x00000021, // Removal Policy Override (RW)
         SPDRP_INSTALL_STATE           = 0x00000022, // Device Install State (R)
         SPDRP_LOCATION_PATHS          = 0x00000023, // Device Location Paths (R)
         SPDRP_BASE_CONTAINERID        = 0x00000024  // Base ContainerID (R)
    }
}
"@
Add-Type -TypeDefinition $T

<#
.Synopsis
   Executes a Process for each Device
.EXAMPLE
   # Print all friendly names
   ForEach-Device { param($friendlyName, $devices, $deviceInfo) Write-Host $friendlyName }
#>
function ForEach-Device {
    [CmdletBinding()]
    Param
    (
        #The Process to be invoked for each friendly Name. params([string] $friendlyName, $devs = devices, $devInfo = deviceInfo
        [Parameter(Mandatory = $true)]
        [ScriptBlock]
        $Process
    )
    $setupClass = [Guid]::Empty
    #Get all devices
    $devs = [Win32.SetupApi]::SetupDiGetClassDevs([ref]$setupClass, [IntPtr]::Zero, [IntPtr]::Zero, [Win32.DiGetClassFlags]::DIGCF_ALLCLASSES)

    #Initialise Struct to hold device info Data
    $devInfo = new-object Win32.SP_DEVINFO_DATA
    $devInfo.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf($devInfo)

    #Device Counter
    $devCount = 0
    #Enumerate Devices
    while ([Win32.SetupApi]::SetupDiEnumDeviceInfo($devs, $devCount, [ref]$devInfo)) {
        # Will contain an enum depending on the type of the registry Property, not used but required for call
        $propType = 0

        # Buffer is initially null and buffer size 0 so that we can get the required Buffer size first
        [byte[]]$propBuffer = $null
        $propBufferSize = 0
        # Get Buffer size
        [Win32.SetupApi]::SetupDiGetDeviceRegistryProperty($devs, [ref]$devInfo, [Win32.SetupDiGetDeviceRegistryPropertyEnum]::SPDRP_FRIENDLYNAME, [ref]$propType, $propBuffer, 0, [ref]$propBufferSize) | Out-null
        # Initialize Buffer with right size
        [byte[]]$propBuffer = [byte[]]::new($propBufferSize)
        # Read FriendlyName property into Buffer
        if (![Win32.SetupApi]::SetupDiGetDeviceRegistryProperty($devs, [ref]$devInfo, [Win32.SetupDiGetDeviceRegistryPropertyEnum]::SPDRP_FRIENDLYNAME, [ref]$propType, $propBuffer, $propBufferSize, [ref]$propBufferSize)) {
            # Ignore if Error
        }
        else {
            # Get Unicode String from Buffer
            $FriendlyName = [System.Text.Encoding]::Unicode.GetString($propBuffer)
            # The friendly Name ends with a weird character
            $FriendlyName = $FriendlyName.Substring(0, $FriendlyName.Length - 1)
            $Process.Invoke($FriendlyName, $devices, $devInfo)
        }
        $devCount++
    }

    [Win32.SetupApi]::SetupDiDestroyDeviceInfoList($devs) | Out-Null
}

<#
.Synopsis
   Get the friendly name of all installed devices 
#>
function Get-DeviceFriendlyNames {
    [CmdletBinding()]
    [OutputType([string[]])]
    param()
    return ForEach-Device {param($friendlyName) $friendlyName}
}

<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
function Remove-Devices {
    [CmdletBinding()]
    [Alias()]
    [OutputType()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [string[]]$FriendlyNames
    )

    if ($FriendlyNames -eq $null -or $FriendlyNames.Count -eq 0) {
        return
    }
    $count = 0;
    ForEach-Device {
        param([string]$FriendlyName, $devs, $devInfo)
        if ($FriendlyNames.Contains($FriendlyName)) {
            if ([Win32.SetupApi]::SetupDiRemoveDevice($devs, [ref]$devInfo)) {
                $count++
            }
            else {
                Write-Verbose "Failed to Remove device $FriendlyName"
            }
        }
    }
    Write-Verbose "Successfully Removed $count Devices"
}

function Remove-GhostNetworkAdapters {
    $version = [System.Environment]::OSVersion.Version

    $version = [System.Environment]::OSVersion.Version

    if ($version.Major -eq 6) {
        switch ($version.Minor) {
            #2008R2
            1 {$adapterName = "Microsoft Virtual Machine Bus Network Adapter "}
            #2012 / 2012R2
            {($_ -eq 2) -or ($_ -eq 3)} {$adapterName = "Microsoft Hyper-V Network Adapter "}
            Default { 
                Write-Host "Unknown Windows Minor Version $($version.Minor). Major Version: $($version.Major). Known minor versions are: 1, 2, 3" -ForegroundColor Red
                return 666
            }
        }
    }
    elseif ($version.Major -eq 10) {
        #Server 2016
        switch ($version.Minor) {
            0 {$adapterName = "Microsoft Hyper-V Network Adapter "}
            Default {
                Write-Host "Unknown Windows Minor Version $($version.Minor). Major Version: $($version.Major). Known minor versions are: 0" -ForegroundColor Red
                return 666
            }
        }
    }
    else {
        Write-Host "Unknown Windows Major Version $($version.Major). Known major versions are: 6, 10" -ForegroundColor Red
        return 666
    }
    
    $activeAdapters = Get-NetAdapter | ? {$_.InterfaceDescription.StartsWith($adapterName)} | select -ExpandProperty InterfaceDescription
    
    Get-DeviceFriendlyNames | ? { $_.Name.StartsWith($adapterName) -and !$activeAdapters.Contains($_)}| Remove-Devices
}

Remove-GhostNetworkAdapters
